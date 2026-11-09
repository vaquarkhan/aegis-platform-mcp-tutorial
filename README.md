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

**Publishable standalone project.** One Aegis MCP gateway in front of four **real** Apache engines
(Flink, Iceberg, Spark, Kafka). This repo is meant to be checked into **its own GitHub project** —
it is not part of the Aegis source tree. It **depends on** a local build of
[aegis-mcp-gateway](https://github.com/vaquarkhan/aegis-mcp-gateway) (or your fork).

Set `AEGIS_HOME` to that checkout before starting.

| Piece | Path |
| --- | --- |
| Full narrative | [TUTORIAL.md](TUTORIAL.md) |
| Governance file (the MCP server) | [aegis.yaml](aegis.yaml) |
| Start engines + Aegis | [Start-All.ps1](Start-All.ps1) |
| Guided MCP scenario | [Run-Walkthrough.ps1](Run-Walkthrough.ps1) |
| One-shot MCP client | [mcp.ps1](mcp.ps1) |
| Stop everything | [Stop-All.ps1](Stop-All.ps1) |
| Cursor IDE stub | [ide/cursor/mcp.json](ide/cursor/mcp.json) |

---

## Use case we solve

**Problem:** An IDE agent (Cursor, Claude, custom MCP client) can talk to Flink, Iceberg, Spark and
Kafka with raw REST or break-glass MCP servers. With engine credentials it can cancel jobs, drop
lake tables, pause connectors, or kill Spark drivers — including by mistake or after a prompt-
injection in table comments / metadata.

**Story (laptop demo of a real platform):**

| Persona | Job | What they need |
| --- | --- | --- |
| **Ana** (reader) | Analyst | Browse **sales** lake tables and see cluster health — never touch **finance** |
| **Eve** (operator) | Platform engineer | List topics, connectors, Spark apps; cancel a Flink job only with oversight |
| **Bob** (approver) | On-call lead | Approve Eve’s destructive actions; cannot approve his own |
| **Outsider** | No groups | Must be refused on every tool |

**What we prove in one session:**

1. Four real engines are up and seeded with a small demo dataset.
2. One MCP URL (`http://127.0.0.1:18080/mcp`) exposes tools for all four.
3. Readers are scoped to Iceberg `sales.*`; `finance` is denied.
4. Outsiders get `POLICY_DENIED`.
5. `flink_cancel_job` needs dry-run + independent approval.
6. Nobody — not even operators — can `iceberg_drop_table` on `finance.ledger` (`never-drop-finance`).
7. Every decision is written to a hash-chained audit journal under `run/audit/`.

---

## Dataset (what Start-All seeds)

Demo data only — enough for MCP reads and governance demos, not a warehouse load.

| Engine | Seeded artifacts | Meaning in the story |
| --- | --- | --- |
| **Iceberg** | Namespace `sales` → table **`orders`**; namespace `finance` → table **`ledger`** | Sales is reader-visible; finance is sensitive and drop-protected |
| **Kafka** | Topic **`orders`**; Connect connector **`orders-file-source`**; file `orders.txt` as the source | Streaming “orders” feed an agent might inspect |
| **Flink** | One running streaming job (job id printed / stored in `run/state.json` as `flink.jobId`) | Something real to list and (with approval) cancel |
| **Spark** | Standalone Master + a **SUBMITTED** driver id (`spark.driver`) | Apps an operator can list without a full YARN cluster |

Ports after start:

| Service | URL / port |
| --- | --- |
| Aegis MCP | `http://127.0.0.1:18080/mcp` |
| Aegis health | `http://127.0.0.1:18080/healthz` |
| Flink JobManager REST | `http://127.0.0.1:18081` |
| Iceberg REST catalog | `http://127.0.0.1:18181` |
| Spark app UI / Master | `14040` / `16066` |
| Kafka broker / Connect | `19092` / `http://127.0.0.1:18083` |

---

## What Aegis does here

Aegis sits **between** the IDE/agent and the engines. The agent never holds Flink/Iceberg/Spark/Kafka
admin credentials for free-form use. For every `tools/call` Aegis:

1. **Authenticates** the bearer token → maps to an actor (`ana` / `eve` / `bob` / `outsider`).
2. **Classifies** the tool (`READ` / `MUTATE` / `DESTRUCTIVE`) from `aegis.yaml`.
3. **Applies policy + scopes** (e.g. readers → `iceberg:table:sales.*` only; hard DENY on finance drops).
4. **Checks egress** (loopback CIDRs only in this tutorial).
5. For **MUTATE / DESTRUCTIVE**: requires **independent approval**; for **DESTRUCTIVE** also a
   **fresh dry-run receipt** bound to the same action.
6. **Audits** allow/deny to `run/audit/aegis-platform.jsonl`, then forwards the HTTP call to the engine
   only if allowed.

Sources in this demo: `flink`, `iceberg`, `spark-history`, `spark-master`, `kafka-connect`,
`kafka-admin` — all declared in [aegis.yaml](aegis.yaml). Capability comes from those HTTP tool
descriptors; **governance stays in the engine**, not in the sources.

---

## Prerequisites

- Windows PowerShell 5.1+
- JDK 17+, Maven 3.9+
- A **built** Aegis tree with real-engine deps:

```powershell
cd $env:AEGIS_HOME   # path to your aegis-mcp-gateway clone
mvn -B -Preal-engines -DskipTests install
```

That produces (among other things):

- `examples/aegis-gateway-kafka/target/aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar` (this tutorial’s gateway)
- Engine classpaths under `examples/aegis-validation*/target/` and break-glass launchers under
  `examples/break-glass-mcp-servers/`

Then point this tutorial at that tree:

```powershell
$env:AEGIS_HOME = 'C:\path\to\aegis-mcp-gateway'
```

---

## Quick start (commands)

```powershell
$env:AEGIS_HOME = 'C:\path\to\aegis-mcp-gateway'
cd <this-repo>
.\Start-All.ps1
.\Run-Walkthrough.ps1
.\Stop-All.ps1
```

Tokens (rotated each Start-All): `run\keys\tokens.json`  
Session facts (job ids, tables, connector): `run\state.json`

### CLI MCP calls (`mcp.ps1`)

```powershell
.\mcp.ps1 -Persona reader -Method tools/list
.\mcp.ps1 -Persona reader -Tool flink_get_cluster_info
.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Arguments @{ namespace = 'sales' }
.\mcp.ps1 -Persona reader -Tool iceberg_list_tables -Arguments @{ namespace = 'finance' }   # SCOPE_DENIED
.\mcp.ps1 -Persona reader -Tool kafka_list_topics
.\mcp.ps1 -Persona reader -Tool spark_list_applications -Arguments @{ limit = 10 }
.\mcp.ps1 -Persona outsider -Tool flink_get_cluster_info                                 # POLICY_DENIED
.\mcp.ps1 -Persona operator -Tool connect_list_connectors
.\mcp.ps1 -Persona operator -Tool iceberg_drop_table -Arguments @{ namespace = 'finance'; table = 'ledger' }  # DENY
```

### Cursor / IDE MCP setup

1. Run `.\Start-All.ps1` and open `run\keys\tokens.json`.
2. Copy [ide/cursor/mcp.json](ide/cursor/mcp.json) into Cursor MCP settings (or merge the server block).
3. Replace the bearer with the **`reader`** token (or `operator` / `approver` for those personas).

```json
{
  "mcpServers": {
    "aegis-platform": {
      "url": "http://127.0.0.1:18080/mcp",
      "headers": {
        "Authorization": "Bearer <reader token from run/keys/tokens.json>"
      }
    }
  }
}
```

4. In the IDE chat, try prompts such as:

- “List MCP tools and summarize what each engine can do.”
- “Show Iceberg tables in the `sales` namespace and the schema of `sales.orders`.”
- “What tables are in `finance`?” → expect scope deny for the reader token.
- “List Kafka topics and Connect connectors.” (use operator token for connectors if needed)
- “Cancel Flink job `<jobId from run/state.json>`.” → expect approval / dry-run flow, not a blind cancel.

---

## People and groups

| Persona (`mcp.ps1 -Persona`) | Actor in YAML | Groups | Typical use |
| --- | --- | --- | --- |
| `reader` | `ana` | `platform-readers` | browse sales + cluster reads |
| `operator` | `eve` | `platform-operators` | mutate / destructive (with approval) |
| `approver` | `bob` | `platform-approvers` | approve Eve; cannot self-approve |
| `outsider` | `outsider` | none | must be refused |

---

## What “real” means here

| Engine | What Start-All starts |
| --- | --- |
| Flink 1.20.1 | MiniCluster JobManager REST on `18081` + a running job |
| Iceberg 1.10.1 | Official `RESTCatalogServer` on `18181` with `sales.orders` and `finance.ledger` |
| Spark 4.0.1 | App UI on `14040` + Master REST on `16066` with a SUBMITTED driver |
| Kafka 3.9.1 | KRaft on `19092` + Connect on `18083` with `orders-file-source` |

Same HTTP APIs as standalone clusters; not multi-host YARN/K8s. Launchers are the ones used by
`$AEGIS_HOME/examples/break-glass-mcp-servers` and the FrontDoors tests.

---

## Publish as its own GitHub repo

This directory is intentional standalone content (Apache-2.0 headers). Suggested flow:

```powershell
cd <parent-of-this-folder>
gh repo create aegis-platform-mcp-tutorial --public --source=. --remote=origin --push
```

Do **not** nest it under the Aegis Incubator tree for release. Point readers at `AEGIS_HOME` + the
build command above. Keep `run/` gitignored (tokens, audit, engine workdirs).

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `AEGIS_HOME is not set` / missing break-glass lib | `$env:AEGIS_HOME = '...\aegis-mcp-gateway'` |
| `missing build output` | `mvn -B -Preal-engines -DskipTests install` in `$AEGIS_HOME` |
| `ERR_CONNECTION_REFUSED` on `:18080` | Stack not up — run `.\Start-All.ps1`; wait for `/healthz` 200 |
| Stale Flink `NoClassDefFoundError` / wrong `.m2` user | Delete `$AEGIS_HOME\examples\break-glass-mcp-servers\flink\run\_classpath` (and spark) and restart |
| `port … is in use` / `already started` | `.\Stop-All.ps1`; remove stale `run\state.json` only after stop |
| Kafka admin tools missing | Rebuild so `aegis-gateway-kafka-…-all.jar` exists |

See [TUTORIAL.md](TUTORIAL.md) for the governed Flink cancel walkthrough and YAML section map.
