# Shared, fail-closed helpers for the public Part 3 CLI scripts.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Initialize-Part3Runtime([string]$RuntimeDirectory) {
    New-Item -ItemType Directory -Force -Path $RuntimeDirectory | Out-Null
    # Restrict the generated passwords, tokens, ids, and SSM payloads to the current Windows user.
    $grant = '{0}:(OI)(CI)F' -f $env:USERNAME
    & icacls.exe $RuntimeDirectory /inheritance:r /grant:r $grant | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "could not restrict ACL on $RuntimeDirectory" }
    return (Resolve-Path $RuntimeDirectory).Path
}

function Invoke-Aws([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & aws @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) { throw "aws $($Arguments -join ' ') failed ($code): $($output -join ' ')" }
    return @($output)
}

function Read-Part3State([string]$RuntimeDirectory) {
    $path = Join-Path $RuntimeDirectory 'state.json'
    if (-not (Test-Path $path)) { throw "missing $path; run 01-upload-and-iam.ps1 first" }
    return (Get-Content -Raw $path | ConvertFrom-Json)
}

function Write-Part3State([string]$RuntimeDirectory, $State) {
    $path = Join-Path $RuntimeDirectory 'state.json'
    [IO.File]::WriteAllText($path, ($State | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
}

function Assert-Value([string]$Name, [string]$Value, [string]$Pattern) {
    if (-not $Value -or $Value -notmatch $Pattern) { throw "invalid ${Name}: '$Value'" }
}
