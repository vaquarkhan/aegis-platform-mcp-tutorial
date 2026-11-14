<!--
  Copyright 2026 Viquar Khan and the Aegis MCP Gateway contributors

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
# Aegis platform MCP tutorial

One Aegis MCP gateway in front of real Apache Kafka, Flink, Iceberg, and Spark. The repository has one runnable local tutorial at the root and a three-part article series under [`articles/`](articles/README.md). Part 3 repeats the same controls on AWS with an SSM-only EC2 instance, Cognito JWT identity, and audit evidence copied to S3.

Aegis is an independent project (`io.github.vaquarkhan`). It is not an Apache Software Foundation or Amazon Web Services project.

## What this repository proves

The engines keep their normal APIs. The agent talks only to Aegis. For every `tools/call`, Aegis authenticates the caller, classifies the tool as `READ`, `MUTATE`, or `DESTRUCTIVE`, checks resource scope, applies deny-overrides policy, requires a preview and an independent approval for destructive actions, checks egress, forwards the fixed backend request only after every gate passes, and appends the decision to a hash-chained journal.

The completed local and AWS runs produced the same results:

| Call | Result |
| --- | --- |
| reader lists `gold` | `ALLOWED`: `customer_ltv`, `daily_revenue`, `product_performance` |
| reader lists `bronze` | `SCOPE_DENIED` |
| known outsider token with no groups reads Flink | `POLICY_DENIED` |
| unknown bearer | HTTP 401 before policy |
| operator drops `restricted.finance_pnl` | `POLICY_DENIED`, rule `never-drop-restricted`; no approval can override it |
| operator cancels Flink without approval | `APPROVAL_REQUIRED`; job remains `RUNNING` |
| operator or reader tries to approve | HTTP 403 |
| bob approves, eve presents receipt plus token | `ALLOWED`; Flink becomes `CANCELED`, one task |
| eve replays the same approval | refused: approval token already used |
| original audit journal | `OK` |
| one changed word in a copy | `BROKEN` at the edited record |

## Read the series

Each article folder is self-contained. It carries its Markdown, SVG diagrams and PNG renders, runnable code, and a numbered `snippets/` mirror of every fenced code block.

| Part | Start here | What it covers | Code and images |
| --- | --- | --- | --- |
| 1 | [`articles/part1/DZONE-ARTICLE-PART1.md`](articles/part1/DZONE-ARTICLE-PART1.md) | incident, MCP risk, local build, dataset, tokens, Cursor, Kiro, VS Code Copilot, Claude Desktop, Gemini CLI, first allow and deny calls | [`articles/part1/code`](articles/part1/code), `architecture`, `build`, and `pipeline` diagrams |
| 2 | [`articles/part2/DZONE-ARTICLE-PART2.md`](articles/part2/DZONE-ARTICLE-PART2.md) | how each engine starts, the full `aegis.yaml`, hard deny, dry run, separate approval, single-use enforcement, audit verification | [`articles/part2/code`](articles/part2/code), `protection` diagram |
| 3 | [`articles/part3/DZONE-ARTICLE-PART3.md`](articles/part3/DZONE-ARTICLE-PART3.md) | AWS inventory, engine processes and data paths, Cognito JWTs, S3 evidence, modular Terraform, teardown | [`articles/part3/code`](articles/part3/code), `aws-architecture` diagram |

[`articles/README.md`](articles/README.md) describes the publication layout. Run `python articles/tools/extract_snippets.py` after changing article fences.

## Local quick start

### Prerequisites

- Windows with PowerShell 5.1 or newer
- JDK 17 or newer
- Maven 3.9 or newer
- Git and `curl.exe`
- roughly 2 GB for first-time dependency downloads

The gateway's default branch is not the 2.0 line used by this tutorial. Clone the review-ready branch by name:

