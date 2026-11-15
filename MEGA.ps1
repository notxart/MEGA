<#
.SYNOPSIS
    Make Edge Google Again (MEGA) - Microsoft Edge Auto-Deploy & Configuration Tool.

.DESCRIPTION
    The ultimate tool to reclaim your browser, turning Microsoft Edge into the
    premier Google-powered experience.

    MEGA applies a curated set of HKCU Group Policy objects and direct Edge
    profile preferences to strip bloatware, disable telemetry and Copilot, lock
    Google as the primary search engine, add Google AI and translation
    shortcuts, and deploy essential browser extensions.

    All changes are per-user. Administrator privileges are requested only when
    Windows blocks writes to the HKCU Edge policy key.

.PARAMETER Elevate
    Requests UAC elevation even when the HKCU policy store is writable. Normal
    use does not need this switch.

.EXAMPLE
    .\MEGA.ps1
    Launches the interactive terminal menu to configure Microsoft Edge.

.EXAMPLE
    .\MEGA.ps1 -Elevate
    Launches the menu and always requests administrator privileges first.

.NOTES
    Project Name : Make Edge Google Again (MEGA)
    Author       : Traxton <Traxton.GPG@proton.me>
    License      : MIT License
    Language     : Windows PowerShell 5.1+ / PowerShell Core 7+ (Windows 10 / 11)
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Elevate
)

$Script:ElevateRequested = [bool]$Elevate

# ==============================================================================
# Console, Encoding, and ANSI Styling
# ==============================================================================

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Non-console hosts do not expose an encoder.
}
$OutputEncoding = [System.Text.Encoding]::UTF8
$Script:IsWindowsOS = ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)

# Enable Virtual Terminal Processing so ANSI styling works in classic conhost.
if ($Script:IsWindowsOS) {
    try {
        if (-not ('Win32.Kernel32Helper' -as [type])) {
            Add-Type -MemberDefinition @"
                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern IntPtr GetStdHandle(int nStdHandle);
                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
"@ -Name 'Kernel32Helper' -Namespace 'Win32' -ErrorAction Stop | Out-Null
        }
        $stdOutHandle = [Win32.Kernel32Helper]::GetStdHandle(-11)
        $consoleMode = [uint32]0
        if ([Win32.Kernel32Helper]::GetConsoleMode($stdOutHandle, [ref]$consoleMode)) {
            [Win32.Kernel32Helper]::SetConsoleMode($stdOutHandle, ($consoleMode -bor 0x0004)) | Out-Null
        }
    } catch {
        Write-Verbose -Message "Unable to enable ANSI terminal processing: $($_.Exception.Message)"
    }
}

$Script:ArrowUp = [char]0x2191
$Script:ArrowDown = [char]0x2193
$Script:ArrowRight = [char]0x2192

$Esc = [char]27
$Script:StyleReset = "$Esc[0m"
$Script:StyleBold = "$Esc[1m"
$Script:StyleCyan = "$Esc[96m"
$Script:StyleGreen = "$Esc[92m"
$Script:StyleYellow = "$Esc[93m"
$Script:StyleRed = "$Esc[91m"
$Script:StyleGray = "$Esc[90m"
$Script:StyleWhite = "$Esc[97m"
$Script:ClearLineRight = "$Esc[K"
$Script:ClearScreenBelow = "$Esc[J"

# ==============================================================================
# Paths and Feature Data
# ==============================================================================

# HKCU Edge policies are user-writable in a default Windows installation.
$Script:PolicyBaseKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
$Script:ExtensionKey = "$($Script:PolicyBaseKey)\ExtensionInstallForcelist"
$Script:ManagedSearchKey = "$($Script:PolicyBaseKey)\ManagedSearchEngines"

$Script:EdgeUserDataDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$Script:EdgeDefaultDir = "$($Script:EdgeUserDataDir)\Default"
$Script:EdgePrefPath = "$($Script:EdgeDefaultDir)\Preferences"
$Script:EdgeLocalState = "$($Script:EdgeUserDataDir)\Local State"

$Script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$Script:ProjectRawUrl = 'https://raw.githubusercontent.com/notxart/MEGA/main/MEGA.ps1'

$Script:ExtensionIds = [ordered]@{
    EXT_ZOTERO     = 'nmhdhpibnnopknkmonacoephklnflpho'
    EXT_UBLOCK     = 'odfafepnkmbhccpbejgmiehpchacaeak'
    EXT_SPONSOR    = 'mbmgnelfcpoecdepckhlhegpcehmpmji'
    EXT_FLUENTREAD = 'kakgmllfpjldjhcnkghpplmlbnmcoflp'
}

$Script:SearchEngines = [ordered]@{
    SRCH_GOOGLE = [ordered]@{ name = 'Google'; keyword = 'google.com'; search_url = 'https://www.google.com/search?q={searchTerms}'; suggest_url = 'https://www.google.com/complete/search?client=chrome&q={searchTerms}'; favicon_url = 'https://www.google.com/favicon.ico'; is_default = $true }
    SRCH_AI     = [ordered]@{ name = 'Google AI'; keyword = 'gg'; search_url = 'https://www.google.com/search?udm=50&q={searchTerms}'; favicon_url = 'https://www.google.com/favicon.ico' }
    SRCH_CTE    = [ordered]@{ name = "Chinese $($Script:ArrowRight) English"; keyword = 'cte'; search_url = 'https://translate.google.com/?sl=zh-TW&tl=en&text={searchTerms}'; favicon_url = 'https://translate.google.com/favicon.ico' }
    SRCH_ETC    = [ordered]@{ name = "English $($Script:ArrowRight) Chinese"; keyword = 'etc'; search_url = 'https://translate.google.com/?sl=en&tl=zh-TW&text={searchTerms}'; favicon_url = 'https://translate.google.com/favicon.ico' }
    SRCH_YT     = [ordered]@{ name = 'YouTube'; keyword = 'yt'; search_url = 'https://www.youtube.com/results?search_query={searchTerms}'; favicon_url = 'https://www.youtube.com/favicon.ico' }
    SRCH_YTM    = [ordered]@{ name = 'YouTube Music'; keyword = 'ytm'; search_url = 'https://music.youtube.com/search?q={searchTerms}'; favicon_url = 'https://music.youtube.com/favicon.ico' }
}

