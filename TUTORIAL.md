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
# Tutorial: govern a real data platform with one Aegis MCP gateway

You have four Apache engines on a laptop — Flink, Iceberg, Spark and Kafka — and an IDE agent that
wants to operate them through MCP. Without a governance layer, that agent inherits whatever each
engine’s credential can do: cancel jobs, drop tables, pause connectors, kill Spark drivers.

This tutorial puts **one Aegis MCP gateway** between the agent and all four engines. Every
`tools/call` is classified, scoped, approved when needed, audited, and only then forwarded.

The engines are **real** (same launchers as the repository’s FrontDoors tests and
`examples/break-glass-mcp-servers`). The scripts here are what we used to validate Kafka, Flink,
Spark and Iceberg under Aegis with Knox in the adopter suite — adapted so you can run the **combined**
story by hand.

```text
  IDE / mcp.ps1 / agent
           |
           v
   Aegis MCP  http://127.0.0.1:18080/mcp
           |
     +-----+------+--------+--------+
     v     v      v        v
   Flink Iceberg Spark   Kafka
   :18081 :18181 :14040  :19092
                 :16066  :18083 Connect
```

## Contents

1. [What you will prove](#1-what-you-will-prove)
2. [Prerequisites and build](#2-prerequisites-and-build)
3. [Start the platform](#3-start-the-platform)
4. [People, groups and tokens](#4-people-groups-and-tokens)
5. [Connect Cursor (or curl)](#5-connect-cursor-or-curl)
6. [Walkthrough: read across four engines](#6-walkthrough-read-across-four-engines)
7. [Walkthrough: a governed Flink cancel](#7-walkthrough-a-governed-flink-cancel)
8. [What Aegis denies on purpose](#8-what-aegis-denies-on-purpose)
9. [The governance file, section by section](#9-the-governance-file-section-by-section)
10. [Audit and clean up](#10-audit-and-clean-up)
11. [How this relates to the automated tests](#11-how-this-relates-to-the-automated-tests)
12. [Troubleshooting](#12-troubleshooting)

## 1. What you will prove

| Proof | How |
| --- | --- |
| Four real engines are up | `Start-All.ps1` prints engine facts (Flink `jobId`, Spark driver id, Kafka connector, Iceberg tables) |
| One MCP surface | `tools/list` shows Flink, Iceberg, Spark and Kafka tools from a single gateway |
| Readers are limited | `ana` can list `sales` tables; `finance` is scope-denied |
| Outsiders are refused | empty groups → policy deny |
| Destructive needs approval | `flink_cancel_job` returns `APPROVAL_REQUIRED` until dry-run + independent approver |
| Finance never drops | `iceberg_drop_table` on `finance.ledger` is `POLICY_DENIED` even for operators |
| Evidence | hash-chained journal under `run/audit/` |

## 2. Prerequisites and build

- **JDK 17+**, **Maven 3.9+**, Windows PowerShell 5.1+ (scripts are `.ps1`; engines are Java)
- Free ports: `18080` (Aegis), `18081` (Flink), `18181` (Iceberg), `14040` / `16066` / `17077` (Spark),
  `19092` / `19093` / `18083` (Kafka)
- About 2 GB disk for Maven deps on first `-Preal-engines` build

This tutorial is a **standalone GitHub project**. Build Aegis separately, then point here with
`AEGIS_HOME`:

```powershell
cd $env:AEGIS_HOME   # your aegis-mcp-gateway clone
mvn -B -Preal-engines -DskipTests install
```

That produces:

- `examples/aegis-gateway-kafka/target/aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar` (this tutorial uses it)
- Flink / Spark / Kafka / Iceberg classpaths under `examples/aegis-validation*/target/`
- Break-glass engine launchers under `examples/break-glass-mcp-servers/`

## 3. Start the platform

```powershell
$env:AEGIS_HOME = 'C:\path\to\aegis-mcp-gateway'
cd <this-tutorial-repo>
.\Start-All.ps1
```

What the script does, in order:

1. Checks the Maven outputs above (`Assert-BgPrerequisites`).
2. Starts **Flink** MiniCluster on `18081` and leaves a streaming job running.
3. Starts **Iceberg** `RESTCatalogServer` on `18181` and seeds `sales.orders` + `finance.ledger`.
4. Starts **Spark** UI + Master REST and seeds a SUBMITTED driver (no worker — same pattern as the Spark FrontDoors test).
5. Starts **Kafka** KRaft + Connect, seeds topic `orders` and connector `orders-file-source`.
6. Writes demo bearer tokens to `run/keys/tokens.json`.
7. Starts **one** Aegis process with `aegis.yaml` on `http://127.0.0.1:18080/mcp`.

Leave that terminal open (or keep the processes running). In another shell:

```powershell
.\Run-Walkthrough.ps1
```

When finished:

```powershell
.\Stop-All.ps1
```

## 4. People, groups and tokens

| Persona (`mcp.ps1 -Persona`) | Actor in YAML | Groups | Typical use |
| --- | --- | --- | --- |
| `reader` | `ana` | `platform-readers` | browse |
| `operator` | `eve` | `platform-operators` | mutate / destructive (with approval) |
| `approver` | `bob` | `platform-approvers` | approve eve’s requests (cannot approve own) |
| `outsider` | `outsider` | none | must be refused |

Tokens are random per `Start-All` and live only under `run/keys/tokens.json` (gitignored).

## 5. Connect Cursor (or curl)

Copy [ide/cursor/mcp.json](ide/cursor/mcp.json) into your Cursor MCP settings and replace the bearer
with the `reader` value from `run/keys/tokens.json`.

Or call MCP yourself:

```powershell
.\mcp.ps1 -Persona reader -Method tools/list
.\mcp.ps1 -Persona reader -Tool flink_get_cluster_info
.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Arguments @{ namespace = 'sales' }
.\mcp.ps1 -Persona operator -Tool kafka_list_topics
.\mcp.ps1 -Persona operator -Tool spark_list_applications
```

## 6. Walkthrough: read across four engines

`Run-Walkthrough.ps1` already does this and writes `run/WALKTHROUGH.md`. Manually:

1. **tools/list** as reader — you should see tools from all four sources.
2. **flink_get_cluster_info** — real Flink `/overview`.
3. **iceberg_list_tables** `{namespace:sales}` — allowed.
4. **iceberg_list_tables** `{namespace:finance}` — `SCOPE_DENIED` for readers.
5. **kafka_list_topics** — broker admin via the `kafka-admin` plugin.
6. **spark_list_applications** — Spark UI REST.
7. **outsider** + any read — denied.
8. **connect_list_connectors** as operator — Connect REST.

## 7. Walkthrough: a governed Flink cancel

Destructive tools need a **dry-run receipt** and an **independent approval**.

1. Read `flink.jobId` from `run/state.json` (printed by Start-All).
2. As operator, call `flink_cancel_job` **without** dry-run → expect `APPROVAL_REQUIRED` (or dry-run required, depending on control order).
3. Call again with dry-run meta (`io.github.vaquarkhan.aegis/dryRun: true`) → receipt + approval request id.
4. As **approver** (bob), `POST /aegis/v1/approvals/{id}/approve` with bob’s bearer token.
5. As operator, call `flink_cancel_job` with the approval token and dry-run receipt in `_meta`.
6. Confirm on Flink: job is no longer RUNNING (JobManager REST or `flink_list_jobs`).

Exact `_meta` keys:

- `io.github.vaquarkhan.aegis/dryRun`
- `io.github.vaquarkhan.aegis/approvalToken`
- `io.github.vaquarkhan.aegis/dryRunReceipt`

(Same contract as `docs/DEVELOPER.md` and the Flink FrontDoors test.)

## 8. What Aegis denies on purpose

Try these as operator — they should still fail:

```powershell
.\mcp.ps1 -Persona operator -Tool iceberg_drop_table -Arguments @{ namespace = 'finance'; table = 'ledger' }
```

Expect `POLICY_DENIED` (`never-drop-finance`). No approval can lift a DENY rule.

Internal Kafka topics matching `__*` / `_*` are also denied by policy.

## 9. The governance file, section by section

[aegis.yaml](aegis.yaml) is the whole MCP server definition:

| Section | Role in this tutorial |
| --- | --- |
| `access` / `approval` | write vs approver groups; signing key env |
| `policy` | READ for readers+operators; MUTATE/DESTRUCTIVE for operators; DENY finance drop; DENY internal topics |
| `scopes` | readers → Iceberg `sales` only; operators → all typed resources |
| `egress` | loopback only |
| `audit` | `./run/audit/aegis-platform.jsonl` |
| `sources` | `flink`, `iceberg`, `spark-history`, `spark-master`, `kafka-connect`, `kafka-admin` |
| `host` | listen `18080` + four static bearer identities |

No `serverCatalog` / break-glass block here on purpose: this tutorial teaches the **governed tool path**.
For signed catalogs and break-glass containment, use
`$AEGIS_HOME/examples/break-glass-mcp-servers` (four separate MCP servers). For Spark SQL + Iceberg
lake in one IDE story, see `$AEGIS_HOME/docs/TUTORIAL-SPARK-ICEBERG.md`.

## 10. Audit and clean up

```powershell
java -jar "$env:AEGIS_HOME\aegis-gateway\target\aegis-gateway-2.0.0-SNAPSHOT-all.jar" `
  --verify-audit .\run\audit\aegis-platform.jsonl
.\Stop-All.ps1
```

`run/` is gitignored (engines workdirs, logs, tokens, audit).

## 11. How this relates to the automated tests

| Automated check | What this tutorial reuses |
| --- | --- |
| `KafkaFrontDoorsTest` | same KRaft + Connect seed pattern |
| `FlinkFrontDoorsTest` | same MiniCluster + cancel-with-approval story |
| `SparkFrontDoorsTest` | same Master REST + SUBMITTED driver |
| `IcebergFrontDoorsTest` | same RESTCatalogServer + sales/finance seed |
| `examples/break-glass-mcp-servers` | engine Java launchers via `BreakGlassMcp.psm1` |

Difference: tests use **two front doors** (own host + Knox) and stop when Surefire finishes. This tutorial
leaves **one own-host gateway** running so you can explore with an IDE.

To re-run the automated two-door suite (with Knox):

```powershell
$env:AEGIS_KNOX_HOME = 'C:\knox\knox-3.0.0'
& "$env:AEGIS_HOME\examples\adopters\run-example.ps1" -Adopter kafka
& "$env:AEGIS_HOME\examples\adopters\run-example.ps1" -Adopter flink
& "$env:AEGIS_HOME\examples\adopters\run-example.ps1" -Adopter spark
& "$env:AEGIS_HOME\examples\adopters\run-example.ps1" -Adopter iceberg
```

## 12. Troubleshooting

| Symptom | Fix |
| --- | --- |
| `missing build output` | `mvn -B -Preal-engines -DskipTests install` from repo root |
| `port … is in use` | `.\Stop-All.ps1`; stop other break-glass servers; free the port |
| `already started` | delete stale `run/state.json` only after `Stop-All`, or run Stop-All |
| Kafka jar missing | ensure `examples/aegis-gateway-kafka/...-all.jar` exists (kafka-admin needs it) |
| Iceberg 401/empty | `ICEBERG_CATALOG_TOKEN` is set by Start-All; restart stack |
| tools/list empty / 503 | wait for `/healthz` 200; check `run/logs/aegis-platform*.log` |

## Next steps

- Add Knox in front of this same `aegis.yaml` (see Knox sections in adopter tutorials).
- Split engines into separate signed MCP servers with break-glass under
  `$AEGIS_HOME/examples/break-glass-mcp-servers`.
- Deep lake + Spark SQL: `$AEGIS_HOME/docs/TUTORIAL-SPARK-ICEBERG.md`.