```powershell
git clone -b aegis-mcp-gateway-2.0-review-ready https://github.com/vaquarkhan/aegis-mcp-gateway.git
cd aegis-mcp-gateway
if (-not (Test-Path .\examples\break-glass-mcp-servers\lib\BreakGlassMcp.psm1)) {
    throw 'Wrong gateway branch. This tutorial needs aegis-mcp-gateway-2.0-review-ready.'
}
mvn -B -Preal-engines -DskipTests install
$env:AEGIS_HOME = (Get-Location).Path
```

Clone this repository in the same parent folder, then start it:

```powershell
cd ..
git clone https://github.com/vaquarkhan/aegis-platform-mcp-tutorial.git
cd aegis-platform-mcp-tutorial
.\Start-All.ps1
```

Wait for:

```text
Aegis platform MCP is up (Flink + Iceberg + Spark + Kafka)
```

Leave that shell open. In every new PowerShell window, restore the two things PowerShell does not carry over:

```powershell
$env:AEGIS_HOME = 'C:\path\to\aegis-mcp-gateway'
Set-Location 'C:\path\to\aegis-platform-mcp-tutorial'
```

### First proof

```powershell
.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Arguments @{ namespace = 'gold' }
.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Arguments @{ namespace = 'bronze' }
.\mcp.ps1 -Persona outsider -Tool flink_get_cluster_info
.\mcp.ps1 -Persona operator -Tool iceberg_drop_table -Arguments @{ namespace = 'restricted'; table = 'finance_pnl' }
```

Expected: gold is allowed; bronze is `SCOPE_DENIED`; outsider is `POLICY_DENIED`; the finance drop is `POLICY_DENIED` by `never-drop-restricted`.

### Destructive-action proof

```powershell
.\Approve-Cancel.ps1
```

This is a real cancel against the running Flink 1.20.1 MiniCluster. The script performs the whole control sequence:

1. eve dry-runs `flink_cancel_job`; Aegis returns the exact live-job preview, a signed receipt, and a pending approval id. Flink remains `RUNNING`.
2. eve tries to approve and gets HTTP 403.
3. bob approves and the record says `decidedBy=bob`.
4. eve collects the single-use approval token.
5. eve re-calls with both artifacts; Aegis forwards the fixed Flink cancel request and the job becomes `CANCELED`.
6. replaying the same approval is refused.

The metadata keys are `io.github.vaquarkhan.aegis/dryRun`, `/dryRunReceipt`, `/approvalToken`, and `/decision`. The complete requests are in [`Approve-Cancel.ps1`](Approve-Cancel.ps1) and Part 2.

### Full walkthrough and audit

```powershell
.\Run-Walkthrough.ps1
java -jar "$env:AEGIS_HOME\examples\aegis-gateway-kafka\target\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar" --verify-audit .\run\audit\aegis-platform.jsonl
```

`Run-Walkthrough.ps1` creates `run/WALKTHROUGH.md`. The record count and head hash differ each run; success begins with `OK`.

Stop every process when finished:

```powershell
.\Stop-All.ps1
```

## What runs and where data lives

| Piece | Local endpoint or path | What is real |
| --- | --- | --- |
| Aegis | `http://127.0.0.1:18080/mcp` | one Java gateway, full policy, approvals, egress, audit |
| Kafka 3.9.1 | broker `19092`, controller `19093`, Connect `18083` | one KRaft node, topic `orders`, connector `orders-file-source`; log segments under `run/engine-kafka/engine-<timestamp>/kraft-logs` |
| Flink 1.20.1 | JobManager REST `18081` | one MiniCluster, one TaskManager, two slots, one endless streaming job at parallelism 1 |
| Iceberg 1.10.1 | REST catalog `18181` | `JdbcCatalog` over `catalog.db`; `InMemoryFileIO`, so table schemas are real but there are no Parquet files |
| Spark 4.0.1 | app UI `14040`, Master REST `16066`, RPC `17077` | `local[1]` application and one submitted standalone driver |
| Identity | `run/keys/tokens.json` | four fresh demo tokens generated on every start |
| Audit | `run/audit/aegis-platform.jsonl` | append-only hash-chained decisions for this run |

