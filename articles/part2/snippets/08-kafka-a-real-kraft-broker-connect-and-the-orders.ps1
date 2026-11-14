# Leave Start-All running so Connect is listening on 18083. Create the file first.
# The connector fails at once if this path does not exist.
New-Item -ItemType Directory -Force -Path C:\data | Out-Null
Set-Content -Path C:\data\orders.txt -Value "order-1`norder-2" -Encoding ascii
$source = 'C:/data/orders.txt'
$body = @{ name = 'orders-file-source-2'; config = @{
    'connector.class' = 'org.apache.kafka.connect.file.FileStreamSourceConnector'
    'tasks.max' = '1'; file = $source; topic = 'orders' } } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18083/connectors' -ContentType 'application/json' -Body $body
