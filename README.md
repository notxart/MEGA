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

Run PowerShell as a standard user (no Administrator privileges required) and paste:

```powershell
irm https://raw.githubusercontent.com/notxart/MEGA/main/MEGA.ps1 | iex
```

### Option 2: Standalone Executable (.exe)

Download the latest compiled release (`MEGA.exe`) directly from the [GitHub Releases](https://github.com/notxart/MEGA/releases) page.

## ✨ Features

### Google Ecosystem Lockdown

- Sets Google as the immutable default search provider.
- Redirects the New Tab Page search bar to Google.
- Custom quick-search keyword engines:
  - `gg` $\rightarrow$ Google AI Overview Search
  - `cte` $\rightarrow$ Google Translate (Chinese $\rightarrow$ English)
  - `etc` $\rightarrow$ Google Translate (English $\rightarrow$ Chinese)
  - `yt` → YouTube
  - `ytm` $\rightarrow$ YouTube Music

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

- **uBlock Origin** (Ad-blocking)
- **SponsorBlock** (Skip sponsored segments in YouTube)
- **Zotero Connector** (Academic reference management)

### Zero-Risk & Non-Invasive

- Operates strictly under HKCU (Current User) — No Admin rights needed.
- One-key complete rollback (`[R] Reset All`) to restore native Edge defaults.

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

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

## 🌟 Acknowledgements & Attributions

- App icon created by Magnific: [Chromium icons created by Magnific - Flaticon](https://www.flaticon.com/free-icons/chromium).
- Policy recommendations aligned with [Privacy Guides](https://www.privacyguides.org/) browser hardening principles.
