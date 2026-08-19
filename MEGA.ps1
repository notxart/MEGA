<#
.SYNOPSIS
    Make Edge Google Again (MEGA) - Microsoft Edge Auto-Deploy & Configuration Tool.

.DESCRIPTION
    The ultimate tool to reclaim your browser, turning Microsoft Edge into the
    premier Google-powered experience.

    This script applies a curated set of Group Policy Objects (HKCU registry) and
    direct profile preferences to strip bloatware, disable telemetry & Copilot,
    lock Google as the primary search engine, add Google AI & translation shortcuts,
    and deploy essential browser extensions.

.PARAMETER None
    This script runs in an interactive TUI (Terminal User Interface) mode by default.

.EXAMPLE
    .\MEGA.ps1
    Launches the interactive terminal menu to configure Microsoft Edge.

.NOTES
    Project Name : Make Edge Google Again (MEGA)
    Author       : Traxton <Traxton.GPG@proton.me>
    License      : MIT License
    Language     : Windows PowerShell 5.1+ / PowerShell Core 7+ (Windows 10 / 11)
#>

[CmdletBinding()]
param()

# ==============================================================================
# Global Console Environment & Encoding Configuration
# ==============================================================================

# Ensure standard UTF-8 console output for crisp Unicode glyphs and text rendering
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Enable Virtual Terminal Processing for ANSI Escape Sequences in Console
if (-not ('Win32.Kernel32Helper' -as [type])) {
    try {
        Add-Type -MemberDefinition @"
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr GetStdHandle(int nStdHandle);

            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
"@ -Name "Kernel32Helper" -Namespace "Win32" -ErrorAction Stop | Out-Null
    } catch {
        Write-Verbose -Message "Unable to declare Win32 helper: $($_.Exception.Message)"
    }
}

if ('Win32.Kernel32Helper' -as [type]) {
    $stdOutHandle = [Win32.Kernel32Helper]::GetStdHandle(-11) # STD_OUTPUT_HANDLE = -11
    $consoleMode = 0
    if ([Win32.Kernel32Helper]::GetConsoleMode($stdOutHandle, [ref]$consoleMode)) {
        [Win32.Kernel32Helper]::SetConsoleMode($stdOutHandle, $consoleMode -bor 0x0004) | Out-Null # ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
    }
}

# Unicode Arrow Glyphs (Encoded as explicit character literals to prevent script encoding issues)
$Script:ArrowUp    = [char]0x2191
$Script:ArrowDown  = [char]0x2193
$Script:ArrowRight = [char]0x2192
$Script:ArrowLeft  = [char]0x2190

# ==============================================================================
# Path Definitions (HKCU Registry Policies & Profile Storage)
# ==============================================================================

# Policy Registry Paths (HKCU Group Policy Objects - Requires elevated privileges)
$Script:PolicyBaseKey    = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
$Script:ExtensionKey     = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'
$Script:ManagedSearchKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge\ManagedSearchEngines'

# Microsoft Edge Profile File System Paths
$Script:EdgeUserDataDir  = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$Script:EdgeDefaultDir   = "$Script:EdgeUserDataDir\Default"
$Script:EdgePrefPath     = "$Script:EdgeDefaultDir\Preferences"
$Script:EdgeLocalState   = "$Script:EdgeUserDataDir\Local State"

# ==============================================================================
# ANSI Escape Sequences for Terminal Styling & Screen Control
# ==============================================================================

$Esc = [char]27
$Script:StyleReset       = "$Esc[0m"
$Script:StyleBold        = "$Esc[1m"
$Script:StyleCyan        = "$Esc[96m"
$Script:StyleGreen       = "$Esc[92m"
$Script:StyleYellow      = "$Esc[93m"
$Script:StyleRed         = "$Esc[91m"
$Script:StyleGray        = "$Esc[90m"
$Script:StyleWhite       = "$Esc[97m"
$Script:ClearLineRight   = "$Esc[K"   # Clear line to the right of the cursor
$Script:ClearScreenBelow = "$Esc[J"   # Clear the screen below the cursor

# ==============================================================================
# Configuration Items Definition (Feature Model)
# ==============================================================================