The only business records are `order-1` and `order-2`, read from `orders.txt` by Kafka Connect into topic `orders`. The eleven Iceberg tables are empty schemas arranged as bronze, silver, gold, and restricted. The Flink and Spark jobs create real operational state for Aegis to govern; they do not populate the Iceberg tables.

## IDE and agent clients

Safe templates are under [`articles/part1/code/ide`](articles/part1/code/ide):

- Cursor: `cursor/mcp.json` to `.cursor/mcp.json`
- Kiro: `kiro/mcp.json` to `.kiro/settings/mcp.json`
- VS Code with GitHub Copilot: `vscode/mcp.json` to `.vscode/mcp.json`
- Claude Desktop: `claude-desktop/claude_desktop_config.json` to its desktop config
- Gemini CLI: `gemini/settings.json` to `.gemini/settings.json`

Use the reader token first. Keep client auto-approval off. Client confirmation is useful, but Aegis remains the enforcement boundary even if a client is compromised or configured to auto-run tools. Never commit a copied config after inserting a token.

## Root files

The root is intentionally small and runnable:

| File | Purpose |
| --- | --- |
| `README.md` | this entry point |
| `.gitignore` | excludes tokens, engine state, logs, Terraform state, and copied client configs |
| `aegis.yaml` | the gateway, tools, policies, scopes, egress, identity, approval, and audit configuration |
| `Start-All.ps1` | starts the four engines, gateway, and medallion schemas |
| `Stop-All.ps1` | stops processes recorded by this run and removes `run/state.json` |
| `Seed-Medallion.ps1` | creates the eleven Iceberg table schemas |
| `mcp.ps1` | one MCP `tools/list` or `tools/call` request |
| `Run-Walkthrough.ps1` | runs the allow, scope-deny, policy-deny, and dry-run checks |
| `Approve-Cancel.ps1` | executes the independent, single-use approval proof |

Everything else meant for publication belongs under `articles/`.

## AWS Part 3

Part 3 ran the same stack on a Windows EC2 `t3.xlarge` with a security group containing zero inbound rules. Systems Manager carried commands. Cognito ID tokens supplied actors and `cognito:groups`. A second gateway verified RS256 signatures and the issuer and audience, then applied the same rules. The two audit journals were copied to S3, downloaded, and verified from the laptop; changing one word broke the chain.

Public code is under `articles/part3/code`:

- `cli/`: local provisioning, SSM, Cognito, evidence verification, teardown
- `remote/`: scripts sent to the instance
- `terraform/`: root composition and modules for network, IAM, compute, Cognito

The article and public code use placeholders instead of the account, VPC, subnet, security group, instance, AMI, pool, client, bucket, profile, and local paths from the recorded run.

## Security boundaries and limits

- This tutorial is a local or disposable cloud demonstration, not a production deployment.
- Static tokens and the fixed signing/catalog secrets in the local scripts are demo values. Part 3 replaces caller identity with Cognito JWTs. Production secrets belong in a secret manager or mounted secret files.
- The backend credentials stay with the gateway. The IDE bearer token is not passed through to Flink, Iceberg, Spark, or Kafka.
- Aegis governs MCP actions. It does not scan prose, decide whether a prompt is wise, replace AWS IAM, or make an engine invulnerable.
- `state.type: memory` is one-process state. More than one gateway replica needs shared PostgreSQL state.
- The Part 3 evidence upload proves file transport and hash-chain integrity. A production evidence store should also use versioning or Object Lock and an identity separate from the instance writer.

## Repository hygiene

Generated state stays out of Git:

- `run/`, `*.log`
- copied IDE configs containing live tokens
- `.terraform/`, `*.tfstate*`, real `passwords.auto.tfvars`
- Part 3 runtime ids, temporary Cognito tokens, SSM payloads, source bundles, and downloaded evidence

Before publishing, run the repository security scan and link/fence checks described in `articles/README.md`. Do not commit or push a generated token, password, instance id, audit journal, engine log, or Terraform state.
