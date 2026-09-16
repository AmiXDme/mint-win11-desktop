# mint-win11-desktop

Windows 11-style desktop for Linux Mint (Cinnamon). Clone this repo on a fresh
Mint install and run `./install.sh` to get the exact same setup.

## What you get

- **Win11 start menu** (`menueleven@djb`) — opens with either Windows key
  (`Super_L::Super_R`), full-width search box on top, 700×600 sized to fit
  900px-tall screens.
- **Taskbar search bar** (`searchbar@win11`) — centered pill between the Menu
  button and the window list. Clicking it opens the menu; typing goes straight
  into the menu search.
- **Panel layout** — Menu → Search → open windows, centered (Win11 order).

## Fresh-install steps

```bash
git clone <your-repo-url> mint-win11-desktop
cd mint-win11-desktop
./install.sh
```

`install.sh` copies both applets into `~/.local/share/cinnamon/applets/`,
restores the applet settings + panel layout via dconf, and restarts Cinnamon.
No sudo needed.

## Fixes included (vs upstream)

1. **`menueleven@djb/6.0/appsview.js` → `focusFirstItem()`**: upstream calls
   `buttons[0].actor.grab_key_focus()` after every search, which yanks keyboard
   focus out of the search box — only the first typed character ever landed.
   Fixed to highlight via `handleEnter()` + `has_focus` flag instead, so
   typing continues while Enter-to-launch and arrow navigation keep working.
2. **`searchbar@win11/applet.js`** (rewritten): finds the menu via
   `getRunningInstancesForUuid()` (+ `_uuid` fallback), listens with
   capture-phase `captured-event` (St.Entry internals swallow normal
   `button-press-event`), and opens the menu on ButtonRelease (opening on
   press causes the same click's release to dismiss it again).
3. **Menu config** (`config/menueleven@djb.json`): overlay key
   `Super_L::Super_R`, search box 90% width on top, menu 700×600.

## Layout

```
applets/menueleven@djb/   Win11 start menu (with search-focus fix)
applets/searchbar@win11/  Centered taskbar search pill (rewritten wiring)
config/enabled-applets.txt  Panel layout (dconf)
config/next-applet-id.txt   Applet id counter (dconf)
config/menueleven@djb.json  Menu settings (overlay key, search, size)
install.sh                One-shot restore script
```