$Script:ConfigItems = @(
    # Category: Target Extensions
    [PSCustomObject]@{ Id = 'EXT_ZOTERO';      Category = 'Target Extensions';   Label = 'Zotero Connector';                                              Selected = $true }
    [PSCustomObject]@{ Id = 'EXT_UBLOCK';      Category = 'Target Extensions';   Label = 'uBlock Origin';                                                 Selected = $true }
    [PSCustomObject]@{ Id = 'EXT_SPONSOR';     Category = 'Target Extensions';   Label = 'SponsorBlock for YouTube';                                      Selected = $true }

    # Category: Appearance
    [PSCustomObject]@{ Id = 'APP_VERTTABS';    Category = 'Appearance';          Label = 'Enable Vertical Tabs & Hide Title Bar';                         Selected = $true }
    [PSCustomObject]@{ Id = 'APP_HOMEPAGE';    Category = 'Appearance';          Label = 'Homepage: UK Layout, 1-Row Links, No Feeds & Preferred Langs';   Selected = $true }

    # Category: Privacy & Security
    [PSCustomObject]@{ Id = 'SET_PRIVACY_ALL'; Category = 'Privacy & Security'; Label = 'Privacy & Security Hardening (Telemetry, Shopping, Tracking)';   Selected = $true }

    # Category: Copilot & AI
    [PSCustomObject]@{ Id = 'COP_DISABLE';     Category = 'Copilot & AI';        Label = 'Copilot: Disable Microsoft Copilot & Sidebar';                  Selected = $true }

    # Category: Search Engines
    [PSCustomObject]@{ Id = 'SRCH_GOOGLE';     Category = 'Search Engines';      Label = 'Address Bar: Lock Google Default & Redirect New Tab';           Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_AI';         Category = 'Search Engines';      Label = 'Add Search Engine: Google AI (Shortcut: gg)';                   Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_CTE';        Category = 'Search Engines';      Label = "Add Search Engine: Chinese $($Script:ArrowRight) English (Shortcut: cte)"; Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_ETC';        Category = 'Search Engines';      Label = "Add Search Engine: English $($Script:ArrowRight) Chinese (Shortcut: etc)"; Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_YT';         Category = 'Search Engines';      Label = 'Add Search Engine: YouTube (Shortcut: yt)';                     Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_YTM';        Category = 'Search Engines';      Label = 'Add Search Engine: YouTube Music (Shortcut: ytm)';               Selected = $true }
)

# ==============================================================================
# Helper Functions
# ==============================================================================

<#
.SYNOPSIS
    Checks whether the current session is running with elevated administrator privileges.
#>
function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Ensures that a specified registry path exists.
#>
function Initialize-RegistryKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
}

<#
.SYNOPSIS
    Sets a registry value safely, creating the parent path if absent.
#>
function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $false)]
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    Initialize-RegistryKey -Path $Path
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop | Out-Null
}

<#
.SYNOPSIS
    Terminates running Microsoft Edge background processes to unlock profile files.
#>
function Stop-EdgeProcess {
    [CmdletBinding()]
    param ()

    $edgeProcesses = Get-Process -Name 'msedge' -ErrorAction SilentlyContinue
    if ($edgeProcesses) {
        Stop-Process -Name 'msedge' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }
}

<#
.SYNOPSIS
    Ensures the Microsoft Edge user profile default directory exists.
#>
function Initialize-EdgeProfileDirectory {
    [CmdletBinding()]
    param ()

    if (-not (Test-Path -Path $Script:EdgeDefaultDir)) {
        New-Item -Path $Script:EdgeDefaultDir -ItemType Directory -Force | Out-Null
    }
}

# ==============================================================================
# Core Execution: Apply Selected Configuration
# ==============================================================================

<#
.SYNOPSIS
    Applies the chosen optimizations and policies to Microsoft Edge.
