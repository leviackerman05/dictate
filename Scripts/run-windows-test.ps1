# Cargo target runner: exercise the same app-local runtime layout as the installer.
param([Parameter(Position=0,Mandatory=$true)][string]$Executable, [Parameter(ValueFromRemainingArguments=$true)][string[]]$TestArguments)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Get-ChildItem (Join-Path $root 'Desktop/src-tauri/runtime/*.dll') | Copy-Item -Destination (Split-Path $Executable -Parent) -Force
& $Executable @TestArguments
exit $LASTEXITCODE
