param([Parameter(Mandatory)][string]$PrivateKeyPath)
. "$PSScriptRoot/tools.ps1"
$keyPath = [IO.Path]::GetFullPath($PrivateKeyPath)
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ($keyPath.StartsWith($project + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Keep the production private key outside the repository'
}
if (Test-Path -LiteralPath $keyPath) { throw 'Refusing to overwrite an existing key' }
$sdk = Get-ReleaseTools
& "$sdk/bin/winsparkle-tool.exe" generate-key --file $keyPath
if ($LASTEXITCODE -ne 0) { throw 'Key generation failed' }
# The tool prints ONLY the public key. Never print the private key here.
Write-Host 'Save the private key in a protected backup. Set its contents as UPDATE_PRIVATE_KEY in GitHub Actions Secrets.'
Write-Host 'Set the public key above as UPDATE_PUBLIC_KEY in GitHub Actions Variables.'