$Script:SearchEnginePolicies = [ordered]@{
    SRCH_GOOGLE = [ordered]@{ NewTabPageSearchBox = 'redirect' }
}

$Script:PolicySets = [ordered]@{
    APP_HOMEPAGE = [ordered]@{
        NewTabPageContentEnabled = 0; NewTabPageQuickLinksEnabled = 1
    }
    SET_PRIVACY_ALL = [ordered]@{
        TrackingPrevention = 3; StartupBoostEnabled = 0; BackgroundModeEnabled = 0; NetworkPredictionOptions = 2
        AlternateErrorPagesEnabled = 0; EdgeShoppingAssistantEnabled = 0; TabServicesEnabled = 0; EdgeAutomaticTabGroupingEnabled = 0
        DiagnosticData = 0; PersonalizationReportingEnabled = 0; MetricsReportingEnabled = 0
        TextPredictionEnabled = 0; EdgeWalletCheckoutEnabled = 0; PaymentMethodQueryEnabled = 0
        WebRtcLocalIpHdrHandling = 'disable_non_proxied_udp'
    }
    COP_DISABLE = [ordered]@{
        HubsSidebarEnabled = 0; AllowBrowsingWithCopilot = 0; Microsoft365CopilotChatIconEnabled = 0
        CopilotNewTabPageEnabled = 0; CopilotAddressBarSuggestionsEnabled = 0; CopilotCoworkToolActionsEnabled = 0
        CopilotPageContext = 0; CopilotCDPPageContext = 0; EdgeEntraCopilotPageContext = 0
        ShareBrowsingHistoryWithCopilotSearchAllowed = 0; ComposeInlineEnabled = 0
    }
}

$Script:CopilotExperimentFlags = @('edge-copilot-mode@2', 'edge-ntp-composer@2', 'edge-compose@2')

$Script:NewTabPageSettings = [ordered]@{
    content_display_mode = 'off'; feed_disabled = $true; market = 'en-gb'; locale = 'en-gb'
    quick_links_row_count = 1; quick_links_mode = 1; quick_links_open_in_new_tab = $false
    open_in_new_tab = $false; show_promoted_links = $false; show_promoted_tiles = $false
    show_widgets = $false; show_feed = $false; switch_to_new_look = $false
}

$Script:ConfigItems = @(
    [PSCustomObject]@{ Id = 'EXT_ZOTERO';     Category = 'Target Extensions'; Label = 'Zotero Connector';                                              Selected = $true }
    [PSCustomObject]@{ Id = 'EXT_UBLOCK';     Category = 'Target Extensions'; Label = 'uBlock Origin';                                                 Selected = $true }
    [PSCustomObject]@{ Id = 'EXT_SPONSOR';    Category = 'Target Extensions'; Label = 'SponsorBlock for YouTube';                                      Selected = $true }
    [PSCustomObject]@{ Id = 'EXT_FLUENTREAD'; Category = 'Target Extensions'; Label = 'FluentRead (Immersive Translation)';                            Selected = $true }
    [PSCustomObject]@{ Id = 'APP_VERTTABS';   Category = 'Appearance';        Label = 'Enable Vertical Tabs & Hide Title Bar';                         Selected = $true }
    [PSCustomObject]@{ Id = 'APP_HOMEPAGE';   Category = 'Appearance';        Label = 'Homepage: UK Layout, 1-Row Links, No Feeds & Preferred Langs';   Selected = $true }
    [PSCustomObject]@{ Id = 'SET_PRIVACY_ALL'; Category = 'Privacy & Security'; Label = 'Privacy & Security Hardening (Telemetry, Shopping, Tracking)'; Selected = $true }
    [PSCustomObject]@{ Id = 'COP_DISABLE';    Category = 'Copilot & AI';      Label = 'Copilot: Disable Microsoft Copilot & Sidebar';                  Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_GOOGLE';    Category = 'Search Engines';    Label = 'Address Bar: Lock Google Default & Redirect New Tab';            Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_AI';        Category = 'Search Engines';    Label = 'Add Search Engine: Google AI (Shortcut: gg)';                   Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_CTE';       Category = 'Search Engines';    Label = "Add Search Engine: Chinese $($Script:ArrowRight) English (Shortcut: cte)"; Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_ETC';       Category = 'Search Engines';    Label = "Add Search Engine: English $($Script:ArrowRight) Chinese (Shortcut: etc)"; Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_YT';        Category = 'Search Engines';    Label = 'Add Search Engine: YouTube (Shortcut: yt)';                     Selected = $true }
    [PSCustomObject]@{ Id = 'SRCH_YTM';       Category = 'Search Engines';    Label = 'Add Search Engine: YouTube Music (Shortcut: ytm)';              Selected = $true }
)

$Script:ConfigItemById = @{}
foreach ($item in $Script:ConfigItems) { $Script:ConfigItemById[$item.Id] = $item }

# Every policy value MEGA owns, used by the targeted reset routine.
$Script:ManagedPolicyNames = @('NewTabPageSearchBox', 'DefinePreferredLanguages', 'ApplicationLocaleValue')
foreach ($policySet in $Script:PolicySets.Values) { $Script:ManagedPolicyNames += @($policySet.Keys) }
$Script:ManagedPolicyNames = @($Script:ManagedPolicyNames | Select-Object -Unique)

# Build the menu model once; toggling selections does not change its shape.
$Script:MenuRows = [System.Collections.Generic.List[object]]::new()
$Script:MenuRowByItemIndex = @{}
$categories = @($Script:ConfigItems | ForEach-Object { $_.Category } | Select-Object -Unique)
$menuItemIndex = 0
foreach ($category in $categories) {
    $Script:MenuRows.Add([PSCustomObject]@{ Type = 'Category'; Category = $category; ItemIndex = -1; ItemObj = $null })
    foreach ($item in @($Script:ConfigItems | Where-Object { $_.Category -eq $category })) {
        $Script:MenuRowByItemIndex[$menuItemIndex] = $Script:MenuRows.Count
        $Script:MenuRows.Add([PSCustomObject]@{ Type = 'Item'; Category = $category; ItemIndex = $menuItemIndex; ItemObj = $item })
        $menuItemIndex++
    }
}

# ==============================================================================
# Helpers
# ==============================================================================

function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# A filtered token can elevate only if the account belongs to Administrators.
# Elevating with different credentials would write to the other account's HKCU.
function Test-IsAdministratorAccount {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        # Groups omits deny-only SIDs from a UAC-filtered token. Claims keeps
        # the S-1-5-32-544 deny-only entry, which is what identifies an admin
        # account that can actually elevate.
        try {
            foreach ($claim in $identity.Claims) {
                if ($claim.Value -eq 'S-1-5-32-544') { return $true }
            }
        } catch { }
        try {
            foreach ($group in $identity.Groups) {
                if ($group.Value -eq 'S-1-5-32-544') { return $true }
            }
        } catch { }
        return $false
    } catch {
        return $false
    }
}