#>
function Invoke-EdgeConfiguration {
    [CmdletBinding()]
    param ()

    Clear-Host
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)"
    Write-Host "         $($Script:StyleBold)$($Script:StyleCyan) Applying Selected Configurations...$($Script:StyleReset)"
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)`n"

    # Terminate background Edge processes to release file locks
    Stop-EdgeProcess
    Initialize-EdgeProfileDirectory

    # Load existing Preferences JSON
    $prefJson = if (Test-Path -Path $Script:EdgePrefPath) {
        try {
            Get-Content -Path $Script:EdgePrefPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            # Return empty object if file is corrupted or unreadable
            [PSCustomObject]@{}
        }
    } else {
        [PSCustomObject]@{}
    }

    if (-not $prefJson.PSObject.Properties['edge']) {
        $prefJson | Add-Member -MemberType NoteProperty -Name 'edge' -Value ([PSCustomObject]@{})
    }

    # Load existing Local State JSON
    $localStateJson = if (Test-Path -Path $Script:EdgeLocalState) {
        try {
            Get-Content -Path $Script:EdgeLocalState -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            # Return empty object if file is corrupted or unreadable
            [PSCustomObject]@{}
        }
    } else {
        [PSCustomObject]@{}
    }

    if (-not $localStateJson.PSObject.Properties['browser']) {
        $localStateJson | Add-Member -MemberType NoteProperty -Name 'browser' -Value ([PSCustomObject]@{})
    }
    if (-not $localStateJson.browser.PSObject.Properties['enabled_labs_experiments']) {
        $localStateJson.browser | Add-Member -MemberType NoteProperty -Name 'enabled_labs_experiments' -Value @()
    }

    # --------------------------------------------------------------------------
    # 1. Target Extensions (Registry Force-Install Policy)
    # --------------------------------------------------------------------------
    $extMap = @{
        'EXT_ZOTERO'  = 'nmhdhpibnnopknkmonacoephklnflpho'
        'EXT_UBLOCK'  = 'odfafepnkmbhccpbejgmiehpchacaeak'
        'EXT_SPONSOR' = 'mbmgnelfcpoecdepckhlhegpcehmpmji'
    }

    $extIndex = 1
    if (Test-Path -Path $Script:ExtensionKey) {
        Remove-Item -Path $Script:ExtensionKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $targetExtensions = $Script:ConfigItems | Where-Object { $_.Category -eq 'Target Extensions' }
    foreach ($item in $targetExtensions) {
        if ($item.Selected) {
            try {
                $extensionId = $extMap[$item.Id]
                Set-RegistryValue -Path $Script:ExtensionKey -Name "$extIndex" -Value $extensionId -Type ([Microsoft.Win32.RegistryValueKind]::String)
                Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($item.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
                $extIndex++
            } catch {
                Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($item.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
            }
        }
    }

    # --------------------------------------------------------------------------
    # 2. Appearance: Vertical Tabs & Hide Title Bar (Direct Profile Preferences)
    # --------------------------------------------------------------------------
    $vertTabsItem = $Script:ConfigItems | Where-Object { $_.Id -eq 'APP_VERTTABS' }
    if ($vertTabsItem.Selected) {
        try {
            if (-not $prefJson.edge.PSObject.Properties['vertical_tabs']) {
                $prefJson.edge | Add-Member -MemberType NoteProperty -Name 'vertical_tabs' -Value ([PSCustomObject]@{})
            }

            $prefJson.edge.vertical_tabs | Add-Member -MemberType NoteProperty -Name 'opened' -Value $true -Force
            $prefJson.edge.vertical_tabs | Add-Member -MemberType NoteProperty -Name 'hide_titlebar' -Value $true -Force
            $prefJson.edge.vertical_tabs | Add-Member -MemberType NoteProperty -Name 'collapsed' -Value $false -Force

            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($vertTabsItem.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($vertTabsItem.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # --------------------------------------------------------------------------
    # 3. Appearance: Homepage Settings & Preferred Languages (Unlocked)
    # --------------------------------------------------------------------------
    $homepageItem = $Script:ConfigItems | Where-Object { $_.Id -eq 'APP_HOMEPAGE' }
    if ($homepageItem.Selected) {
        try {
            # Clean up any locking GPO language policies to keep settings UI editable
            Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'DefinePreferredLanguages' -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'ApplicationLocaleValue' -ErrorAction SilentlyContinue

            # Policy: Disable MSN feeds on New Tab Page
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'NewTabPageContentEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'NewTabPageQuickLinksEnabled' -Value 1

            # Preferences: Set Preferred Languages (1. English 'en', 2. Traditional Chinese 'zh-TW', 3. English UK 'en-GB')
            if (-not $prefJson.PSObject.Properties['intl']) {
                $prefJson | Add-Member -MemberType NoteProperty -Name 'intl' -Value ([PSCustomObject]@{})
            }
            $prefJson.intl | Add-Member -MemberType NoteProperty -Name 'accept_languages' -Value 'en,zh-TW,zh,en-GB' -Force
            $prefJson.intl | Add-Member -MemberType NoteProperty -Name 'selected_languages' -Value 'en,zh-TW,en-GB' -Force

            # Preferences: New Tab Page Customizations (edge.new_tab_page)
            if (-not $prefJson.edge.PSObject.Properties['new_tab_page']) {
                $prefJson.edge | Add-Member -MemberType NoteProperty -Name 'new_tab_page' -Value ([PSCustomObject]@{})
            }
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'content_display_mode' -Value 'off' -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'feed_disabled' -Value $true -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'market' -Value 'en-gb' -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'locale' -Value 'en-gb' -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'quick_links_row_count' -Value 1 -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'quick_links_mode' -Value 1 -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'quick_links_open_in_new_tab' -Value $false -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'open_in_new_tab' -Value $false -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_promoted_links' -Value $false -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_promoted_tiles' -Value $false -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_widgets' -Value $false -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_feed' -Value $false -Force
            $prefJson.edge.new_tab_page | Add-Member -MemberType NoteProperty -Name 'switch_to_new_look' -Value $false -Force

            # Preferences: Root New Tab Page Fallback
            if (-not $prefJson.PSObject.Properties['new_tab_page']) {
                $prefJson | Add-Member -MemberType NoteProperty -Name 'new_tab_page' -Value ([PSCustomObject]@{})
            }
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'content_display_mode' -Value 'off' -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'feed_disabled' -Value $true -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'market' -Value 'en-gb' -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'quick_links_row_count' -Value 1 -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'quick_links_mode' -Value 1 -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'open_in_new_tab' -Value $false -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_promoted_links' -Value $false -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_promoted_tiles' -Value $false -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_widgets' -Value $false -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'show_feed' -Value $false -Force
            $prefJson.new_tab_page | Add-Member -MemberType NoteProperty -Name 'switch_to_new_look' -Value $false -Force

            # Local State: Set Edge Display Language to English without enterprise lock
            if (-not $localStateJson.PSObject.Properties['intl']) {
                $localStateJson | Add-Member -MemberType NoteProperty -Name 'intl' -Value ([PSCustomObject]@{})
            }
            $localStateJson.intl | Add-Member -MemberType NoteProperty -Name 'app_locale' -Value 'en' -Force

            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($homepageItem.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($homepageItem.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # --------------------------------------------------------------------------
    # 4. Privacy & Security: Comprehensive Hardening (Master Toggle)
    # --------------------------------------------------------------------------
    $itemPrivacyAll = $Script:ConfigItems | Where-Object { $_.Id -eq 'SET_PRIVACY_ALL' }
    if ($itemPrivacyAll.Selected) {
        try {
            # 4.1 Core Tracking Prevention & Performance Privacy
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'TrackingPrevention' -Value 3
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'StartupBoostEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'BackgroundModeEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'NetworkPredictionOptions' -Value 2

            # 4.2 Search and Connected Experiences Elimination
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'AlternateErrorPagesEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'EdgeShoppingAssistantEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'TabServicesEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'EdgeAutomaticTabGroupingEnabled' -Value 0

            # 4.3 Telemetry, Diagnostics & Ad Tracking Elimination
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'DiagnosticData' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'PersonalizationReportingEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'MetricsReportingEnabled' -Value 0

            # 4.4 Typing Telemetry, Text Prediction & WebRTC Privacy
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'TextPredictionEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'EdgeWalletCheckoutEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'PaymentMethodQueryEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'WebRtcLocalIpHdrHandling' -Value 'disable_non_proxied_udp' -Type ([Microsoft.Win32.RegistryValueKind]::String)

            # 4.5 Profile Preferences Hardening
            if (-not $prefJson.edge.PSObject.Properties['shopping']) {
                $prefJson.edge | Add-Member -MemberType NoteProperty -Name 'shopping' -Value ([PSCustomObject]@{})
            }
            $prefJson.edge.shopping | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $false -Force

            if (-not $prefJson.edge.PSObject.Properties['tab_organization']) {
                $prefJson.edge | Add-Member -MemberType NoteProperty -Name 'tab_organization' -Value ([PSCustomObject]@{})
            }
            $prefJson.edge.tab_organization | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $false -Force

            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemPrivacyAll.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemPrivacyAll.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # --------------------------------------------------------------------------
    # 5. Copilot & AI: Completely Disable Copilot Ecosystem
    # --------------------------------------------------------------------------
    $itemCopDisable = $Script:ConfigItems | Where-Object { $_.Id -eq 'COP_DISABLE' }
    if ($itemCopDisable.Selected) {
        try {
            # Core Policy Lockdowns
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'HubsSidebarEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'AllowBrowsingWithCopilot' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'Microsoft365CopilotChatIconEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'CopilotNewTabPageEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'CopilotAddressBarSuggestionsEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'CopilotCoworkToolActionsEnabled' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'CopilotPageContext' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'CopilotCDPPageContext' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'EdgeEntraCopilotPageContext' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'ShareBrowsingHistoryWithCopilotSearchAllowed' -Value 0
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'ComposeInlineEnabled' -Value 0

            # Local State Experiments Flag Injection to prevent AI sidebars
            $experimentsList = [System.Collections.Generic.List[string]]::new([string[]]$localStateJson.browser.enabled_labs_experiments)
            $aiFlags = @('edge-copilot-mode@2', 'edge-ntp-composer@2', 'edge-compose@2')
            foreach ($flag in $aiFlags) {
                if (-not $experimentsList.Contains($flag)) {
                    $experimentsList.Add($flag)
                }
            }
            $localStateJson.browser.enabled_labs_experiments = $experimentsList.ToArray()

            # Preferences Cleanup
            if (-not $prefJson.edge.PSObject.Properties['sidebar']) {
                $prefJson.edge | Add-Member -MemberType NoteProperty -Name 'sidebar' -Value ([PSCustomObject]@{})
            }
            $prefJson.edge.sidebar | Add-Member -MemberType NoteProperty -Name 'show_copilot_button' -Value $false -Force
            $prefJson.edge.sidebar | Add-Member -MemberType NoteProperty -Name 'show_sidebar' -Value $false -Force

            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemCopDisable.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemCopDisable.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # Save Modified Preferences JSON
    try {
        $prefJson | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $Script:EdgePrefPath -Encoding UTF8 -Force
    } catch {
        Write-Verbose -Message "Unable to write Preferences file: $($_.Exception.Message)"
    }

    # Save Modified Local State JSON
    try {
        $localStateJson | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $Script:EdgeLocalState -Encoding UTF8 -Force
    } catch {
        Write-Verbose -Message "Unable to write Local State file: $($_.Exception.Message)"
    }

    # --------------------------------------------------------------------------
    # 6. Search Engines (Official ManagedSearchEngines Policy List)
    # --------------------------------------------------------------------------
    Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'DefaultSearchProvider*' -ErrorAction SilentlyContinue
    Remove-Item -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Edge\SiteSearchSettings' -Recurse -Force -ErrorAction SilentlyContinue

    $itemGoogle = $Script:ConfigItems | Where-Object { $_.Id -eq 'SRCH_GOOGLE' }
    $itemAi     = $Script:ConfigItems | Where-Object { $_.Id -eq 'SRCH_AI' }
    $itemCte    = $Script:ConfigItems | Where-Object { $_.Id -eq 'SRCH_CTE' }
    $itemEtc    = $Script:ConfigItems | Where-Object { $_.Id -eq 'SRCH_ETC' }
    $itemYt     = $Script:ConfigItems | Where-Object { $_.Id -eq 'SRCH_YT' }
    $itemYtm    = $Script:ConfigItems | Where-Object { $_.Id -eq 'SRCH_YTM' }

    if (Test-Path -Path $Script:ManagedSearchKey) {
        Remove-Item -Path $Script:ManagedSearchKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $engineIndex = 1

    # 6.1 Google (Default Engine + Redirect New Tab)
    if ($itemGoogle.Selected) {
        try {
            Set-RegistryValue -Path $Script:PolicyBaseKey -Name 'NewTabPageSearchBox' -Value 'redirect' -Type ([Microsoft.Win32.RegistryValueKind]::String)

            $googleEngine = @{
                name        = 'Google'
                keyword     = 'google.com'
                search_url  = 'https://www.google.com/search?q={searchTerms}'
                suggest_url = 'https://www.google.com/complete/search?client=chrome&q={searchTerms}'
                favicon_url = 'https://www.google.com/favicon.ico'
                is_default  = $true
            }
            $json = $googleEngine | ConvertTo-Json -Compress
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value $json -Type ([Microsoft.Win32.RegistryValueKind]::String)
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemGoogle.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
            $engineIndex++
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemGoogle.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # 6.2 Google AI (Shortcut: gg) - Schema requires omitting is_default
    if ($itemAi.Selected) {
        try {
            $aiEngine = @{
                name        = 'Google AI'
                keyword     = 'gg'
                search_url  = 'https://www.google.com/search?udm=50&q={searchTerms}'
                favicon_url = 'https://www.google.com/favicon.ico'
            }
            $json = $aiEngine | ConvertTo-Json -Compress
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value $json -Type ([Microsoft.Win32.RegistryValueKind]::String)
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemAi.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
            $engineIndex++
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemAi.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # 6.3 Chinese -> English (Shortcut: cte)
    if ($itemCte.Selected) {
        try {
            $cteEngine = @{
                name        = "Chinese $($Script:ArrowRight) English"
                keyword     = 'cte'
                search_url  = 'https://translate.google.com/?sl=zh-TW&tl=en&text={searchTerms}'
                favicon_url = 'https://translate.google.com/favicon.ico'
            }
            $json = $cteEngine | ConvertTo-Json -Compress
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value $json -Type ([Microsoft.Win32.RegistryValueKind]::String)
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemCte.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
            $engineIndex++
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemCte.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # 6.4 English -> Chinese (Shortcut: etc)
    if ($itemEtc.Selected) {
        try {
            $etcEngine = @{
                name        = "English $($Script:ArrowRight) Chinese"
                keyword     = 'etc'
                search_url  = 'https://translate.google.com/?sl=en&tl=zh-TW&text={searchTerms}'
                favicon_url = 'https://translate.google.com/favicon.ico'
            }
            $json = $etcEngine | ConvertTo-Json -Compress
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value $json -Type ([Microsoft.Win32.RegistryValueKind]::String)
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemEtc.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
            $engineIndex++
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemEtc.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # 6.5 YouTube (Shortcut: yt)
    if ($itemYt.Selected) {
        try {
            $ytEngine = @{
                name        = 'YouTube'
                keyword     = 'yt'
                search_url  = 'https://www.youtube.com/results?search_query={searchTerms}'
                favicon_url = 'https://www.youtube.com/favicon.ico'
            }
            $json = $ytEngine | ConvertTo-Json -Compress
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value $json -Type ([Microsoft.Win32.RegistryValueKind]::String)
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemYt.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
            $engineIndex++
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemYt.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # 6.6 YouTube Music (Shortcut: ytm)
    if ($itemYtm.Selected) {
        try {
            $ytmEngine = @{
                name        = 'YouTube Music'
                keyword     = 'ytm'
                search_url  = 'https://music.youtube.com/search?q={searchTerms}'
                favicon_url = 'https://music.youtube.com/favicon.ico'
            }
            $json = $ytmEngine | ConvertTo-Json -Compress
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value $json -Type ([Microsoft.Win32.RegistryValueKind]::String)
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemYtm.Label)$($Script:StyleReset) $($Script:StyleGreen)[OK]$($Script:StyleReset)"
            $engineIndex++
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$($itemYtm.Label)$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    }

    # Completion Banner
    Write-Host "`n$($Script:StyleCyan)-------------------------------------------------------$($Script:StyleReset)"
    Write-Host "$($Script:StyleBold)$($Script:StyleGreen)[SUCCESS]$($Script:StyleReset) $($Script:StyleWhite)Configurations applied successfully.$($Script:StyleReset)"
    Write-Host "$($Script:StyleYellow)Please restart Microsoft Edge to complete setup.$($Script:StyleReset)"
    Write-Host "`n$($Script:StyleGray)Press any key to exit...$($Script:StyleReset)"

    [Console]::ReadKey($true) | Out-Null
    [Console]::CursorVisible = $true
    exit 0
}

