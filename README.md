# Phoenix — releases

Installers for **Phoenix**, a local-first AI interview assistant for macOS and Windows.

Downloads are on the [**Releases**](../../releases) page. The application source is kept in a
private repository; this one exists so that downloads and in-app updates work without needing
access to it.

## macOS

Builds are **not notarized**, so macOS reports the app as *"damaged and can't be opened"*. It is
not damaged — that is Apple's wording for an app that is not signed with a paid Developer ID.
Use whichever of these suits you:

- **The `.pkg`** — clears the flag for you during installation. Fewest steps.
- **The `.dmg`** — contains `Install Phoenix.command`, which installs and clears the flag.
- **By hand** — drag the app to Applications, then either approve it once under
  *System Settings → Privacy & Security → Open Anyway*, or run
  `xattr -cr /Applications/Phoenix.app`.

On macOS 15 (Sequoia) and later, right-click → *Open* no longer works as a bypass.

After installing, grant **Microphone** and **Screen & System Audio Recording** under
*System Settings → Privacy & Security*. Screen Recording only takes effect after a relaunch.

Current builds are **Apple Silicon only**. Intel Macs are not yet supported.

## Windows

Run the `.exe` installer. Windows SmartScreen may warn on first run for the same reason —
the build is unsigned.
