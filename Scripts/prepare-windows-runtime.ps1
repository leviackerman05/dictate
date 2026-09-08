# Stage app-local ONNX and VC++ DLLs. Uses existing free MSVC build tools;
# never installs software, changes machine policy, or calls a paid service.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dest = Join-Path $root 'Desktop/src-tauri/runtime'
New-Item -ItemType Directory -Force $dest | Out-Null
$version = '1.28.0'
$expected = 'abef733dacbe2f571547a7150b479b5cb9cc0df22f96c24983a42cadb1b4f8bc'
$archive = Join-Path ([IO.Path]::GetTempPath()) "dictate-onnxruntime-win-x64-$version.zip"
if (!(Test-Path $archive) -or (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower() -ne $expected) {
    Invoke-WebRequest "https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-$version.zip" -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw 'ONNX Runtime checksum failed' }
$extract = Join-Path ([IO.Path]::GetTempPath()) "dictate-onnxruntime-$version"
Expand-Archive $archive $extract -Force
$package = Join-Path $extract "onnxruntime-win-x64-$version"
Get-ChildItem (Join-Path $package 'lib/*.dll') | Copy-Item -Destination $dest -Force
foreach ($name in @('LICENSE','ThirdPartyNotices.txt')) {
    if (Test-Path (Join-Path $package $name)) { Copy-Item (Join-Path $package $name) (Join-Path $dest "ONNX-$name") -Force }
}
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (!(Test-Path $vswhere)) { throw 'Install the free Visual Studio Build Tools C++ workload before building Dictate.' }
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'The MSVC C++ workload is missing.' }
$redist = Get-ChildItem (Join-Path $vs 'VC/Redist/MSVC') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path (Join-Path $_.FullName 'x64/Microsoft.VC143.CRT')} | Select-Object -First 1
if (!$redist) { throw 'MSVC redistributable files were not found in the installed Build Tools.' }
Get-ChildItem (Join-Path $redist.FullName 'x64/Microsoft.VC143.CRT/*.dll') | Copy-Item -Destination $dest -Force
if (!(Test-Path (Join-Path $dest 'onnxruntime.dll')) -or !(Test-Path (Join-Path $dest 'msvcp140.dll'))) { throw 'Incomplete app-local runtime' }
Write-Host 'Verified ONNX Runtime and staged app-local Microsoft runtime DLLs. No end-user C++ installation is required.'
