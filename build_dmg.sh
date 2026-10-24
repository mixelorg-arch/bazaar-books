#!/bin/bash
# Wraps Bazaar Books.app in a drag-to-Applications disk image.
set -e
cd "$(dirname "$0")"

APP="Bazaar Books.app"
DMG="BazaarBooks.dmg"
VOL="Bazaar Books"
STAGE=".dmg_stage"

[ -d "$APP" ] || { echo "✗ $APP not found — run ./build_app.sh first"; exit 1; }

echo "▸ staging"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Read Me.txt" <<'TXT'
Bazaar Books — till and ledger for the photobooth bazaar
========================================================

INSTALL
  Drag Bazaar Books onto the Applications folder shown beside it.

FIRST LAUNCH
  The app is signed ad-hoc, not notarised by Apple, so the first launch
  needs one extra step:
      right-click Bazaar Books in Applications  ->  Open  ->  Open
  macOS remembers the choice; after that it opens normally.

USING IT
  Sell    tap a tile per item sold, then Charge
  Sales   every sale, by day — expand, void, or print a receipt
  Report  takings by period, by item and by category, CSV export
  Items   add, edit and remove products and their prices
  Books   days, wages, expenses and the monthly report

  It works with no internet. Sign in (top of the window) to sync to
  Supabase; the bazaar's data is kept in its own tables, separate from
  the print shop till and the sales ledger.
TXT

echo "▸ building $DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "✓ built $DMG"