# ==============================================================================
# Core Execution: Reset All Policies (with Confirmation Dialog)
# ==============================================================================

<#
.SYNOPSIS
    Clears all MEGA applied policies and restores Edge experimental defaults.
#>
function Reset-EdgePolicy {
    [CmdletBinding()]
    param ()

    Clear-Host
    Write-Host "$($Script:StyleYellow)=======================================================$($Script:StyleReset)"
    Write-Host "         $($Script:StyleBold)$($Script:StyleYellow) Confirm Reset Policies$($Script:StyleReset)"
    Write-Host "$($Script:StyleYellow)=======================================================$($Script:StyleReset)`n"
    Write-Host " $($Script:StyleWhite)Are you sure you want to remove all managed policies? [Y/N]: $($Script:StyleReset)" -NoNewline

    $confirmKey = [Console]::ReadKey($true)
    if ($confirmKey.Key -ne [ConsoleKey]::Y) {
        Write-Host "$($Script:StyleGray)[Cancelled]$($Script:StyleReset)"
        Start-Sleep -Milliseconds 600
        return
    }

    Write-Host "$($Script:StyleGreen)[Confirmed]$($Script:StyleReset)`n"
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)"
    Write-Host "         $($Script:StyleBold)$($Script:StyleCyan) Removing All Managed Policies...$($Script:StyleReset)"
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)`n"

    # Terminate Edge before reverting files
    Stop-EdgeProcess

    # Remove all managed Edge policies under HKCU
    if (Test-Path -Path $Script:PolicyBaseKey) {
        try {
            Remove-Item -Path $Script:PolicyBaseKey -Recurse -Force -ErrorAction Stop | Out-Null
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)Edge Policies Status:$($Script:StyleReset) $($Script:StyleGreen)[Cleared]$($Script:StyleReset)"
        } catch {
            Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)Edge Policies Status:$($Script:StyleReset) $($Script:StyleRed)[Failed]$($Script:StyleReset)"
        }
    } else {
        Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)Edge Policies Status:$($Script:StyleReset) $($Script:StyleGray)[Not Found]$($Script:StyleReset)"
    }

    # Revert Local State experiment flags
    if (Test-Path -Path $Script:EdgeLocalState) {
        try {
            $localStateJson = Get-Content -Path $Script:EdgeLocalState -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($localStateJson.browser.PSObject.Properties['enabled_labs_experiments']) {
                $flagsToRemove = @('edge-copilot-mode@2', 'edge-ntp-composer@2', 'edge-compose@2')
                $filteredFlags = $localStateJson.browser.enabled_labs_experiments | Where-Object { $_ -notin $flagsToRemove }
                $localStateJson.browser.enabled_labs_experiments = @($filteredFlags)
                $localStateJson | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $Script:EdgeLocalState -Encoding UTF8 -Force
                Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)Experiments Status:$($Script:StyleReset) $($Script:StyleGreen)[Reverted]$($Script:StyleReset)"
            }
        } catch {
            Write-Verbose -Message "Unable to revert Local State flags: $($_.Exception.Message)"
        }
    }

    Write-Host "`n$($Script:StyleCyan)-------------------------------------------------------$($Script:StyleReset)"
    Write-Host "$($Script:StyleBold)$($Script:StyleGreen)[SUCCESS]$($Script:StyleReset) $($Script:StyleWhite)All policies removed successfully.$($Script:StyleReset)"
    Write-Host "$($Script:StyleYellow)Please restart Microsoft Edge to apply changes.$($Script:StyleReset)"
    Write-Host "`n$($Script:StyleGray)Press any key to exit...$($Script:StyleReset)"

    [Console]::ReadKey($true) | Out-Null
    [Console]::CursorVisible = $true
    exit 0
}

