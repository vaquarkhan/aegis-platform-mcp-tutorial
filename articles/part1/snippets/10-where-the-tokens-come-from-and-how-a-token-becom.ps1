function New-E2eToken { -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }) }
$tokens = @{
    reader   = New-E2eToken
    operator = New-E2eToken
    approver = New-E2eToken
    outsider = New-E2eToken
}
$tokens | ConvertTo-Json | Set-Content (Join-Path $Run 'keys\tokens.json') -Encoding ascii