# Detects the uncommon case where an ACL blocks the HKCU Edge policy key.
function Test-PolicyStoreWritable {
    $edgePath = 'SOFTWARE\Policies\Microsoft\Edge'
    $probePath = 'SOFTWARE\Policies\Microsoft\MEGA.WriteProbe.' + [guid]::NewGuid().ToString('N')
    $probeKey = $null
    try {
        $edgeKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($edgePath, $true)
        if ($null -ne $edgeKey) {
            try {
                $edgeKey.SetValue('MEGA.WriteProbe', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
                $edgeKey.DeleteValue('MEGA.WriteProbe', $false)
            } finally {
                $edgeKey.Close()
            }
            return $true
        }
        $probeKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($probePath)
        if ($null -eq $probeKey) { return $false }
        $probeKey.Close()
        $probeKey = $null
        return $true
    } catch {
        Write-Verbose -Message "HKCU Edge policy store is not writable: $($_.Exception.Message)"
        return $false
    } finally {
        if ($null -ne $probeKey) { $probeKey.Close() }
        try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($probePath, $false) } catch { }
    }
}

function Set-RegistryValue {
    param($Path, $Name, $Value, $Type = [Microsoft.Win32.RegistryValueKind]::DWord)
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop | Out-Null
}

function Set-PolicySettings {
    param([System.Collections.IDictionary]$Settings)
    foreach ($name in $Settings.Keys) {
        $value = $Settings[$name]
        if ($value -is [bool]) { $value = [int]$value }
        $kind = if ($value -is [string]) { [Microsoft.Win32.RegistryValueKind]::String } else { [Microsoft.Win32.RegistryValueKind]::DWord }
        Set-RegistryValue -Path $Script:PolicyBaseKey -Name $name -Value $value -Type $kind
    }
}

function Stop-EdgeProcess {
    $edgeProcesses = @(Get-Process -Name 'msedge' -ErrorAction SilentlyContinue)
    if ($edgeProcesses.Count -gt 0) {
        Stop-Process -Name 'msedge' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }
}

# Returns $null when an existing profile file cannot be parsed, so callers can
# abort before overwriting it.
function Read-JsonFile {
    param($Path, $Label)
    if (-not (Test-Path -LiteralPath $Path)) { return [PSCustomObject]@{} }
    try {
        $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($text)) { return [PSCustomObject]@{} }
        $object = $text | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $object) { throw 'The JSON document is empty.' }
        return $object
    } catch {
        Write-Host "$($Script:StyleRed)Error: Could not parse $Label.$($Script:StyleReset)"
        Write-Host "$($Script:StyleGray)$Path$($Script:StyleReset)"
        Write-Host "$($Script:StyleYellow)$($_.Exception.Message)$($Script:StyleReset)"
        Write-Host "$($Script:StyleGray)Close Edge and repair or remove the file, then try again. No files were changed.$($Script:StyleReset)"
        return $null
    }
}

function Save-JsonFile {
    param($Path, $InputObject, $Label)
    $tempPath = $Path + '.mega.tmp'
    try {
        $directory = Split-Path -Parent $Path
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
        }
        $json = $InputObject | ConvertTo-Json -Depth 100 -Compress
        [System.IO.File]::WriteAllText($tempPath, $json, $Script:Utf8NoBom)
        Move-Item -LiteralPath $tempPath -Destination $Path -Force -ErrorAction Stop
    } catch {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        throw "Could not save ${Label}: $($_.Exception.Message)"
    }
}

function Get-JsonChild {
    param($InputObject, $Name)
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property -and $property.Value -is [System.Management.Automation.PSCustomObject]) {
        return $property.Value
    }
    $child = [PSCustomObject]@{}
    $InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $child -Force
    return $child
}

