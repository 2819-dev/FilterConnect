# Filtr

Personal daily limits for distracting apps and sites — a calm Mac menu-bar companion. Soft nudges only; never a hard lockout.

**Requires macOS 14+ (Sonoma).**

## Download

Prebuilt macOS binaries (unsigned) from GitHub Releases — no Xcode required:

- **[Filtr.app.zip](https://github.com/2819-dev/FilterConnect/releases/download/v0.2.0/Filtr.app.zip)** — unzip, then open `Filtr.app`
- **[Filtr.dmg](https://github.com/2819-dev/FilterConnect/releases/download/v0.2.0/Filtr.dmg)** — open the disk image and run Filtr
- Release page: **[v0.2.0](https://github.com/2819-dev/FilterConnect/releases/tag/v0.2.0)**

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

Filtr uses **Sparkle** to check GitHub Releases and install updates in place — no need to re-download the zip each time.

- Automatic background checks (about daily)
- **Check for Updates…** in the menu bar popover and Settings
- Feed: `https://github.com/2819-dev/FilterConnect/releases/latest/download/appcast.xml`

## Open in Xcode

1. Clone this repo on your Mac.
2. Open **`Filtr.xcodeproj`** in Xcode 15+ (resolves the Sparkle package).
3. Select the **Filtr** scheme and **My Mac** as the run destination.
4. Press **Run** (⌘R). Filtr appears in the menu bar (hourglass icon). There is no Dock icon (`LSUIElement`).

Sign in with a free Apple ID in Xcode if prompted for signing. No paid Apple Developer Program membership is required for personal use.

## Using Filtr

1. Click the menu-bar icon → today’s usage vs limits for **YouTube**, **Gaming**, and **Other**.
2. Open **Settings…** to edit daily limits and app/site mappings.
3. Gaming ships with a small starter list (Steam, Epic, Battle.net, Riot, Minecraft, Twitch hosts, …). Use **Add frontmost app** to map whatever you’re in.
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

Limits, mappings, and usage stay on your Mac (UserDefaults). The only network use is Sparkle checking/downloading updates from GitHub Releases. No account, no analytics.

## Known gaps

- Browser URL APIs are **best-effort**: title/Automation prompts and AX attributes vary by browser version; Arc relies more on Accessibility.
- No hard blocking, Screen Time shields, or cross-device sync (by design for v1).
- Release builds are unsigned (no paid Apple Developer / notarization).
