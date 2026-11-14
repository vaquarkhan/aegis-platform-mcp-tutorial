$schema = @{ type='struct'; 'schema-id'=0; fields=@(
    @{id=1; name='week';    required=$true; type='date'},
    @{id=2; name='country'; required=$true; type='string'},
    @{id=3; name='orders';  required=$true; type='long'},
    @{id=4; name='revenue'; required=$true; type='decimal(16,2)'}
) } | ConvertTo-Json -Depth 6 -Compress

Invoke-RestMethod -Method Post -ContentType 'application/json'   -Uri 'http://127.0.0.1:18181/v1/namespaces/gold/tables'   -Body "{""name"":""weekly_revenue"",""schema"":$schema}"
