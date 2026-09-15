# Vicinae + Spectacle-style window management

Vicinae owns the launcher, window picker, and clipboard history. Rectangle owns
window sizing/placement on macOS; KWin owns it on KDE Plasma Wayland. Snippets and
Raycast clipboard history are **not migrated**. No private data belongs here.

Prepared against Vicinae **0.28.2** and Rectangle **0.73** (build 79). Vicinae's
macOS support is beta and requires **Apple Silicon + macOS 26 or newer**.

## macOS setup

1. Install the apps if missing:

   ```sh
   brew install --cask vicinae rectangle
   ```

   Homebrew also installs the Vicinae CLI. For a DMG installation, follow the
   [official CLI symlink instructions](https://docs.vicinae.com/install/macos#cli-usage).
   `install.sh` installs configuration, not application packages.
2. Quit Raycast, Vicinae, and Rectangle before applying/restarting. Raycast and
   Rectangle can otherwise compete for the same window shortcuts; Raycast and
   Vicinae would both claim Command+Space and Option+Tab.
3. From the repository root, run `./install.sh`. On a fresh machine this creates
   the Vicinae imports and stages Rectangle's preset for its next launch.
4. If Vicinae already had a `settings.json`, the installer preserves it. Add these
   paths to its existing `imports` array (create the array if absent):

   ```json
   {
       "imports": ["dots/settings.json", "dots/macos.json"]
   }
   ```

   This is an example of the imports field, **not a replacement for the whole
   existing file**. Keep other imports and preferences. Local values override the
   imported defaults; remove a local shortcut override if you want the repo value.
5. Start Vicinae and Rectangle. Complete Vicinae's onboarding and grant the
   permissions it requests for window access, clipboard/pasting, and input
   handling. Grant Rectangle **Accessibility** permission. These OS approvals
   must be done on each Mac; copying dotfiles cannot grant them.
6. Enable **Launch at Login** in both apps. Disable Raycast's login launch only
   after checking the replacement works. Also release Command+Space in Spotlight
   shortcuts if it is still assigned there.

### Hotkeys

Vicinae serializes the macOS Command key as `control`; this is deliberate and
must not be copied unchanged to Linux. The clipboard shortcut is a new default,
not recovered from Raycast.

| Action | macOS shortcut |
| --- | --- |
| Toggle Vicinae | ⌘Space |
| Switch Windows | ⌥Tab |
| Clipboard History | ⌘⇧V |
| Left / right / top / bottom half | ⌘⌥← / → / ↑ / ↓ |
| Maximize (not macOS fullscreen) | ⌘⌥F |
| Center | ⌘⌥C |
| Top-left / top-right quarter | ⌃⌘← / → |
| Bottom-left / bottom-right quarter | ⌃⌘⇧← / → |
| Previous / next display | ⌃⌥⌘← / → |
| Smaller / larger | ⌃⌥⇧← / → |
| Maximize height | ⌃⌥⇧↑ |
| Restore previous size/position | ⌃⌥Backspace |

The Rectangle preset explicitly assigns its **Spectacle-default** bindings,
including Rectangle's Restore action. It is not an exact reimplementation of
Spectacle's undo/redo history or third cycling. Other existing Rectangle
preferences and unrelated shortcuts are left alone.

Option+Tab invokes Vicinae's **searchable Switch Windows command**, not macOS's
native app switcher. Do not assume native hold-Alt/repeated-Tab/release-to-activate
behavior. Select a window and press Return.

### Check after starting

- Command+Space opens Vicinae rather than Raycast or Spotlight.
- Option+Tab lists open windows; selecting one focuses it.
- Copy harmless text, then use Command+Shift+V to find and paste it.
- In a normal, resizable window, test halves, quarters, maximize, restore, and
  display movement (when a second display is connected).
- Log in again and confirm both apps start without Raycast reclaiming the keys.

If reverting, quit Vicinae and Rectangle before restarting Raycast. Its data and
preferences have not been removed or modified by this setup.

## KDE Plasma on Wayland

**Secondary target: supplied configuration is not live-tested on KDE.** The
installer installs the shared Vicinae defaults, but does not edit a live
`kglobalshortcutsrc`, replace your KDE configuration, or guess your distribution's
package manager. The following desktop-local setup is still required.

1. Install Vicinae using the package appropriate to your distribution.
2. Run `./install.sh`. If a Vicinae config already exists, add
   `"dots/settings.json"` to its `imports` array. Do **not** import `macos.json`.
3. Start it at login using the documented user service:

   ```sh
   systemctl --user enable vicinae --now
   ```

   If your package has no service, add Vicinae to KDE Autostart instead. Use one
   startup method, not both.
4. In **System Settings → Keyboard → Shortcuts**, add these application/command
   shortcuts (the `vicinae` CLI must be on KDE's session PATH):

   | Shortcut | Command |
   | --- | --- |
   | Meta+Space | `vicinae toggle` |
   | Alt+Tab | `vicinae deeplink vicinae://launch/wm/switch-windows` |
   | Meta+Shift+V | `vicinae deeplink vicinae://launch/clipboard/history` |

   Clear KWin's **Walk Through Windows → Alt+Tab** before assigning that key to
   Vicinae. Resolve any KRunner/Klipper or custom binding collisions shown by KDE.
   Native KWin Alt+Tab remains an alternative if you prefer its cycling behavior.
5. In that Shortcuts page, import `vicinae/kde.kksrc` from this repository and
   apply it. This partial scheme changes only the named KWin window actions.
   It maps **Command → Meta**, **Option → Alt**, and **Control → Ctrl** from the
   table above. Launcher/clipboard bindings are configured separately in step 4.

### Linux differences and limitations

- The macOS bindings are registered directly by Vicinae. Wayland global shortcut
  support depends on the compositor's protocols; the documented KDE command
  bindings avoid depending on Vicinae's newer hotkey protocol support.
- KWin quick tiling/maximization is native KDE behavior, not Rectangle behavior.
  The scheme covers halves, quarters, maximize, center, display movement, and
  maximize-height. It does **not** invent equivalents for Rectangle's incremental
  larger/smaller or restore-history actions. KWin maximization toggles, and tiling
  may differ on repeated presses.
- Vicinae's window integration on KDE Wayland uses an **internal KRunner D-Bus
  API**, which upstream calls brittle. Window listing/focusing can break after
  Plasma updates. Native KWin Alt+Tab is the fallback.
- Clipboard monitoring is supported through KDE's Wayland data-control protocol.
  Check history and paste into your real apps; Linux input/paste setup is not the
  same as macOS permissions. Klipper may also retain its own independent history.
- If Vicinae cannot grab focus, upstream recommends KDE focus-stealing prevention
  set to **Low**. Review that desktop-wide change yourself rather than applying it
  silently through dotfiles.
- Android/Termux is intentionally excluded.

## File ownership and privacy

- `~/.config/vicinae/dots` points to this directory (`XDG_CONFIG_HOME` is honored
  by the installer). Imported JSON files are not rewritten by Vicinae.
- `~/.config/vicinae/settings.json` stays a **local writable file**, including when
  `install.sh --force` is used. GUI changes and machine-specific overrides go here.
- `RectangleConfig.json` is **copied**, not linked, to
  `~/Library/Application Support/Rectangle/RectangleConfig.json`. Rectangle
  imports and renames that copy on its next launch. Rerunning the installer stages
  the preset again; an already pending import is preserved. To apply this preset
  instead of a different pending import, use Rectangle's GUI Import button.
- The `version` in the Rectangle export is its source build number, not an update
  pin. The installer does not overwrite the live Rectangle preference plist.
- Clipboard databases, snippets, accounts, application history, and private
  preferences remain outside this repository. The setup does not change clipboard
  retention or encryption defaults; review those in Vicinae before copying secrets.
- Raycast's main shortcut was readable from its preferences, but command settings
  were in its encrypted database. Its encrypted `.rayconfig` is not a Vicinae
  config. Neither that database nor snippet exports are copied here.

## References

- [Vicinae config/imports](https://docs.vicinae.com/config)
- [macOS installation](https://docs.vicinae.com/install/macos)
- [KDE quickstart](https://docs.vicinae.com/quickstart/kde)
- [Window management support](https://docs.vicinae.com/window)
- [Clipboard support](https://docs.vicinae.com/clipboard)
- [Rectangle configuration import/export and Spectacle differences](https://github.com/rxhanson/Rectangle/tree/v0.73#import--export-json-config)
- [Raycast export formats](https://manual.raycast.com/import-export)
