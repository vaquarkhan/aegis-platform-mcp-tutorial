# Optional. Skip while Start-All is running: it already owns port 18181.
# Forward slashes are required. A URI that still contains backslashes is rejected by SQLite.
$work = (Join-Path $env:TEMP 'aegis-iceberg') -replace '\\', '/'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$env:CATALOG_REST_PORT     = '18181'
$env:CATALOG_WAREHOUSE     = "$work/warehouse"
$env:CATALOG_IO__IMPL      = 'org.apache.iceberg.inmemory.InMemoryFileIO'
$env:CATALOG_CATALOG__IMPL = 'org.apache.iceberg.jdbc.JdbcCatalog'
$env:CATALOG_URI           = "jdbc:sqlite:file:$work/catalog.db"
$env:CATALOG_JDBC_USER     = 'aegis'
$env:CATALOG_JDBC_PASSWORD = 'aegis'
$icebergArgs = (Get-ChildItem .\run\engine-iceberg\engine-*\iceberg.args | Select-Object -Last 1).FullName
java "@$icebergArgs" org.apache.iceberg.rest.RESTCatalogServer
