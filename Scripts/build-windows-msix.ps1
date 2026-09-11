# Package an already validated NSIS payload for Microsoft Store submission.
# This does not sign the package or publish it. Identity comes from Partner Center.
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$IdentityName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Publisher,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PublisherDisplayName,
    [Parameter(Mandatory)][ValidatePattern('^[1-9][0-9]*\.[0-9]+\.[0-9]+\.0$')][string]$Version,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WebView2Runtime,
    [string]$Installer,
    [string]$Output
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$Installer) {
    $installers = @(Get-ChildItem "$root/Desktop/src-tauri/target/release/bundle/nsis/*-setup.exe")
    if ($installers.Count -ne 1) { throw 'Build one validated Windows NSIS installer first.' }
    $Installer = $installers[0].FullName
}
if (!$Output) { $Output = "$root/dist/Dictate-Windows-x64-Store.msix" }
if (!(Test-Path "$WebView2Runtime/msedgewebview2.exe")) { throw 'Supply the extracted official x64 Fixed Version WebView2 runtime.' }
$signature = Get-AuthenticodeSignature "$WebView2Runtime/msedgewebview2.exe"
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { throw 'WebView2 must have a valid Microsoft signature.' }
$makeappx = Get-ChildItem "${env:ProgramFiles(x86)}/Windows Kits/10/bin/*/x64/makeappx.exe" | Sort-Object FullName -Descending | Select-Object -First 1
if (!$makeappx) { throw 'Install the free Windows SDK with MakeAppx.' }
$stage = Join-Path ([IO.Path]::GetTempPath()) ('dictate-store-' + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Force "$stage/extracted", "$stage/package/Assets" | Out-Null
    & 7z x -y "-o$stage/extracted" $Installer | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not extract the validated installer.' }
    $apps = @(Get-ChildItem "$stage/extracted" -Recurse -Filter dictate-desktop.exe)
    if ($apps.Count -ne 1) { throw 'Expected one Dictate executable.' }
    $payload = $apps[0].Directory.FullName
    foreach ($name in @('dictate-desktop.exe','onnxruntime.dll','msvcp140.dll','vcruntime140.dll','LICENSE','THIRD_PARTY_LICENSES.txt','ONNX-LICENSE')) {
        if (!(Test-Path "$payload/$name")) { throw "Missing payload dependency: $name" }
    }
    Get-ChildItem $payload | Where-Object { $_.Name -notmatch '(?i)uninstall|^\$' } | Copy-Item -Destination "$stage/package" -Recurse -Force
    Copy-Item $WebView2Runtime "$stage/package/webview2" -Recurse
    foreach ($name in @('Square44x44Logo.png','Square150x150Logo.png','StoreLogo.png')) {
        Copy-Item "$root/Desktop/src-tauri/icons/$name" "$stage/package/Assets/$name"
    }
    [xml]$manifest = Get-Content "$root/Release/windows-store/AppxManifest.xml.template"
    $manifest.Package.Identity.Name = $IdentityName
    $manifest.Package.Identity.Publisher = $Publisher
    $manifest.Package.Identity.Version = $Version
    $manifest.Package.Properties.PublisherDisplayName = $PublisherDisplayName
    $manifest.Save("$stage/package/AppxManifest.xml")
    New-Item -ItemType Directory -Force (Split-Path $Output -Parent) | Out-Null
    & $makeappx.FullName pack /d "$stage/package" /p $Output /o
    if ($LASTEXITCODE -ne 0) { throw 'MakeAppx rejected the package.' }
    (Get-FileHash $Output -Algorithm SHA256).Hash.ToLower() | Set-Content "$Output.sha256"
    Write-Host "Prepared unsigned Store submission: $Output"
    Write-Host 'Run Windows App Certification Kit and packaged-app acceptance tests, then submit in Partner Center. Microsoft signs only after certification.'
} finally {
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
}
