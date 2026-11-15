<!-- markdownlint-disable-file MD033 -->

# MEGA: Make Edge Google Again

<div align="center">

> **The ultimate tool to reclaim your browser, turning Microsoft Edge into the premier Google-powered experience.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue.svg)](https://www.microsoft.com/windows)
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%20Core%207%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![GitHub Release](https://img.shields.io/github/v/release/notxart/MEGA?color=green&label=Release)](https://github.com/notxart/MEGA/releases)

</div>

---

## ⚡ Quick Start

### Option 1: One-Line PowerShell Execution (Recommended)

Run PowerShell as a standard user and paste:

```powershell
irm https://raw.githubusercontent.com/notxart/MEGA/main/MEGA.ps1 | iex
```

No Administrator privileges are normally required: every policy is written under
`HKCU`, and the Edge profile lives under `%LOCALAPPDATA%`. MEGA checks that the
policy key is writable before it starts. If Windows or an organization has
locked that key, MEGA requests UAC and relaunches itself automatically when the
current account is a local administrator, instead of failing halfway through. A
standard account gets an explicit explanation rather than an elevation that
would write to a different user's `HKCU`.

### Option 2: Standalone Executable (.exe)

Download the latest compiled release (`MEGA.exe`) directly from the [GitHub Releases](https://github.com/notxart/MEGA/releases) page.

> **Save your work first.** MEGA closes Microsoft Edge before it writes profile files.

## ✨ Features

### Google Ecosystem Lockdown

- Sets Google as the immutable default search provider.
- Redirects the New Tab Page search bar to Google.
- Custom quick-search keyword engines:
  - `gg` → Google AI Overview Search
  - `cte` → Google Translate (Chinese → English)
  - `etc` → Google Translate (English → Chinese)
  - `yt` → YouTube
  - `ytm` → YouTube Music

### Privacy Hardening & Debloat

- Completely strips Microsoft Copilot, Sidebar, and AI compose tools.
- Disables diagnostics telemetry, typing prediction tracking, and shopping assistants.
- Disables background resource consumption and startup boost overhead.
- Prevents WebRTC local IP leakage (`disable_non_proxied_udp`).

### Decluttered UI & Productivity

- Enables vertical tabs and hides the top title bar.
- Cleans New Tab Page (1-row quick links, disables MSN news feeds and promotional tiles).
- Unlocks display and language preference overrides.

### Essential Extension Auto-Deployment

MEGA uses Edge's `ExtensionInstallForcelist` policy to install:

- **uBlock Origin** (Ad-blocking)
- **SponsorBlock** (Skip sponsored segments in YouTube)
- **Zotero Connector** (Academic reference management)
- **[FluentRead](https://microsoftedge.microsoft.com/addons/detail/fluentread/kakgmllfpjldjhcnkghpplmlbnmcoflp)** (Open-source immersive translation)

### Safe by Default

- Operates under `HKCU` and your Edge profile — no machine-wide policy changes.
- Asks for UAC only when the policy registry key is actually not writable, or
  when you pass `-Elevate` on an administrator account.
- `[R] Reset All` removes every MEGA-managed policy and Copilot experiment flag,
  and leaves unrelated Edge policies untouched. Profile preferences changed by
  MEGA (vertical tabs, new-tab layout, languages) are left in place and can be
  adjusted in Edge Settings.
- Applying with no items selected is a no-op, and a corrupt Edge `Preferences` file aborts the run before anything is overwritten.

## 🎮 Interactive Menu Controls

MEGA features an interactive Terminal User Interface (TUI) with dynamic viewport scrolling and Vim navigation support:

| Key | Action |
| --- | --- |
| `↑` / `↓` or `k` / `j` | Move selection up / down |
| `Space` | Toggle selected item on / off |
| `A` | Select all items |
| `N` | Deselect all items |
| `Enter` | Apply selected configurations |
| `R` | Reset and remove all managed policies (Revert) |
| `Q` | Exit setup |

## 🛠️ Requirements & Notes

- Windows 10 or Windows 11, Microsoft Edge installed.
- Windows PowerShell 5.1 or PowerShell 7+.
- `-Elevate` forces a UAC prompt on an administrator account even when the policy
  key is writable:

  ```powershell
  .\MEGA.ps1 -Elevate
  ```

- When MEGA runs through the `irm ... | iex` one-liner and needs elevation, it downloads the canonical script again into a temporary file for the elevated session. Run the script from a local file if you need to test unpublished changes.

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

## 🌟 Acknowledgements & Attributions

- App icon created by Magnific: [Chromium icons created by Magnific - Flaticon](https://www.flaticon.com/free-icons/chromium).
- Policy recommendations aligned with [Privacy Guides](https://www.privacyguides.org/) browser hardening principles.
