import Cocoa
import WebKit

// Serves the bundled web app under a stable origin (app://bazaar/) rather than
// file://. A file URL has no stable origin, so localStorage — where every sale
// lives until it syncs — and the module import of supabase-js would both be
// unreliable. This makes WKWebView behave exactly like the browser.
final class SchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { task.didFailWithError(URLError(.badURL)); return }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let name = (path as NSString).lastPathComponent
        let base = (name as NSString).deletingPathExtension
        let ext  = (name as NSString).pathExtension
        guard let fileURL = Bundle.main.url(forResource: base, withExtension: ext),
              let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let mime: String
        switch ext.lowercased() {
            case "html": mime = "text/html"
            case "js":   mime = "text/javascript"
            case "css":  mime = "text/css"
            case "json": mime = "application/json"
            default:     mime = "application/octet-stream"
        }
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": mime])!
        task.didReceive(resp)
        task.didReceive(data)
        task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate,
                         WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    // Two things a WKWebView cannot do by itself: window.print() does nothing,
    // and a blob <a download> goes nowhere. Both are routed to the native side.
    // The web app is untouched — it has no idea it is running inside an app.
    static let shim = """
    (function(){
      if(window.__bzNative) return; window.__bzNative=true;
      window.print=function(){ window.webkit.messageHandlers.bz.postMessage({action:'print'}); };
      var click=HTMLAnchorElement.prototype.click;
      HTMLAnchorElement.prototype.click=function(){
        var a=this;
        if(a.download && /^(blob|data):/.test(a.href)){
          fetch(a.href).then(function(r){return r.text();}).then(function(t){
            window.webkit.messageHandlers.bz.postMessage({action:'save', name:a.download, text:t});
          });
          return;
        }
        return click.apply(this, arguments);
      };
    })();
    """

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 1280, height: 860)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.center()
        window.title = "Bazaar Books"
        window.setFrameAutosaveName("BazaarBooksMainWindow")
        window.minSize = NSSize(width: 900, height: 600)
        window.backgroundColor = NSColor(srgbRed: 0.961, green: 0.961, blue: 0.961, alpha: 1)

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()   // sales survive quitting
        config.setURLSchemeHandler(SchemeHandler(), forURLScheme: "app")
        config.userContentController.addUserScript(
            WKUserScript(source: AppDelegate.shim, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.add(self, name: "bz")

        webView = WKWebView(frame: rect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL(string: "app://bazaar/index.html")!))

        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Headless check that the bundle really serves the app: BZ_SELFCHECK=1
    /// writes what the page rendered to /tmp/bz_selfcheck.txt and quits.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard ProcessInfo.processInfo.environment["BZ_SELFCHECK"] == "1" else { return }
        let js = """
        (function(){
          // Opening Items renders the payment-method list, which is the point
          // of the check. The app quits straight after, so nothing is left.
          var it=document.querySelector('#tabs button[data-tab="items"]'); if(it) it.click();
          return JSON.stringify({title:document.title,
          shop:document.getElementById('shopName').textContent,
          tiles:document.querySelectorAll('.tile[data-id]').length,
          methods:document.querySelectorAll('.item-row[data-mid]').length,
          tabs:[...document.querySelectorAll('#tabs button')].map(b=>b.textContent),
          configLoaded: !!window.BAZAAR_CONFIG,
          origin: location.origin,
          storage: (function(){ try{ localStorage.setItem('__t','1');
            var ok = localStorage.getItem('__t')==='1'; localStorage.removeItem('__t');
            return ok; }catch(e){ return 'blocked: '+e; } })()});
        })()
        """
        webView.evaluateJavaScript(js) { result, err in
            let line = (result as? String) ?? "error: \(String(describing: err))"
            try? line.write(to: URL(fileURLWithPath: "/tmp/bz_selfcheck.txt"),
                            atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
        }
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "bz", let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        switch action {
        case "print": printPage()
        case "save":
            let name = (body["name"] as? String) ?? "export.csv"
            let text = (body["text"] as? String) ?? ""
            save(name: name, text: text)
        default: break
        }
    }

    /// The page's own @media print rules decide what prints — the receipt or
    /// the monthly report, never the whole till.
    @objc func printPage() {
        let info = NSPrintInfo.shared
        info.horizontalPagination = .automatic
        info.verticalPagination   = .automatic
        let op = webView.printOperation(with: info)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.view?.frame = webView.bounds
        op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    private func save(name: String, text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            do { try text.data(using: .utf8)?.write(to: url) }
            catch {
                let a = NSAlert(); a.messageText = "Could not save the file"
                a.informativeText = error.localizedDescription
                a.runModal()
            }
        }
    }

    // The web app has its own confirm sheets, but keep these honest anyway.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = NSAlert(); a.messageText = message; a.runModal(); completionHandler()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate

let mainMenu = NSMenu()
let appItem = NSMenuItem(); mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "About Bazaar Books",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
appMenu.addItem(.separator())
appMenu.addItem(withTitle: "Hide Bazaar Books", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
appMenu.addItem(withTitle: "Quit Bazaar Books", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu

let fileItem = NSMenuItem(); mainMenu.addItem(fileItem)
let fileMenu = NSMenu(title: "File")
fileMenu.addItem(withTitle: "Print…", action: #selector(AppDelegate.printPage), keyEquivalent: "p")
fileItem.submenu = fileMenu

let editItem = NSMenuItem(); mainMenu.addItem(editItem)
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
editMenu.addItem(.separator())
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editItem.submenu = editMenu
app.mainMenu = mainMenu

app.run()
