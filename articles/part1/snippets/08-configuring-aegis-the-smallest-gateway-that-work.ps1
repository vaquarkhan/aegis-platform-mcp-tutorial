curl.exe http://127.0.0.1:18079/healthz

$body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}'
Set-Content -Path list.json -Value $body -Encoding ascii
curl.exe -sS -X POST http://127.0.0.1:18079/mcp   -H "Authorization: Bearer a-demo-token-value"   -H "Accept: application/json, text/event-stream"   -H "MCP-Protocol-Version: 2026-07-28"   -H "Mcp-Method: tools/list"   -H "Content-Type: application/json" --data-binary "@list.json"
