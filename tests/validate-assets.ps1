[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root
)

$ErrorActionPreference = 'Stop'

function Assert-Contains {
    param([string]$Actual, [string]$Expected)
    if (-not $Actual.Contains($Expected, [StringComparison]::OrdinalIgnoreCase)) {
        throw "expected error containing '$Expected', got '$Actual'"
    }
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("fabric-assets-contract-" + [Guid]::NewGuid())
try {
    New-Item -ItemType Directory -Path (Join-Path $scratch 'bundles') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratch 'catalog') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'catalog/curated-allow-list.json') -Destination (Join-Path $scratch 'catalog/curated-allow-list.json')
    $manifest = @'
{
  "contractVersion": "fabric-assets/v1",
  "bundleId": "test-bundle",
  "bundleVersion": "1.0.0",
  "supportedFabric": ">=0.1.0 <0.2.0",
  "manifestDigest": "0000000000000000000000000000000000000000000000000000000000000000",
  "dependencies": [{"id":"spring-web","version":"latest"}],
  "templates": []
}
'@
    $manifest | Set-Content -LiteralPath (Join-Path $scratch 'bundles/fabric-assets-v1.json') -NoNewline

    $manifestPath = Join-Path $scratch 'bundles/fabric-assets-v1.json'
    $digest = & (Join-Path $Root 'tools/normalize-and-validate.ps1') -Root $scratch -PrintDigest
    $manifest = Get-Content -LiteralPath $manifestPath -Raw
    $manifest.Replace(('0' * 64), $digest) | Set-Content -LiteralPath $manifestPath -NoNewline

    $validatorFailed = $false
    try {
        $output = & (Join-Path $Root 'tools/normalize-and-validate.ps1') -Root $scratch 2>&1
    }
    catch {
        $validatorFailed = $true
        $output = $_.Exception.Message
    }
    if (-not $validatorFailed) {
        throw 'validator accepted dynamic dependency version'
    }
    Assert-Contains -Actual ($output -join "`n") -Expected 'dynamic version'
    Write-Output 'contract rejection test completed'
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
