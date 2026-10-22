Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReleaseTools {
    param([string]$Cache = (Join-Path $PSScriptRoot '../../tmp/operations/tools'))
    $Cache = [IO.Path]::GetFullPath($Cache)
    New-Item -ItemType Directory -Force $Cache | Out-Null
    $sdk = Join-Path $Cache 'WinSparkle-0.9.2'
    if (!(Test-Path "$sdk/bin/winsparkle-tool.exe")) {
        $archive = Join-Path $Cache 'winsparkle.zip'
        Invoke-WebRequest 'https://github.com/vslavik/winsparkle/releases/download/v0.9.2/WinSparkle-0.9.2.zip' -OutFile $archive
        if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne '2a5facf5a22056edf7afc4d0a4bf05620b7aa7cc1619c3078b281e374cdb9996') {
            throw 'WinSparkle checksum mismatch'
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $Cache -Force
    }
    return $sdk
}

function Get-InnoCompiler {
    param([string]$Cache = (Join-Path $PSScriptRoot '../../tmp/operations/tools'))
    $Cache = [IO.Path]::GetFullPath($Cache)
    $compiler = Join-Path $Cache 'inno/ISCC.exe'
    if (!(Test-Path $compiler)) {
        New-Item -ItemType Directory -Force $Cache | Out-Null
        $setup = Join-Path $Cache 'innosetup-6.7.3.exe'
        Invoke-WebRequest 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe' -OutFile $setup
        if ((Get-FileHash $setup -Algorithm SHA256).Hash -ne '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732') {
            throw 'Inno Setup checksum mismatch'
        }
        $process = Start-Process -FilePath $setup -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', "/DIR=`"$Cache/inno`"") -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Inno Setup installation failed: $($process.ExitCode)" }
    }
    return $compiler
}
