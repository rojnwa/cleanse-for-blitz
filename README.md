<p align="center">
  <img src="assets/banner.svg" width="880" alt="Cleanse: adblock for the Blitz desktop app. No ads, no trackers, no cookie banner.">
</p>

Cleanse is an ad blocker for the [Blitz](https://blitz.gg) desktop app on Windows. It removes ads,
trackers and the cookie banner for League of Legends, TFT and VALORANT. The ad column disappears too,
so pages like champion builds use the full window width. Nothing extra to install, and none of Blitz's
files are changed.

## Get started

Press the Windows key, type **PowerShell**, open it, paste this line and press Enter:

```powershell
irm https://raw.githubusercontent.com/rojnwa/cleanse-for-blitz/HEAD/cleanse.ps1 | iex
```

Choose whether Blitz should start ad-free when Windows starts, and Blitz opens without ads. From now
on, open Blitz with the **Cleanse for Blitz** shortcut on your desktop or in the Start menu.

Rather not use PowerShell? Download this repository as a ZIP, unzip it and double-click **Install.cmd**.

To remove Cleanse, paste this instead, or double-click **Uninstall.cmd**. Blitz itself stays installed.

```powershell
iex "& {$(irm https://raw.githubusercontent.com/rojnwa/cleanse-for-blitz/HEAD/cleanse.ps1)} -Uninstall"
```

## Questions

**Windows asks whether to run the file.** Click **Run** (or **More info → Run anyway**). Cleanse is a
plain-text script: open [`cleanse.ps1`](cleanse.ps1) to read every line.

**Blitz restarted when I opened it.** If Blitz was already open the normal way, it's restarted once so
ads can be blocked.

**Blitz opens twice at login.** Turn off Blitz's own "launch on startup" setting and let Cleanse start
it instead (run **Install.cmd** again to change that choice).

**Does it work with Blitz for Fortnite, CS2 or Marvel Rivals?** No. Those are separate Blitz apps.
Cleanse works with the main Blitz app (League of Legends, TFT and VALORANT).

**Ads are back after a Blitz update.** Blitz probably changed its ad provider. Cleanse updates itself
every time you open Blitz with it, so a fix arrives on its own once it's published.

## How it works

Blitz is built on Chromium. The shortcut starts Blitz with a local debugging port and connects to it
through the Chrome DevTools Protocol to:

- cancel requests to ad networks, the cookie-banner provider and analytics (Blitz's own servers are
  left alone);
- hide the empty ad slots and give the reserved ad column back to the content.

It stops by itself when you close Blitz. On each start it checks this repository for a newer version
of the script and updates itself. It uses only the PowerShell built into Windows 10 and 11.
The debugging port only accepts connections from your own PC, but any program on your PC can use it
while Blitz runs.

## Legal

GPLv3. See [LICENSE](LICENSE).

Cleanse isn't affiliated with or endorsed by Blitz App, Inc. Blitz is a trademark of Blitz App, Inc.

Cleanse was created under Riot Games' "Legal Jibber Jabber" policy using assets owned by Riot Games.
Riot Games does not endorse or sponsor this project.
