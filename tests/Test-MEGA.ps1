#Requires -Version 5.1

<#
.SYNOPSIS
    Offline regression checks for MEGA's data model and apply pipeline.

.DESCRIPTION
    Dot-sources MEGA.ps1, validates the feature catalogue, then runs the apply
    pipeline against a temporary Edge profile with all registry writes mocked.
    No real Edge profile, registry value, or running Edge process is touched.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'MEGA.ps1')

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:Failures.Add($Message) }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        $script:Failures.Add("$Message (expected [$Expected], got [$Actual])")
    }
}

# ------------------------------------------------------------------------------
# Data model
# ------------------------------------------------------------------------------

Assert-Equal 14 $ConfigItems.Count 'ConfigItems count'
Assert-Equal 14 (@($ConfigItems.Id | Select-Object -Unique).Count) 'ConfigItems ids must be unique'
Assert-Equal 'Target Extensions,Appearance,Privacy & Security,Copilot & AI,Search Engines' (@($ConfigItems.Category | Select-Object -Unique) -join ',') 'ConfigItems category order'

$expectedExtensions = [ordered]@{
    EXT_ZOTERO     = 'nmhdhpibnnopknkmonacoephklnflpho'
    EXT_UBLOCK     = 'odfafepnkmbhccpbejgmiehpchacaeak'
    EXT_SPONSOR    = 'mbmgnelfcpoecdepckhlhegpcehmpmji'
    EXT_FLUENTREAD = 'kakgmllfpjldjhcnkghpplmlbnmcoflp'
}
Assert-Equal 4 $ExtensionIds.Count 'extension catalogue count'
foreach ($key in $expectedExtensions.Keys) {
    Assert-Equal $expectedExtensions[$key] $ExtensionIds[$key] "extension id for $key"
    Assert-True ($ExtensionIds[$key] -match '^[a-p]{32}$') "extension id format for $key"
}

$fluentRead = $ConfigItemById['EXT_FLUENTREAD']
Assert-True ($null -ne $fluentRead -and $fluentRead.Label -like 'FluentRead*') 'FluentRead item is present'
Assert-True ($fluentRead.Category -eq 'Target Extensions') 'FluentRead is an extension item'
Assert-True ($fluentRead.Selected) 'FluentRead is selected by default'

Assert-Equal 6 $SearchEngines.Count 'search engine catalogue count'
foreach ($key in $SearchEngines.Keys) {
    $engine = $SearchEngines[$key]
    Assert-True ($engine.search_url -like '*{searchTerms}*') "search placeholder for $key"
    Assert-True (-not [string]::IsNullOrWhiteSpace($engine.name)) "search name for $key"
    $roundTrip = ($engine | ConvertTo-Json -Compress) | ConvertFrom-Json
    Assert-Equal $engine.name $roundTrip.name "search JSON round-trip for $key"
}
Assert-True ($SearchEngines['SRCH_GOOGLE'].is_default -eq $true) 'Google is the default engine'
Assert-True ($null -eq $SearchEngines['SRCH_AI'].is_default) 'non-default engines omit is_default'

Assert-Equal 2 $PolicySets['APP_HOMEPAGE'].Count 'homepage policy count'
Assert-Equal 15 $PolicySets['SET_PRIVACY_ALL'].Count 'privacy policy count'
Assert-Equal 11 $PolicySets['COP_DISABLE'].Count 'Copilot policy count'
Assert-Equal 31 $ManagedPolicyNames.Count 'managed policy name count'
foreach ($name in @('NewTabPageSearchBox', 'WebRtcLocalIpHdrHandling', 'ComposeInlineEnabled')) {
    Assert-True ($ManagedPolicyNames -contains $name) "managed policy list contains $name"
}