# ==============================================================================
# Interactive TUI: Render Menu (Virtual Scrolling & Viewport Clamping)
# ==============================================================================

<#
.SYNOPSIS
    Renders the interactive terminal interface with dynamic viewport clamping.
#>
function Show-Menu {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$CurrentIndex
    )

    # 1. Flatten categories and item rows into structured renderable lines
    $renderRows = @()
    $categories = $Script:ConfigItems | Select-Object -ExpandProperty Category -Unique
    $flatItemIndex = 0

    foreach ($category in $categories) {
        $renderRows += [PSCustomObject]@{
            Type      = 'Category'
            Category  = $category
            ItemIndex = -1
            ItemObj   = $null
        }
        $itemsInCategory = $Script:ConfigItems | Where-Object { $_.Category -eq $category }
        foreach ($item in $itemsInCategory) {
            $renderRows += [PSCustomObject]@{
                Type      = 'Item'
                Category  = $category
                ItemIndex = $flatItemIndex
                ItemObj   = $item
            }
            $flatItemIndex++
        }
    }

    # 2. Query terminal dimensions safely
    $windowHeight = try { [Console]::WindowHeight } catch { 25 }
    if ($windowHeight -lt 10) { $windowHeight = 10 }

    # Header occupies 6 fixed lines; allocate 2 lines buffer for scroll markers and padding
    $headerHeight = 6
    $availableContentLines = $windowHeight - $headerHeight - 2
    if ($availableContentLines -lt 3) { $availableContentLines = 3 }

    # 3. Locate the row index matching $CurrentIndex
    $targetRowIndex = 0
    for ($i = 0; $i -lt $renderRows.Count; $i++) {
        if ($renderRows[$i].Type -eq 'Item' -and $renderRows[$i].ItemIndex -eq $CurrentIndex) {
            $targetRowIndex = $i
            break
        }
    }

    # 4. Calculate dynamic viewport window range
    if ($renderRows.Count -le $availableContentLines) {
        $startIndex = 0
        $endIndex   = $renderRows.Count - 1
    } else {
        $halfViewport = [math]::Floor($availableContentLines / 2)
        $startIndex   = [math]::Max(0, $targetRowIndex - $halfViewport)
        $endIndex     = $startIndex + $availableContentLines - 1
        if ($endIndex -ge $renderRows.Count) {
            $endIndex   = $renderRows.Count - 1
            $startIndex = [math]::Max(0, $endIndex - $availableContentLines + 1)
        }
    }

    # 5. Reset cursor to top-left of visible viewport
    [Console]::Write("$Esc[H")

    # 6. Render Fixed Header
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host "        $($Script:StyleBold)$($Script:StyleCyan) Make Edge Google Again (MEGA) Deployer$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host " $($Script:StyleGray)[$($Script:ArrowUp)$($Script:ArrowDown)/kj] Move   [Space] Toggle   [A] All   [N] None$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host " $($Script:StyleGray)[Enter] Apply Selected    [R] Reset All    [Q] Exit$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host "$($Script:StyleCyan)-------------------------------------------------------$($Script:StyleReset)$($Script:ClearLineRight)"

    # 7. Render Scroll Up Indicator if content exists above
    if ($startIndex -gt 0) {
        Write-Host "  $($Script:StyleGray)$($Script:ArrowUp) more items above$($Script:StyleReset)$($Script:ClearLineRight)"
    }

    # 8. Render Clamped Content Rows
    for ($r = $startIndex; $r -le $endIndex; $r++) {
        $row = $renderRows[$r]
        if ($row.Type -eq 'Category') {
            Write-Host "$($Script:StyleBold)$($Script:StyleCyan)## $($row.Category)$($Script:StyleReset)$($Script:ClearLineRight)"
        } else {
            $item = $row.ItemObj
            $isHighlighted = ($row.ItemIndex -eq $CurrentIndex)
            $checkMark = if ($item.Selected) { "$($Script:StyleGreen)[X]$($Script:StyleReset)" } else { "$($Script:StyleGray)[ ]$($Script:StyleReset)" }

            if ($isHighlighted) {
                Write-Host "  $($Script:StyleYellow)>$($Script:StyleReset) $checkMark $($Script:StyleBold)$($Script:StyleWhite)$($item.Label)$($Script:StyleReset) $($Script:ClearLineRight)"
            } else {
                Write-Host "    $checkMark $($Script:StyleWhite)$($item.Label)$($Script:StyleReset) $($Script:ClearLineRight)"
            }
        }
    }

    # 9. Render Scroll Down Indicator if content exists below
    if ($endIndex -lt ($renderRows.Count - 1)) {
        Write-Host "  $($Script:StyleGray)$($Script:ArrowDown) more items below$($Script:StyleReset)$($Script:ClearLineRight)"
    }

    # 10. Clear any residual artifacts below current frame
    [Console]::Write($Script:ClearScreenBelow)
}

