# Issue #12 uniform file headers implementation plan

**Goal:** Normalize project-owned MIT notices while preserving source behavior,
existing metadata, local skills, and independent third-party licenses.

**Architecture:** Use the established bilingual project header with language-specific
line comments. Validate complete notices and metadata in the existing Python CLI;
use a separate saved-model annotation check for Simulink artifacts.

**Tech stack:** Python standard library, Git, PowerShell, official MATLAB MCP.

- [x] Inventory tracked files from origin/main `0749a75181c618da072633373a5d87ff8d669caa`;
  record ownership exclusions and metadata provenance in `docs/license-header-audit.md`.
- [x] Add failing regression cases in `tests/headers/test_headers.py` for SPDX-only,
  corrupt notices, missing fields, prefixes, placeholders, duplicate headers,
  interpreter directives, and tracked/excluded scope.
  Run `python -m unittest discover -s tests/headers -v` before implementation.
- [x] Extend `tools/test_check_spdx.py` to validate complete MIT headers, classify
  tracked text/model/excluded files, and report model validation separately.
- [x] Normalize owned source headers only, preserving help, codegen directives,
  shebangs, encoding declarations, execution bodies and historical metadata.
- [x] Through official MATLAB MCP inspect/update root model annotations and read
  back after saving; compare executable model XML and annotation bounds. Record
  unavailable dependencies as SKIP. Keep scripts/reports under `.agent-env/`.
- [x] Run header regression tests, full header CLI, agent and BLDC Python suites,
  PowerShell parser, source-body equivalence checks, and model readback checks.
  Environment initialization/tool registration are unchanged: Smoke is not required.
- Final publication: request independent review per requesting-code-review skill, resolve findings,
  commit the unchanged local skill and issue changes, push the issue branch and
  create a PR targeting main with `Closes #12` and actual results.

Execution proceeds autonomously as authorized by the user. Model annotation work
may be delegated as an independent plan task; source normalization and checker
development remain in the primary task. No merge or main push is authorized.