Assert-Equal 19 $MenuRows.Count 'menu row count'
Assert-Equal 14 $MenuRowByItemIndex.Count 'menu item map count'
Assert-Equal 'Category' $MenuRows[0].Type 'first menu row is a category'
Assert-Equal 'EXT_ZOTERO' $MenuRows[1].ItemObj.Id 'first selectable item is Zotero'
foreach ($index in 0..($ConfigItems.Count - 1)) {
    Assert-True ($MenuRowByItemIndex.ContainsKey($index)) "menu row for item index $index"
}

# ------------------------------------------------------------------------------
# Apply pipeline (mocked registry, temporary profile)
# ------------------------------------------------------------------------------

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('mega-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $Script:EdgePrefPath = Join-Path $testRoot 'Preferences'
    $Script:EdgeLocalState = Join-Path $testRoot 'Local State'

    @'
{
  "keep": "untouched",
  "edge": {
    "vertical_tabs": { "opened": false, "hide_titlebar": false, "collapsed": true },
    "shopping": { "enabled": true },
    "sidebar": { "show_sidebar": true, "other": "keep" },
    "new_tab_page": { "market": "en-us", "keep": "ntp" }
  },
  "intl": { "accept_languages": "fr" }
}
'@ | Set-Content -LiteralPath $Script:EdgePrefPath -Encoding UTF8

    @'
{
  "browser": { "enabled_labs_experiments": ["keep-flag"], "other": "keep" },
  "keep": "state"
}
'@ | Set-Content -LiteralPath $Script:EdgeLocalState -Encoding UTF8

    $script:RegistryWrites = [System.Collections.Generic.List[object]]::new()

    # Mocks: record policy writes and prevent any real registry mutation.
    function Set-RegistryValue {
        param($Path, $Name, $Value, $Type = [Microsoft.Win32.RegistryValueKind]::DWord)
        $script:RegistryWrites.Add([PSCustomObject]@{ Path = $Path; Name = $Name; Value = $Value; Type = "$Type" })
    }
    function Stop-EdgeProcess { }
    function Clear-Host { }
    function Wait-ForKeyPress { }
    function Remove-Item {
        [CmdletBinding()]
        param($Path, [switch]$Recurse, [switch]$Force)
        if ($Path -like 'HKCU:*') { return }
        Microsoft.PowerShell.Management\Remove-Item -Path $Path -Recurse:$Recurse -Force:$Force -ErrorAction SilentlyContinue
    }
    function Remove-ItemProperty {
        [CmdletBinding()]
        param($Path, $Name)
        if ($Path -like 'HKCU:*') { return }
        Microsoft.PowerShell.Management\Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    }

    $result = Invoke-EdgeConfiguration
    Assert-True $result 'apply returns success'
    Assert-Equal 39 $RegistryWrites.Count 'apply registry write count'

    $extensionWrites = @($RegistryWrites | Where-Object { $_.Path -like '*ExtensionInstallForcelist' })
    Assert-Equal 4 $extensionWrites.Count 'extension write count'
    Assert-Equal 'nmhdhpibnnopknkmonacoephklnflpho' ($extensionWrites[0].Value) 'Zotero force-install id'
    Assert-Equal 'odfafepnkmbhccpbejgmiehpchacaeak' ($extensionWrites[1].Value) 'uBlock force-install id'
    Assert-Equal 'mbmgnelfcpoecdepckhlhegpcehmpmji' ($extensionWrites[2].Value) 'SponsorBlock force-install id'
    Assert-Equal 'kakgmllfpjldjhcnkghpplmlbnmcoflp' ($extensionWrites[3].Value) 'FluentRead force-install id'

    $searchWrites = @($RegistryWrites | Where-Object { $_.Path -like '*ManagedSearchEngines' })
    Assert-Equal 6 $searchWrites.Count 'managed search engine count'
    Assert-Equal 'Google' (($searchWrites[0].Value | ConvertFrom-Json).name) 'first managed engine is Google'
    Assert-True ((($searchWrites[0].Value | ConvertFrom-Json).is_default) -eq $true) 'Google is marked default'

    $policyWrites = @($RegistryWrites | Where-Object { $_.Path -eq 'HKCU:\SOFTWARE\Policies\Microsoft\Edge' })
    Assert-Equal 29 $policyWrites.Count 'policy value write count'
    $redirect = @($policyWrites | Where-Object { $_.Name -eq 'NewTabPageSearchBox' })
    Assert-Equal 1 $redirect.Count 'new-tab search redirect is written'
    Assert-Equal 'redirect' ($redirect[0].Value) 'new-tab search redirect value'
    $webrtc = @($policyWrites | Where-Object { $_.Name -eq 'WebRtcLocalIpHdrHandling' })
    Assert-Equal 'String' ($webrtc[0].Type) 'WebRTC policy is a string value'
    Assert-Equal 'disable_non_proxied_udp' ($webrtc[0].Value) 'WebRTC policy value'

    $preferences = Get-Content -LiteralPath $Script:EdgePrefPath -Raw | ConvertFrom-Json
    Assert-Equal 'untouched' $preferences.keep 'unrelated preference is preserved'
    Assert-Equal $true $preferences.edge.vertical_tabs.opened 'vertical tabs opened'
    Assert-Equal $true $preferences.edge.vertical_tabs.hide_titlebar 'title bar hidden'
    Assert-Equal 'keep' $preferences.edge.sidebar.other 'unrelated sidebar preference is preserved'
    Assert-Equal 'en-gb' $preferences.edge.new_tab_page.market 'edge new-tab market'
    Assert-Equal 'ntp' $preferences.edge.new_tab_page.keep 'unrelated new-tab preference is preserved'
    Assert-Equal 'en-gb' $preferences.new_tab_page.market 'root new-tab market'
    Assert-Equal 'en,zh-TW,en-GB' $preferences.intl.selected_languages 'selected languages'

    $localState = Get-Content -LiteralPath $Script:EdgeLocalState -Raw | ConvertFrom-Json
    Assert-Equal 'state' $localState.keep 'unrelated local state is preserved'
    Assert-Equal 'keep' $localState.browser.other 'unrelated browser local state is preserved'
    Assert-Equal 'en' $localState.intl.app_locale 'Edge display locale'
    $flags = @($localState.browser.enabled_labs_experiments)
    Assert-True ($flags -contains 'keep-flag') 'user experiment flag is preserved'
    foreach ($flag in $CopilotExperimentFlags) {
        Assert-True ($flags -contains $flag) "Copilot flag $flag is added"
    }

    # A corrupt profile must abort before any write, not silently reset it.
    $writeCountBeforeCorrupt = $RegistryWrites.Count
    '{ not valid json' | Set-Content -LiteralPath $Script:EdgePrefPath -Encoding UTF8
    $result = Invoke-EdgeConfiguration
    Assert-True (-not $result) 'corrupt Preferences aborts apply'
    Assert-Equal $writeCountBeforeCorrupt $RegistryWrites.Count 'corrupt Preferences performs no registry writes'
    Assert-Equal '{ not valid json' ((Get-Content -LiteralPath $Script:EdgePrefPath -Raw).Trim()) 'corrupt Preferences is not overwritten'

    # Applying an empty selection must not clear managed policies.
    $ConfigItems | ForEach-Object { $_.Selected = $false }
    $writeCountBeforeEmpty = $RegistryWrites.Count
    $result = Invoke-EdgeConfiguration
    Assert-True (-not $result) 'empty selection aborts apply'
    Assert-Equal $writeCountBeforeEmpty $RegistryWrites.Count 'empty selection performs no registry writes'
} finally {
    if ($testRoot -and [System.IO.Directory]::Exists($testRoot)) {
        [System.IO.Directory]::Delete($testRoot, $true)
    }
}

if ($script:Failures.Count -gt 0) {
    Write-Host ''
    Write-Host "FAILED: $($script:Failures.Count) check(s) failed." -ForegroundColor Red
    foreach ($failure in $script:Failures) { Write-Host " - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host "All MEGA checks passed." -ForegroundColor Green