# ==============================================================================
# Entry Point & Main Loop
# ==============================================================================

<#
.SYNOPSIS
    Main interaction loop handling input events and menu navigation.
#>
function Invoke-Main {
    [CmdletBinding()]
    param ()

    # Check administrative elevation
    if (-not (Test-IsAdmin)) {
        if ($PSCommandPath) {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs
            exit 0
        } else {
            Write-Host "$($Script:StyleRed)Error: Administrative privileges are required to configure Edge Group Policies.$($Script:StyleReset)"
            Write-Host "$($Script:StyleYellow)Please run PowerShell as Administrator and try again.$($Script:StyleReset)"
            exit 1
        }
    }

    [Console]::CursorVisible = $false
    Clear-Host
    $currentIndex = 0
    $totalItems = $Script:ConfigItems.Count

    while ($true) {
        Show-Menu -CurrentIndex $currentIndex
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            # Navigation Up: ArrowUp or Vim 'k'
            { $_ -in [ConsoleKey]::UpArrow, [ConsoleKey]::K } {
                $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $totalItems - 1 }
            }

            # Navigation Down: ArrowDown or Vim 'j'
            { $_ -in [ConsoleKey]::DownArrow, [ConsoleKey]::J } {
                $currentIndex = if ($currentIndex -lt ($totalItems - 1)) { $currentIndex + 1 } else { 0 }
            }

            # Toggle Selection
            ([ConsoleKey]::Spacebar) {
                $Script:ConfigItems[$currentIndex].Selected = -not $Script:ConfigItems[$currentIndex].Selected
            }

            # Select All
            ([ConsoleKey]::A) {
                $Script:ConfigItems | ForEach-Object { $_.Selected = $true }
            }

            # Deselect All
            ([ConsoleKey]::N) {
                $Script:ConfigItems | ForEach-Object { $_.Selected = $false }
            }

            # Apply Configurations
            ([ConsoleKey]::Enter) {
                Invoke-EdgeConfiguration
            }

            # Reset All Managed Policies
            ([ConsoleKey]::R) {
                Reset-EdgePolicy
                Clear-Host
            }

            # Quit / Exit Setup
            ([ConsoleKey]::Q) {
                Clear-Host
                Write-Host "$($Script:StyleGray)Exiting setup. Goodbye.$($Script:StyleReset)"
                [Console]::CursorVisible = $true
                exit 0
            }
        }
    }
}

# Execute Main Entry Point
Invoke-Main
