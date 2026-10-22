param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$BuildNumber,
    [string]$SourceDir = 'build/windows/x64/runner/Release',
    [string]$OutputDir = 'build/windows/release'
)
. "$PSScriptRoot/tools.ps1"
$source = (Resolve-Path -LiteralPath $SourceDir).Path
$output = [IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force $output | Out-Null
$exe = Get-Item "$source/mountain_fairytale.exe"
$numericVersion = "$($exe.VersionInfo.FileMajorPart).$($exe.VersionInfo.FileMinorPart).$($exe.VersionInfo.FileBuildPart).$($exe.VersionInfo.FilePrivatePart)"
if ($numericVersion -ne "$Version.$BuildNumber") {
    throw "Executable version mismatch: $($exe.VersionInfo.FileVersion)"
}
# Bundle the redistributable CRT from the installed Visual Studio toolchain.
# App-local deployment keeps ordinary installs and updates free of UAC prompts.
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'Visual C++ toolchain not found' }
$crt = Get-ChildItem "$vs/VC/Redist/MSVC/*/x64/Microsoft.VC14*.CRT" -Directory |
    Sort-Object FullName -Descending | Select-Object -First 1
if (!$crt) { throw 'Visual C++ redistributable CRT not found' }
Copy-Item "$($crt.FullName)/*.dll" $source -Force
$compiler = Get-InnoCompiler
& $compiler "/DAppVersion=$Version" "/DBuildNumber=$BuildNumber" "/DSourceDir=$source" "/DOutputDir=$output" "$PSScriptRoot/../../windows/installer/app.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
