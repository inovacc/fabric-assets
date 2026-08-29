[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [switch]$PrintDigest
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { throw "ASSET.CONTRACT: $Message" }

function Get-Sha256([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

function Test-RelativeOutputPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Contains('\\') -or $Path.Contains(':') -or $Path.StartsWith('/') -or $Path.StartsWith('//')) { Fail "invalid template output path '$Path'" }
    foreach ($part in $Path.Split('/')) {
        if ($part -in @('', '.', '..') -or $part.TrimEnd('.', ' ') -ne $part) { Fail "invalid template output path '$Path'" }
        $stem = $part.Split('.')[0].ToUpperInvariant()
        if ($stem -in @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')) { Fail "Windows device name in output path '$Path'" }
    }
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$bundlePath = Join-Path $rootPath 'bundles/fabric-assets-v1.json'
$allowPath = Join-Path $rootPath 'catalog/curated-allow-list.json'
if (-not (Test-Path -LiteralPath $bundlePath)) { Fail "missing bundle manifest '$bundlePath'" }
if (-not (Test-Path -LiteralPath $allowPath)) { Fail "missing curated allow-list '$allowPath'" }

$bundle = Get-Content -LiteralPath $bundlePath -Raw | ConvertFrom-Json -AsHashtable
$allow = Get-Content -LiteralPath $allowPath -Raw | ConvertFrom-Json -AsHashtable
foreach ($field in @('contractVersion', 'bundleId', 'bundleVersion', 'supportedFabric', 'manifestDigest', 'dependencies', 'templates')) {
    if (-not $bundle.ContainsKey($field)) { Fail "missing bundle field '$field'" }
}
if ($bundle.contractVersion -ne 'fabric-assets/v1') { Fail "unsupported contract version '$($bundle.contractVersion)'" }
if ($bundle.bundleId -notmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'bundleId is not stable lowercase kebab case' }
if ($bundle.bundleVersion -notmatch '^\d+\.\d+\.\d+$') { Fail 'bundleVersion is not an exact semantic version' }
if ($bundle.manifestDigest -notmatch '^[a-f0-9]{64}$') { Fail 'manifestDigest must be lowercase SHA-256' }

$copy = [ordered]@{}
foreach ($property in $bundle.GetEnumerator()) { if ($property.Key -ne 'manifestDigest') { $copy[$property.Key] = $property.Value } }
$computedDigest = Get-Sha256 ([Text.Encoding]::UTF8.GetBytes(($copy | ConvertTo-Json -Depth 100 -Compress)))
if ($PrintDigest) { Write-Output $computedDigest; return }
if ($bundle.manifestDigest -ne $computedDigest) { Fail "manifest digest mismatch; expected $computedDigest" }

$allowedIds = @($allow.dependencyIds)
foreach ($dependency in @($bundle.dependencies)) {
    if ($dependency.Keys.Count -ne 2 -or -not $dependency.ContainsKey('id') -or -not $dependency.ContainsKey('version')) { Fail 'dependency must contain exactly id and version' }
    if ($dependency.id -notin $allowedIds) { Fail "dependency '$($dependency.id)' is not curated" }
    if ($dependency.version -notmatch '^\d+(\.\d+){1,3}(-[0-9A-Za-z.-]+)?$') { Fail "dynamic version '$($dependency.version)' for dependency '$($dependency.id)'" }
}

$seen = @{}
$allowedTokens = @($allow.renderTokens)
foreach ($template in @($bundle.templates)) {
    foreach ($field in @('profile', 'source', 'output', 'ownership', 'tokens', 'sha256')) { if (-not $template.ContainsKey($field)) { Fail "template missing field '$field'" } }
    Test-RelativeOutputPath $template.output
    $folded = $template.output.ToLowerInvariant()
    if ($seen.ContainsKey($folded)) { Fail "duplicate or Windows-colliding output '$($template.output)'" }
    $seen[$folded] = $true
    if ($template.ownership -notin @('managed', 'userSeed', 'metadata', 'runtimeState')) { Fail "invalid ownership '$($template.ownership)'" }
    if ($template.sha256 -notmatch '^[a-f0-9]{64}$') { Fail "invalid template SHA-256 '$($template.source)'" }
    foreach ($token in @($template.tokens)) { if ($token -notin $allowedTokens) { Fail "unknown render token '$token'" } }
}

Write-Output "asset bundle $($bundle.bundleId) validated with digest $computedDigest"
