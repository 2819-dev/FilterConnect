# Filtr

Personal daily limits for distracting apps and sites — a calm Mac menu-bar companion. Soft nudges only; never a hard lockout.

**Requires macOS 14+ (Sonoma).**

## Download

Prebuilt macOS binaries (unsigned) from GitHub Releases — no Xcode required:

- **[Filtr.app.zip](https://github.com/2819-dev/FilterConnect/releases/download/v0.3.1/Filtr.app.zip)** — unzip, then open `Filtr.app`
- **[Filtr.dmg](https://github.com/2819-dev/FilterConnect/releases/download/v0.3.1/Filtr.dmg)** — open the disk image and run Filtr
- Release page: **[v0.3.1](https://github.com/2819-dev/FilterConnect/releases/tag/v0.3.1)**

Open the **.dmg** → drag **Filtr** onto **Applications** (the window says so).

First launch: **Right-click → Open** (or System Settings → Privacy & Security → Open Anyway). Gatekeeper warns because the build isn’t notarized — expected for free personal unsigned apps.

Prefer putting Filtr in **/Applications** so in-app updates can replace the app cleanly.

If the Release assets aren’t up yet, check the latest green **Build macOS** workflow run → Artifacts → `Filtr-macOS`.

## Setup

On first launch Filtr opens a short setup guide:

1. Welcome
2. Set daily limits (YouTube / Gaming / Other)
3. Optional browser permissions (Accessibility / Automation)
4. Ready

Replay anytime from **Settings → Replay setup guide…**.

## Auto-updates

Filtr checks **GitHub Releases** in the background and can download + install a newer `Filtr.app.zip` for you — no manual re-download.

- Quiet check on launch (prompts only when something newer exists)
- **Check for Updates** in the menu bar popover and Settings
- Installs over the current app location, then relaunches (prefer `/Applications`)

## Open in Xcode

1. Clone this repo on your Mac.
2. Open **`Filtr.xcodeproj`** in Xcode 15+.
3. Select the **Filtr** scheme and **My Mac** as the run destination.
4. Press **Run** (⌘R). Filtr appears in the menu bar (hourglass icon). There is no Dock icon (`LSUIElement`).

Sign in with a free Apple ID in Xcode if prompted for signing. No paid Apple Developer Program membership is required for personal use.

## Using Filtr

1. Click the menu-bar icon → today’s usage vs limits per category.
2. Open **Settings…** to rename categories, add new ones, set minutes, and **Choose apps…** from everything installed on your Mac (plus website hosts / frontmost app).
3. Gaming ships with a starter list you can edit; Other stays empty until you assign apps or sites.
4. Defaults: YouTube **30 min**, Gaming **60 min**, Other **off**.

## Permissions (browser tracking)

Filtr tracks the **frontmost app** via `NSWorkspace` (no special permission).

For **browser** sites (YouTube, Twitch, etc.) it best-effort reads the active tab URL:

| Mechanism | When | What to grant |
|---|---|---|
| **AppleScript** | Safari, Chrome, Brave, Edge | macOS may prompt for **Automation** (control that browser). Allow Filtr. |
| **Accessibility** | Fallback / Arc and others | **System Settings → Privacy & Security → Accessibility** → enable **Filtr**. |

Without those grants, app-level tracking still works; site matching will often miss.

Usage pauses while the screen is locked or the Mac is asleep. Quitting Filtr stops tracking.

## Soft limits

When a category hits its daily limit, Filtr shows:

> You’ve reached your limit for today

Actions: **+1 min**, **+15 min**, **For today**.  
**Dismiss** re-nudges after **5 minutes** if you’re still over and didn’t extend.

Nothing is blocked or quit — awareness + friction only.

## Build from source / Gatekeeper

Prefer the [Download](#download) links above. To build yourself: **Product → Archive** in Xcode (or use the **Build macOS** GitHub Action). Same Gatekeeper note: Right-click → Open for unsigned builds.

## Privacy

Limits, mappings, and usage stay on your Mac (UserDefaults). The only network use is checking/downloading updates from GitHub Releases. No account, no analytics.

## Known gaps

- Browser URL APIs are **best-effort**: title/Automation prompts and AX attributes vary by browser version; Arc relies more on Accessibility.
- No hard blocking, Screen Time shields, or cross-device sync (by design for v1).
- Release builds are unsigned (no paid Apple Developer / notarization).
