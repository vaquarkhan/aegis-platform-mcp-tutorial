$envMap = @{
    AEGIS_SIGNING_KEY     = 'end-to-end-tutorial-signing-key-0123456789abcdef'
    AEGIS_E2E_READER      = $tokens.reader
    AEGIS_E2E_OPERATOR    = $tokens.operator
    AEGIS_E2E_APPROVER    = $tokens.approver
    AEGIS_E2E_OUTSIDER    = $tokens.outsider
    ICEBERG_CATALOG_TOKEN = 'end-to-end-tutorial-catalog-credential'
}
