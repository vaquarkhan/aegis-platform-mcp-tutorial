# Part 1 code blocks, in article order

Every fenced block in `DZONE-ARTICLE-PART1.md`, one file each, numbered as it appears. Files ending in `.txt` are captured output, not commands to run.

| File | Section | Language | First line |
| --- | --- | --- | --- |
| `01-the-problem-space.json` | The problem space | `json` | `{ "method": "tools/call",` |
| `02-prerequisites-and-the-one-build-command.ps1` | Prerequisites and the one build command | `powershell` | `git clone -b aegis-mcp-gateway-2.0-review-ready https://gith` |
| `03-prerequisites-and-the-one-build-command.ps1` | Prerequisites and the one build command | `powershell` | `git clone https://github.com/vaquarkhan/aegis-platform-mcp-t` |
| `04-prerequisites-and-the-one-build-command.ps1` | Prerequisites and the one build command | `powershell` | `"AEGIS_HOME=$env:AEGIS_HOME"` |
| `05-prerequisites-and-the-one-build-command.ps1` | Prerequisites and the one build command | `powershell` | `$env:AEGIS_HOME = 'PASTE_THE_AEGIS_HOME_LINE'` |
| `06-configuring-aegis-the-smallest-gateway-that-work.yaml` | Configuring Aegis: the smallest gateway that works | `yaml` | `gateway:` |
| `07-configuring-aegis-the-smallest-gateway-that-work.ps1` | Configuring Aegis: the smallest gateway that works | `powershell` | `if (-not $env:AEGIS_HOME) { throw 'Set AEGIS_HOME to your ae` |
| `08-configuring-aegis-the-smallest-gateway-that-work.ps1` | Configuring Aegis: the smallest gateway that works | `powershell` | `curl.exe http://127.0.0.1:18079/healthz` |
| `09-configuring-aegis-the-smallest-gateway-that-work.json` | Configuring Aegis: the smallest gateway that works | `json` | `{"result":{"tools":[{"name":"demo_status","description":"Rea` |
| `10-where-the-tokens-come-from-and-how-a-token-becom.ps1` | Where the tokens come from, and how a token becomes a person | `powershell` | `function New-E2eToken { -join ((1..32) / ForEach-Object { '{` |
| `11-where-the-tokens-come-from-and-how-a-token-becom.yaml` | Where the tokens come from, and how a token becomes a person | `yaml` | `host:` |
| `12-where-the-tokens-come-from-and-how-a-token-becom.ps1` | Where the tokens come from, and how a token becomes a person | `powershell` | `$envMap = @{` |
| `13-connect-your-ide-to-the-gateway.ps1` | Connect your IDE to the gateway | `powershell` | `Get-Content .\run\keys\tokens.json` |
| `14-connect-your-ide-to-the-gateway.json` | Connect your IDE to the gateway | `json` | `{` |
| `15-connect-your-ide-to-the-gateway.json` | Connect your IDE to the gateway | `json` | `{` |
| `16-connect-your-ide-to-the-gateway.json` | Connect your IDE to the gateway | `json` | `{` |
| `17-connect-your-ide-to-the-gateway.json` | Connect your IDE to the gateway | `json` | `{` |
| `18-connect-your-ide-to-the-gateway.json` | Connect your IDE to the gateway | `json` | `{` |
| `19-your-first-governed-commands.ps1` | Your first governed commands | `powershell` | `param(` |
| `20-your-first-governed-commands.ps1` | Your first governed commands | `powershell` | `.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Argumen` |
| `21-your-first-governed-commands.json` | Your first governed commands | `json` | `{"result":{"structuredContent":{"value":[` |
| `22-your-first-governed-commands.ps1` | Your first governed commands | `powershell` | `.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Argumen` |
| `23-your-first-governed-commands.json` | Your first governed commands | `json` | `{"result":{"content":[{"text":` |
| `24-your-first-governed-commands.ps1` | Your first governed commands | `powershell` | `.\mcp.ps1 -Persona outsider -Tool flink_get_cluster_info` |
| `25-your-first-governed-commands.json` | Your first governed commands | `json` | `{"result":{"content":[{"text":` |
| `26-evidence-how-aegis-defends-a-destructive-action.txt` | Evidence: how Aegis defends a destructive action | `text` | `without approval    DENIED:APPROVAL_REQUIRED:step4   Flink R` |
