# Bazaar Books

Till and ledger for the photobooth bazaar — 3D printed items, stickers and
booth prints. Same system as the print shop till, with its own products and its
own database tables, so the two businesses never mix.

| Tab | |
|---|---|
| **Sell** | Product tiles by category, running cart, cash-and-change keypad |
| **Sales** | Every sale by day — expand, void, or print a receipt |
| **Report** | Takings by period, by item and by category, CSV export |
| **Items** | Add, edit and remove products, prices, and payment methods |
| **Books** | Days, wages, expenses, and the printed monthly report |

The seeded price list (keychains, flexi toys, figurines, sticker sheets, photo
strips, bundles) is a starting point — all of it is editable in **Items**.

## Mode of payment

Charging a sale asks how it was paid: **Cash, GCash, Maya, Maribank, BPI,
BDO**. Edit the list under **Items → Payment methods** — the switch at the top
of the Items tab — or tap **Edit methods** on the Charge sheet itself. Add,
rename and remove methods freely; the list is synced, so every device offers
the same one.

Cash is the only one that asks for an amount and works out change; a transfer
is always for the exact total, so the keypad gets out of the way. The method
shows on the sale, on the receipt, in the CSV export, and as a **By payment**
breakdown in **Report** — which is what you reconcile each wallet against at
the end of a day.

Sales taken before this existed count as Cash.

## How to run it

* **Mac** — `BazaarBooks.dmg`, drag to Applications. First launch: right-click
  → Open → Open (it is signed ad-hoc, not notarised).
* **Android tablet** — `BazaarBooks.apk`, copy it over and open it. Android 7+.
* **Browser** — serve this folder over http:// (not `file://`, which blocks
  storage): `python3 -m http.server 8791`

All three are the same web app; the Mac and Android builds bundle it and add
printing and CSV saving, which a plain web view cannot do on its own.

## Data

Offline first: the till never waits for the network. localStorage holds
everything on screen, and Supabase is the copy made when there is a connection
and someone is signed in. Signing in is optional.

Tables live in the **`ledger`** Supabase project, all prefixed `bazaar_`:

* `bazaar_sales` — one row per sale, line items as JSON
* `bazaar_services` — the price list
* `bazaar_methods` — the payment methods
* `bazaar_days` — each trading day's takings and wages
* `bazaar_expenses` — monthly costs
* `bazaar_people` — who worked
* `bazaar_daily_totals` — a view: daily takings straight from SQL
* `bazaar_payment_totals` — a view: daily takings split by payment method

**Nothing is shared with the print shop till (`printshop_*`) or the sales
ledger (`entries`, `expenses`, `employees`).** Row level security limits every
table to an approved member.

Schema: [`supabase/schema.sql`](supabase/schema.sql), then
[`supabase/payments-migration.sql`](supabase/payments-migration.sql) for the
payment methods. Both are already applied — they are here as the record.

Each build is a separate store of data: sales rung up on the Mac do not appear
on the tablet until both have synced.

## Rebuilding

```bash
./build_app.sh && ./build_dmg.sh                    # Mac
cd ../BazaarBooks-Android && ./gradlew assembleRelease   # Android
```

Both copy in the current `index.html`, so the web app stays the single source
of truth. Back up `../BazaarBooks-Android/bazaarbooks-release.jks` and
`keystore.properties` — Android only installs an update signed with the same key.
