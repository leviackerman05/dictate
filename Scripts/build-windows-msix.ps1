# Package an already validated NSIS payload for Microsoft Store submission.
# This does not sign the package or publish it. Defaults match the reserved Partner Center product.
param(
    [ValidateNotNullOrEmpty()][string]$IdentityName = 'PriyanshSingh.Dictate-PrivateVoiceTyping',
    [ValidateNotNullOrEmpty()][string]$Publisher = 'CN=41A9F374-D1EA-4092-B9C8-24D61C5BE98A',
    [ValidateNotNullOrEmpty()][string]$PublisherDisplayName = 'Priyansh Singh',
    [ValidateNotNullOrEmpty()][string]$ProductDisplayName = 'Dictate - Private Voice Typing',
    [ValidatePattern('^[1-9][0-9]*\.[0-9]+\.[0-9]+\.0$')][string]$Version = '1.1.8.0',
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
$sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
if (!$sevenZip) { throw 'Install 7-Zip and make sure the 7z command is available in PATH.' }
$makeappx = Get-ChildItem "${env:ProgramFiles(x86)}/Windows Kits/10/bin/*/x64/makeappx.exe" | Sort-Object FullName -Descending | Select-Object -First 1
if (!$makeappx) { throw 'Install the free Windows SDK with MakeAppx.' }
$stage = Join-Path ([IO.Path]::GetTempPath()) ('dictate-store-' + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Force "$stage/extracted", "$stage/package/Assets" | Out-Null
    & $sevenZip.Source x -y "-o$stage/extracted" $Installer | Out-Null
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
    $namespaces = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
    $namespaces.AddNamespace('f', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
    $namespaces.AddNamespace('uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
    $identity = $manifest.SelectSingleNode('/f:Package/f:Identity', $namespaces)
    $properties = $manifest.SelectSingleNode('/f:Package/f:Properties', $namespaces)
    $visualElements = $manifest.SelectSingleNode('/f:Package/f:Applications/f:Application/uap:VisualElements', $namespaces)
    if (!$identity -or !$properties -or !$visualElements) { throw 'The Store manifest template is missing required elements.' }
    $identity.SetAttribute('Name', $IdentityName)
    $identity.SetAttribute('Publisher', $Publisher)
    $identity.SetAttribute('Version', $Version)
    $properties.DisplayName = $ProductDisplayName
    $properties.PublisherDisplayName = $PublisherDisplayName
    $visualElements.SetAttribute('DisplayName', $ProductDisplayName)
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
