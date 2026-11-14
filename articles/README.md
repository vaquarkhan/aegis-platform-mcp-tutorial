# Articles

A three-part series on governing an AI agent across a streaming lakehouse with one Aegis MCP gateway. Written by Vaquar Khan. Each part was run, not sketched, and every output is copied from a real run.

| Part | Article | Covers |
| --- | --- | --- |
| 1 | [part1/DZONE-ARTICLE-PART1.md](part1/DZONE-ARTICLE-PART1.md) | the incident, the MCP risk, the local build, dataset and tokens, connecting Cursor, Kiro, VS Code Copilot, Claude Desktop, and Gemini CLI, and the first allow and deny calls |
| 2 | [part2/DZONE-ARTICLE-PART2.md](part2/DZONE-ARTICLE-PART2.md) | how each engine starts, the full `aegis.yaml` rule by rule, the hard deny, the dry run, the independent single-use approval, and audit verification |
| 3 | [part3/DZONE-ARTICLE-PART3.md](part3/DZONE-ARTICLE-PART3.md) | the same gateway on AWS: SSM-only EC2, Cognito JWT identity, S3 evidence, modular Terraform, and teardown |

## Folder layout

Each `partN/` folder is self-contained:

- `DZONE-ARTICLE-PARTN.md` is the article.
- `images/` holds the SVG diagrams and their PNG renders. Markdown references them as `images/<name>.svg`.
- `code/` holds the runnable code the article shows. Part 1 has the IDE client templates, Part 2 has the gateway scripts, launchers, and `aegis.yaml`, Part 3 has `cli/`, `remote/`, and `terraform/`.
- `snippets/` is a generated mirror of every fenced code block in the article, numbered in article order, with an `INDEX.md`. Files ending in `.txt` are captured output, not commands to run.

## Keeping it consistent

`part1/code` and `part2/code` are publication snapshots of the runnable files at the repository root, which are the ones `Start-All.ps1` and friends actually execute. When a root script changes, refresh its snapshot deliberately.

Tools under `tools/` (run with the repository's Python):

- `extract_snippets.py` regenerates every `snippets/` folder from the article fences.
- `check_links.py` verifies that every relative link and image resolves.
- `check_fences.py` confirms each article's code fences are balanced.
- `scan_secrets.py` fails if any published file carries a real account id, resource id, token, secret, or local user path.

Run all four before publishing:

```powershell
python articles/tools/extract_snippets.py
python articles/tools/check_fences.py
python articles/tools/check_links.py
python articles/tools/scan_secrets.py
```

## Placeholders in Part 3

Part 3's article, diagram, and scripts use capitalized placeholders (`ACCOUNT_ID`, `vpc-DEFAULT`, `us-east-1_POOLID`, `APP_CLIENT_ID`, `aegis-evidence-ACCOUNT_ID`, `YOUR_PROFILE`) wherever the recorded run had a real value. Nothing depends on the specific ids. `part3/code/terraform` creates the infrastructure from a bucket name and a `passwords.auto.tfvars`.
