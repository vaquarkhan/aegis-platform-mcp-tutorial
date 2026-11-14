# MCP client templates

These are safe templates. They contain placeholders or environment-variable references, not live tokens. `Start-All.ps1` writes the reader token to `run/keys/tokens.json`.

| Client | Template | Copy to | Verified scope |
| --- | --- | --- | --- |
| Cursor | `cursor/mcp.json` | `.cursor/mcp.json` | HTTP config shape; use the Part 1 prompts |
| Kiro | `kiro/mcp.json` | `.kiro/settings/mcp.json` | Connected and called real tools in this tutorial |
| VS Code with GitHub Copilot | `vscode/mcp.json` | `.vscode/mcp.json` | Uses a secret `promptString` input |
| Claude Desktop | `claude-desktop/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` | Stdio gateway verified: 14 tools, gold allowed, bronze denied |
| Gemini CLI | `gemini/settings.json` | `.gemini/settings.json` | Official Streamable HTTP shape; not run in the recorded tutorial |

Keep client confirmation enabled (`autoApprove: []` in Kiro, `trust: false` in Gemini). Client confirmation is useful but it is not the policy boundary. Aegis still classifies, scopes, evaluates deny rules, requires approval, pins egress, forwards, and audits every call.

Never commit a copied project file after replacing a token. The repository `.gitignore` excludes `.cursor/mcp.json`, `.kiro/settings/mcp.json`, `.vscode/mcp.json`, and `.gemini/settings.json`.