function Set-JsonValue {
    param($InputObject, $Name, $Value)
    $InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Write-Status {
    param($Label, $Status, $Color)
    Write-Host "   $($Script:StyleCyan)*$($Script:StyleReset) $($Script:StyleWhite)$Label$($Script:StyleReset) $Color[$Status]$($Script:StyleReset)"
}

function Write-Header {
    param($Title, $Color = $Script:StyleCyan)
    Write-Host "$Color=======================================================$($Script:StyleReset)"
    Write-Host "         $($Script:StyleBold)$Color $Title$($Script:StyleReset)"
    Write-Host "$Color=======================================================$($Script:StyleReset)`n"
}

function Invoke-FeatureStep {
    param($Item, [scriptblock]$Action)
    if (-not $Item.Selected) { return $false }
    try {
        $null = & $Action
        Write-Status -Label $Item.Label -Status 'OK' -Color $Script:StyleGreen
        return $true
    } catch {
        Write-Status -Label $Item.Label -Status 'Failed' -Color $Script:StyleRed
        Write-Verbose -Message "Failed to apply '$($Item.Label)': $($_.Exception.Message)"
        $Script:ApplyFailures++
        return $false
    }
}

function Test-AnyItemSelected {
    param([string[]]$Ids)
    foreach ($id in $Ids) {
        if ($Script:ConfigItemById[$id].Selected) { return $true }
    }
    return $false
}

# Pauses in a real console, but not when stdin is redirected (CI or automation).
function Wait-ForKeyPress {
    try {
        if ([Console]::IsInputRedirected) { return }
        [Console]::ReadKey($true) | Out-Null
    } catch {
        # No console is attached.
    }
}

# ==============================================================================
# Apply Selected Configuration
# ==============================================================================

function Invoke-EdgeConfiguration {
    $selectedItems = @($Script:ConfigItems | Where-Object { $_.Selected })
    if ($selectedItems.Count -eq 0) {
        Write-Host "$($Script:StyleYellow)No items are selected. Use [Space] to select at least one item.$($Script:StyleReset)"
        Start-Sleep -Milliseconds 900
        return $false
    }

    $Script:ApplyFailures = 0
    $Script:PreferencesDirty = $false
    $Script:LocalStateDirty = $false

    Clear-Host
    Write-Header -Title 'Applying Selected Configurations...'

    # Edge rewrites profile files on exit, so close it before touching them.
    Stop-EdgeProcess

    $needsPreferences = Test-AnyItemSelected -Ids @('APP_VERTTABS', 'APP_HOMEPAGE', 'SET_PRIVACY_ALL', 'COP_DISABLE')
    $needsLocalState = Test-AnyItemSelected -Ids @('APP_HOMEPAGE', 'COP_DISABLE')
    $preferences = $null
    $localState = $null

    if ($needsPreferences) {
        $preferences = Read-JsonFile -Path $Script:EdgePrefPath -Label 'Edge Preferences'
        if ($null -eq $preferences) {
            Write-Host "`n$($Script:StyleYellow)Press any key to return to the menu...$($Script:StyleReset)"
            Wait-ForKeyPress
            return $false
        }
    }
    if ($needsLocalState) {
        $localState = Read-JsonFile -Path $Script:EdgeLocalState -Label 'Edge Local State'
        if ($null -eq $localState) {
            Write-Host "`n$($Script:StyleYellow)Press any key to return to the menu...$($Script:StyleReset)"
            Wait-ForKeyPress
            return $false
        }
    }

    # 1. Extensions (rebuild the force-install list from selected items).
    if (Test-Path -Path $Script:ExtensionKey) {
        Remove-Item -Path $Script:ExtensionKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $extensionIndex = 1
    foreach ($item in @($Script:ConfigItems | Where-Object { $_.Category -eq 'Target Extensions' -and $_.Selected })) {
        $applied = Invoke-FeatureStep -Item $item -Action {
            $extensionId = $Script:ExtensionIds[$item.Id]
            if ([string]::IsNullOrWhiteSpace($extensionId)) { throw "No extension id is registered for $($item.Id)." }
            Set-RegistryValue -Path $Script:ExtensionKey -Name "$extensionIndex" -Value $extensionId -Type ([Microsoft.Win32.RegistryValueKind]::String)
        }
        if ($applied) { $extensionIndex++ }
    }

    # 2. Vertical tabs and title bar.
    $verticalTabsItem = $Script:ConfigItemById['APP_VERTTABS']
    $null = Invoke-FeatureStep -Item $verticalTabsItem -Action {
        $verticalTabs = Get-JsonChild -InputObject (Get-JsonChild -InputObject $preferences -Name 'edge') -Name 'vertical_tabs'
        Set-JsonValue -InputObject $verticalTabs -Name 'opened' -Value $true
        Set-JsonValue -InputObject $verticalTabs -Name 'hide_titlebar' -Value $true
        Set-JsonValue -InputObject $verticalTabs -Name 'collapsed' -Value $false
        $Script:PreferencesDirty = $true
    }

    # 3. Homepage, new-tab page, and preferred languages.
    $homepageItem = $Script:ConfigItemById['APP_HOMEPAGE']
    $null = Invoke-FeatureStep -Item $homepageItem -Action {
        Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'DefinePreferredLanguages' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'ApplicationLocaleValue' -ErrorAction SilentlyContinue
        Set-PolicySettings -Settings $Script:PolicySets['APP_HOMEPAGE']

        $intl = Get-JsonChild -InputObject $preferences -Name 'intl'
        Set-JsonValue -InputObject $intl -Name 'accept_languages' -Value 'en,zh-TW,zh,en-GB'
        Set-JsonValue -InputObject $intl -Name 'selected_languages' -Value 'en,zh-TW,en-GB'

        $edgeNewTab = Get-JsonChild -InputObject (Get-JsonChild -InputObject $preferences -Name 'edge') -Name 'new_tab_page'
        $rootNewTab = Get-JsonChild -InputObject $preferences -Name 'new_tab_page'
        foreach ($name in $Script:NewTabPageSettings.Keys) {
            Set-JsonValue -InputObject $edgeNewTab -Name $name -Value $Script:NewTabPageSettings[$name]
            Set-JsonValue -InputObject $rootNewTab -Name $name -Value $Script:NewTabPageSettings[$name]
        }

        $stateIntl = Get-JsonChild -InputObject $localState -Name 'intl'
        Set-JsonValue -InputObject $stateIntl -Name 'app_locale' -Value 'en'
        $Script:PreferencesDirty = $true
        $Script:LocalStateDirty = $true
    }

    # 4. Privacy and security hardening.
    $privacyItem = $Script:ConfigItemById['SET_PRIVACY_ALL']
    $null = Invoke-FeatureStep -Item $privacyItem -Action {
        Set-PolicySettings -Settings $Script:PolicySets['SET_PRIVACY_ALL']
        $edge = Get-JsonChild -InputObject $preferences -Name 'edge'
        Set-JsonValue -InputObject (Get-JsonChild -InputObject $edge -Name 'shopping') -Name 'enabled' -Value $false
        Set-JsonValue -InputObject (Get-JsonChild -InputObject $edge -Name 'tab_organization') -Name 'enabled' -Value $false
        $Script:PreferencesDirty = $true
    }

    # 5. Copilot and AI removal.
    $copilotItem = $Script:ConfigItemById['COP_DISABLE']
    $null = Invoke-FeatureStep -Item $copilotItem -Action {
        Set-PolicySettings -Settings $Script:PolicySets['COP_DISABLE']

        $browser = Get-JsonChild -InputObject $localState -Name 'browser'
        $existingFlags = @()
        if ($null -ne $browser.PSObject.Properties['enabled_labs_experiments']) {
            $existingFlags = @($browser.enabled_labs_experiments)
        }
        $flagList = [System.Collections.Generic.List[string]]::new()
        foreach ($flag in $existingFlags) {
            if (-not [string]::IsNullOrWhiteSpace([string]$flag)) { $flagList.Add([string]$flag) }
        }
        foreach ($flag in $Script:CopilotExperimentFlags) {
            if (-not $flagList.Contains($flag)) { $flagList.Add($flag) }
        }
        Set-JsonValue -InputObject $browser -Name 'enabled_labs_experiments' -Value $flagList.ToArray()

        $sidebar = Get-JsonChild -InputObject (Get-JsonChild -InputObject $preferences -Name 'edge') -Name 'sidebar'
        Set-JsonValue -InputObject $sidebar -Name 'show_copilot_button' -Value $false
        Set-JsonValue -InputObject $sidebar -Name 'show_sidebar' -Value $false
        $Script:LocalStateDirty = $true
        $Script:PreferencesDirty = $true
    }

    # 6. Search engines (rebuild the managed list from selected items).
    Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'DefaultSearchProvider*' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $Script:PolicyBaseKey -Name 'NewTabPageSearchBox' -ErrorAction SilentlyContinue
    Remove-Item -Path "$($Script:PolicyBaseKey)\SiteSearchSettings" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    if (Test-Path -Path $Script:ManagedSearchKey) {
        Remove-Item -Path $Script:ManagedSearchKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $engineIndex = 1
    foreach ($item in @($Script:ConfigItems | Where-Object { $_.Category -eq 'Search Engines' -and $_.Selected })) {
        $applied = Invoke-FeatureStep -Item $item -Action {
            $engine = $Script:SearchEngines[$item.Id]
            if ($null -eq $engine) { throw "No search engine is registered for $($item.Id)." }
            if ($Script:SearchEnginePolicies.Contains($item.Id)) {
                Set-PolicySettings -Settings $Script:SearchEnginePolicies[$item.Id]
            }
            Set-RegistryValue -Path $Script:ManagedSearchKey -Name "$engineIndex" -Value ($engine | ConvertTo-Json -Compress) -Type ([Microsoft.Win32.RegistryValueKind]::String)
        }
        if ($applied) { $engineIndex++ }
    }

    # 7. Persist profile changes only when MEGA touched them.
    foreach ($target in @(
            @{ Path = $Script:EdgePrefPath; Object = $preferences; Dirty = $Script:PreferencesDirty; Label = 'Edge Preferences' },
            @{ Path = $Script:EdgeLocalState; Object = $localState; Dirty = $Script:LocalStateDirty; Label = 'Edge Local State' })) {
        if (-not $target.Dirty) { continue }
        try {
            Save-JsonFile -Path $target.Path -InputObject $target.Object -Label $target.Label
        } catch {
            Write-Status -Label "Save $($target.Label)" -Status 'Failed' -Color $Script:StyleRed
            Write-Verbose -Message $_.Exception.Message
            $Script:ApplyFailures++
        }
    }

    Write-Host "`n$($Script:StyleCyan)-------------------------------------------------------$($Script:StyleReset)"
    if ($Script:ApplyFailures -eq 0) {
        Write-Host "$($Script:StyleBold)$($Script:StyleGreen)[SUCCESS]$($Script:StyleReset) $($Script:StyleWhite)Configurations applied successfully.$($Script:StyleReset)"
    } else {
        Write-Host "$($Script:StyleBold)$($Script:StyleYellow)[PARTIAL]$($Script:StyleReset) $($Script:StyleWhite)Completed with $($Script:ApplyFailures) failed operation(s). Review the output above.$($Script:StyleReset)"
    }
    Write-Host "$($Script:StyleYellow)Please restart Microsoft Edge to complete setup.$($Script:StyleReset)"
    Write-Host "`n$($Script:StyleGray)Press any key to exit...$($Script:StyleReset)"
    Wait-ForKeyPress
    try { [Console]::CursorVisible = $true } catch { }
    return $true
}

# ==============================================================================
# Reset Managed Policies
# ==============================================================================

function Reset-EdgePolicy {
    Clear-Host
    Write-Header -Title 'Confirm Reset Policies' -Color $Script:StyleYellow
    Write-Host " $($Script:StyleWhite)Are you sure you want to remove all MEGA-managed policies? [Y/N]: $($Script:StyleReset)" -NoNewline
    if (([Console]::ReadKey($true)).Key -ne [ConsoleKey]::Y) {
        Write-Host "$($Script:StyleGray)[Cancelled]$($Script:StyleReset)"
        Start-Sleep -Milliseconds 600
        return $false
    }

    Write-Host "$($Script:StyleGreen)[Confirmed]$($Script:StyleReset)`n"
    Write-Header -Title 'Removing All Managed Policies...'
    Stop-EdgeProcess

    $resetFailures = 0
    $policyKeyExisted = Test-Path -Path $Script:PolicyBaseKey
    $policyCleanupFailed = $false

    if ($policyKeyExisted) {
        try {
            $valueNames = @((Get-Item -Path $Script:PolicyBaseKey -ErrorAction Stop).GetValueNames())
            foreach ($name in $Script:ManagedPolicyNames) {
                if ($valueNames -contains $name) {
                    try { Remove-ItemProperty -Path $Script:PolicyBaseKey -Name $name -ErrorAction Stop }
                    catch { $policyCleanupFailed = $true; Write-Verbose -Message "Could not remove policy '$name': $($_.Exception.Message)" }
                }
            }
            foreach ($name in @($valueNames | Where-Object { $_ -like 'DefaultSearchProvider*' })) {
                try { Remove-ItemProperty -Path $Script:PolicyBaseKey -Name $name -ErrorAction Stop }
                catch { $policyCleanupFailed = $true; Write-Verbose -Message "Could not remove policy '$name': $($_.Exception.Message)" }
            }
        } catch {
            $policyCleanupFailed = $true
            Write-Verbose -Message "Could not read the Edge policy key: $($_.Exception.Message)"
        }
        foreach ($subKeyName in @('ExtensionInstallForcelist', 'ManagedSearchEngines', 'SiteSearchSettings')) {
            $subKeyPath = "$($Script:PolicyBaseKey)\$subKeyName"
            if (Test-Path -Path $subKeyPath) {
                try { Remove-Item -Path $subKeyPath -Recurse -Force -ErrorAction Stop }
                catch { $policyCleanupFailed = $true; Write-Verbose -Message "Could not remove policy key '$subKeyName': $($_.Exception.Message)" }
            }
        }

        # Remove an empty MEGA-created Edge key so Edge stops reporting managed
        # policies. Unrelated values or subkeys keep the key in place.
        $remainingKey = Get-Item -Path $Script:PolicyBaseKey -ErrorAction SilentlyContinue
        if ($null -ne $remainingKey) {
            $remainingValues = @($remainingKey.GetValueNames())
            $remainingSubKeys = @($remainingKey.GetSubKeyNames())
            if ($remainingKey -is [Microsoft.Win32.RegistryKey]) { $remainingKey.Close() }
            if ($remainingValues.Count -eq 0 -and $remainingSubKeys.Count -eq 0) {
                try { Remove-Item -Path $Script:PolicyBaseKey -Force -ErrorAction Stop }
                catch { $policyCleanupFailed = $true; Write-Verbose -Message "Could not remove the empty Edge policy key: $($_.Exception.Message)" }
            }
        }
    }

    if (-not $policyKeyExisted) {
        Write-Status -Label 'Edge Policies Status:' -Status 'Not Found' -Color $Script:StyleGray
    } elseif ($policyCleanupFailed) {
        Write-Status -Label 'Edge Policies Status:' -Status 'Failed' -Color $Script:StyleRed
        $resetFailures++
    } else {
        Write-Status -Label 'Edge Policies Status:' -Status 'Cleared' -Color $Script:StyleGreen
    }

    # Revert the experiment flags MEGA added to Local State.
    $experimentStatus = 'Not Found'
    $experimentColor = $Script:StyleGray
    if (Test-Path -LiteralPath $Script:EdgeLocalState) {
        $experimentStatus = 'No Change'
        try {
            $state = Get-Content -LiteralPath $Script:EdgeLocalState -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $state.PSObject.Properties['browser'] -and $null -ne $state.browser -and $null -ne $state.browser.PSObject.Properties['enabled_labs_experiments']) {
                $before = @($state.browser.enabled_labs_experiments)
                $after = @($before | Where-Object { $_ -notin $Script:CopilotExperimentFlags })
                if ($after.Count -ne $before.Count) {
                    Set-JsonValue -InputObject $state.browser -Name 'enabled_labs_experiments' -Value @($after)
                    Save-JsonFile -Path $Script:EdgeLocalState -InputObject $state -Label 'Edge Local State'
                    $experimentStatus = 'Reverted'
                    $experimentColor = $Script:StyleGreen
                }
            }
        } catch {
            $experimentStatus = 'Failed'
            $experimentColor = $Script:StyleRed
            $resetFailures++
            Write-Verbose -Message "Could not revert Local State experiment flags: $($_.Exception.Message)"
        }
    }
    Write-Status -Label 'Experiments Status:' -Status $experimentStatus -Color $experimentColor

    Write-Host "`n$($Script:StyleCyan)-------------------------------------------------------$($Script:StyleReset)"
    if ($resetFailures -eq 0) {
        Write-Host "$($Script:StyleBold)$($Script:StyleGreen)[SUCCESS]$($Script:StyleReset) $($Script:StyleWhite)All MEGA-managed policies were removed.$($Script:StyleReset)"
    } else {
        Write-Host "$($Script:StyleBold)$($Script:StyleYellow)[PARTIAL]$($Script:StyleReset) $($Script:StyleWhite)Reset completed with $resetFailures failed operation(s).$($Script:StyleReset)"
    }
    Write-Host "$($Script:StyleGray)Profile preferences changed by MEGA (layout, new-tab page, languages) are preserved; adjust them in Edge Settings if desired.$($Script:StyleReset)"
    Write-Host "$($Script:StyleYellow)Please restart Microsoft Edge to apply changes.$($Script:StyleReset)"
    Write-Host "`n$($Script:StyleGray)Press any key to exit...$($Script:StyleReset)"
    Wait-ForKeyPress
    try { [Console]::CursorVisible = $true } catch { }
    return $true
}

# ==============================================================================
# Interactive TUI
# ==============================================================================

function Show-Menu {
    param([int]$CurrentIndex)

    $windowHeight = try { [Console]::WindowHeight } catch { 25 }
    if ($windowHeight -lt 10) { $windowHeight = 10 }
    $availableContentLines = [int][math]::Max(3, $windowHeight - 8)

    $targetRowIndex = 0
    if ($Script:MenuRowByItemIndex.ContainsKey($CurrentIndex)) { $targetRowIndex = $Script:MenuRowByItemIndex[$CurrentIndex] }

    $rowCount = $Script:MenuRows.Count
    if ($rowCount -le $availableContentLines) {
        $startIndex = 0
        $endIndex = $rowCount - 1
    } else {
        $startIndex = [int][math]::Max(0, $targetRowIndex - [math]::Floor($availableContentLines / 2))
        $endIndex = $startIndex + $availableContentLines - 1
        if ($endIndex -ge $rowCount) {
            $endIndex = $rowCount - 1
            $startIndex = [int][math]::Max(0, $endIndex - $availableContentLines + 1)
        }
    }

    [Console]::Write("$Esc[H")
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host "        $($Script:StyleBold)$($Script:StyleCyan) Make Edge Google Again (MEGA) Deployer$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host "$($Script:StyleCyan)=======================================================$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host " $($Script:StyleGray)[$($Script:ArrowUp)$($Script:ArrowDown)/kj] Move   [Space] Toggle   [A] All   [N] None$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host " $($Script:StyleGray)[Enter] Apply Selected    [R] Reset All    [Q] Exit$($Script:StyleReset)$($Script:ClearLineRight)"
    Write-Host "$($Script:StyleCyan)-------------------------------------------------------$($Script:StyleReset)$($Script:ClearLineRight)"

    if ($startIndex -gt 0) {
        Write-Host "  $($Script:StyleGray)$($Script:ArrowUp) more items above$($Script:StyleReset)$($Script:ClearLineRight)"
    }
    for ($rowIndex = $startIndex; $rowIndex -le $endIndex; $rowIndex++) {
        $row = $Script:MenuRows[$rowIndex]
        if ($row.Type -eq 'Category') {
            Write-Host "$($Script:StyleBold)$($Script:StyleCyan)## $($row.Category)$($Script:StyleReset)$($Script:ClearLineRight)"
            continue
        }
        $item = $row.ItemObj
        $checkMark = if ($item.Selected) { "$($Script:StyleGreen)[X]$($Script:StyleReset)" } else { "$($Script:StyleGray)[ ]$($Script:StyleReset)" }
        if ($row.ItemIndex -eq $CurrentIndex) {
            Write-Host "  $($Script:StyleYellow)>$($Script:StyleReset) $checkMark $($Script:StyleBold)$($Script:StyleWhite)$($item.Label)$($Script:StyleReset) $($Script:ClearLineRight)"
        } else {
            Write-Host "    $checkMark $($Script:StyleWhite)$($item.Label)$($Script:StyleReset) $($Script:ClearLineRight)"
        }
    }
    if ($endIndex -lt ($rowCount - 1)) {
        Write-Host "  $($Script:StyleGray)$($Script:ArrowDown) more items below$($Script:StyleReset)$($Script:ClearLineRight)"
    }
    [Console]::Write($Script:ClearScreenBelow)
}

# ==============================================================================
# Elevation
# ==============================================================================

function Save-RemoteScript {
    param($Url)
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("MEGA-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    try {
        # GitHub requires TLS 1.2; Windows PowerShell 5.1 does not always enable it.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace([string]$response.Content)) { throw 'The download returned an empty script.' }
        $content = ([string]$response.Content).TrimStart([char[]]@([char]0xFEFF))
        [System.IO.File]::WriteAllText($tempPath, $content, [System.Text.UTF8Encoding]::new($true))
        return $tempPath
    } catch {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        throw "Could not download the elevated copy of MEGA: $($_.Exception.Message)"
    }
}

function Get-ElevationInvocation {
    $processPath = $null
    try { $processPath = (Get-Process -Id $PID -ErrorAction Stop).Path } catch {
        try { $processPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($processPath)) { throw 'Could not determine the current PowerShell executable.' }

    $hostName = [System.IO.Path]::GetFileNameWithoutExtension($processPath).ToLowerInvariant()
    if ($hostName -notin @('powershell', 'pwsh', 'powershell_ise')) {
        return [PSCustomObject]@{ FilePath = $processPath; ArgumentList = $null; TempFile = $null }
    }

    $shellPath = $processPath
    if ($hostName -eq 'powershell_ise') { $shellPath = Join-Path $PSHOME 'powershell.exe' }

    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        return [PSCustomObject]@{
            FilePath = $shellPath
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            TempFile = $null
        }
    }

    # With the documented "irm ... | iex" one-liner there is no script path and
    # PowerShell does not expose the evaluated source, so fetch the canonical
    # script for the elevated session.
    $tempPath = Save-RemoteScript -Url $Script:ProjectRawUrl
    return [PSCustomObject]@{
        FilePath = $shellPath
        ArgumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$tempPath`""
        TempFile = $tempPath
    }
}

function Request-AdministratorRelaunch {
    param($Reason)

    if ($env:MEGA_ELEVATED -eq '1') {
        Write-Host "$($Script:StyleRed)Error: Administrator privileges are still required after elevation.$($Script:StyleReset)"
        Write-Host "$($Script:StyleYellow)Check the permissions on HKCU\SOFTWARE\Policies\Microsoft\Edge, or run PowerShell as Administrator manually.$($Script:StyleReset)"
        return
    }

    if (-not (Test-IsAdministratorAccount)) {
        Write-Host "$($Script:StyleRed)Error: This account cannot be elevated for this user's HKCU policy key.$($Script:StyleReset)"
        Write-Host "$($Script:StyleYellow)MEGA could not confirm that this account is a local administrator. Elevating with different credentials would write Edge policies to the other account's HKCU, not yours.$($Script:StyleReset)"
        Write-Host "$($Script:StyleGray)Ask an administrator to grant this account write access to HKCU\SOFTWARE\Policies\Microsoft\Edge, then run MEGA again.$($Script:StyleReset)"
        return
    }

    try {
        $invocation = Get-ElevationInvocation
    } catch {
        Write-Host "$($Script:StyleRed)Error: $($_.Exception.Message)$($Script:StyleReset)"
        Write-Host "$($Script:StyleYellow)Run PowerShell as Administrator and try again.$($Script:StyleReset)"
        return
    }

    Write-Host "$($Script:StyleYellow)$Reason$($Script:StyleReset)"
    Write-Host "$($Script:StyleCyan)Requesting administrator privileges (UAC)...$($Script:StyleReset)"
    $previousElevationFlag = $env:MEGA_ELEVATED
    $env:MEGA_ELEVATED = '1'
    try {
        $startParams = @{ FilePath = $invocation.FilePath; Verb = 'RunAs'; PassThru = $true; Wait = $true; ErrorAction = 'Stop' }
        if (-not [string]::IsNullOrWhiteSpace($invocation.ArgumentList)) { $startParams['ArgumentList'] = $invocation.ArgumentList }
        $process = Start-Process @startParams
        if ($process.ExitCode -ne 0) {
            Write-Host "$($Script:StyleYellow)The elevated session exited with code $($process.ExitCode).$($Script:StyleReset)"
        }
    } catch {
        Write-Host "$($Script:StyleRed)Error: Could not obtain administrator privileges.$($Script:StyleReset)"
        Write-Host "$($Script:StyleYellow)$($_.Exception.Message)$($Script:StyleReset)"
        Write-Host "$($Script:StyleGray)Run PowerShell as Administrator and try again, or unlock HKCU\SOFTWARE\Policies\Microsoft\Edge for this user.$($Script:StyleReset)"
    } finally {
        $env:MEGA_ELEVATED = $previousElevationFlag
        if ($invocation.TempFile -and (Test-Path -LiteralPath $invocation.TempFile)) {
            Remove-Item -LiteralPath $invocation.TempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# ==============================================================================
# Entry Point
# ==============================================================================

function Invoke-Main {
    if (-not $Script:IsWindowsOS) {
        Write-Host "$($Script:StyleRed)Error: MEGA supports Windows 10 and Windows 11 only.$($Script:StyleReset)"
        return
    }

    try {
        if ([Console]::IsInputRedirected) {
            Write-Host "$($Script:StyleRed)Error: MEGA's interactive menu requires a console with keyboard input.$($Script:StyleReset)"
            Write-Host "$($Script:StyleYellow)Run MEGA from an interactive PowerShell window instead of redirected input.$($Script:StyleReset)"
            return
        }
    } catch { }

    $isAdmin = Test-IsAdmin
    if ($Script:ElevateRequested -and -not $isAdmin) {
        Request-AdministratorRelaunch -Reason 'Elevation was requested with -Elevate.'
        return
    }
    if (-not (Test-PolicyStoreWritable)) {
        if (-not $isAdmin) {
            Request-AdministratorRelaunch -Reason 'Windows is blocking writes to the HKCU Edge policy key.'
            return
        }
        Write-Host "$($Script:StyleRed)Error: The HKCU Edge policy key is not writable, even with administrator privileges.$($Script:StyleReset)"
        Write-Host "$($Script:StyleYellow)Check the ACLs on HKCU\SOFTWARE\Policies\Microsoft\Edge before running MEGA again.$($Script:StyleReset)"
        return
    }

    try { [Console]::CursorVisible = $false } catch { }
    Clear-Host
    $currentIndex = 0
    $totalItems = $Script:ConfigItems.Count
    try {
        while ($true) {
            Show-Menu -CurrentIndex $currentIndex
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                { $_ -in [ConsoleKey]::UpArrow, [ConsoleKey]::K } {
                    $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $totalItems - 1 }
                }
                { $_ -in [ConsoleKey]::DownArrow, [ConsoleKey]::J } {
                    $currentIndex = if ($currentIndex -lt ($totalItems - 1)) { $currentIndex + 1 } else { 0 }
                }
                ([ConsoleKey]::Spacebar) { $Script:ConfigItems[$currentIndex].Selected = -not $Script:ConfigItems[$currentIndex].Selected }
                ([ConsoleKey]::A) { $Script:ConfigItems | ForEach-Object { $_.Selected = $true } }
                ([ConsoleKey]::N) { $Script:ConfigItems | ForEach-Object { $_.Selected = $false } }
                ([ConsoleKey]::Enter) { if (Invoke-EdgeConfiguration) { return } }
                ([ConsoleKey]::R) { if (Reset-EdgePolicy) { return }; Clear-Host }
                ([ConsoleKey]::Q) {
                    Clear-Host
                    Write-Host "$($Script:StyleGray)Exiting setup. Goodbye.$($Script:StyleReset)"
                    return
                }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch { }
    }
}

# Execute the entry point unless this file is dot-sourced (tests do that).
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
