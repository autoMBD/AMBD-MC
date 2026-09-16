# MathWorks Agent Environment Implementation Plan

> For agentic workers: implement these tasks sequentially and review the resulting changes before delivery.

**Goal:** Implement issue #10 on a branch based on `main`, with official MathWorks tools, reproducible installation, update discovery, validation and rollback.

**Architecture:** A PowerShell entry point delegates portable dependency/state management to Python 3.11+ standard-library modules. Official release archives and the MathWorks installer supply all MATLAB/Simulink tools and skills. Project configuration points to an immutable, verified environment; candidate validation precedes activation, and previous environments remain available for rollback.

**Tech stack:** PowerShell 7, Python 3.11+, MATLAB R2023a+ with Simulink, official MATLAB MCP Server and Agentic Toolkits, GitHub Actions.

The user authorized implementation of #10. Work starts at `main` commit `094313534a69c77e32eedb500beae02fcaefdf59`. This baseline lacks the PMSM refactor and Markdown type generator; project checks must report those omissions separately from environment smoke tests.

## Tasks

- [x] Establish official release references, content hashes and installer parameters; reproduce MATLAB startup with the execution environment identified.
- [x] Add `tests/agent/` tests for lock validation, archive traversal, hash mismatch, unchanged-version checks, configuration ownership, failed activation and rollback. Run `python -m unittest discover -s tests/agent -v` before implementing the tested behavior.
- [x] Implement `tools/agent/artifacts.py`: validate official sources and immutable revisions, download/cache verified assets, compare releases and construct candidate locks. Record upstream tool/skill inventory for meaningful diffs.
- [x] Implement `tools/agent/configuration.py`: manage only project-owned MCP registration and skill entries; preserve unrelated settings and detect collisions. Support repeated activation and recovery from interrupted writes.
- [x] Implement `tools/agent/mcp_client.py` and MATLAB smoke fixtures: use JSON-RPC over stdio to exercise the real official server, assert MATLAB computation/tests and a small Simulink simulation, and return structured diagnostics.
- [x] Implement `tools/agent/agent_env.py` and `agent-env.ps1`: Bootstrap, Doctor, CheckUpdates, Sync, Smoke and Rollback with explicit exit codes, offline mode, configurable MATLAB root and project-local state.
- [x] Add the locked official release manifest, project guidance, templates and `docs/agent-environment.md`. Document first setup, session selection, updates, restart, recovery and uninstallation.
- [x] Add CI tests and a scheduled/manual release check that uploads a report without installing MATLAB or mutating developer environments.
- [x] Run unit tests, license checks, syntax checks, real Bootstrap/Smoke, idempotent setup, update discovery and rollback. Independently review the change and fix actionable findings.

## Verification contract

Offline tests must reject invalid hashes and archive paths, keep an active environment intact when candidate validation fails, restore prior configuration on rollback, and preserve user-owned files. Live verification must use the MCP protocol and distinguish absent optional toolboxes or absent project files from failed required smoke checks. A successful install command alone is not evidence that MATLAB or Simulink works.

## Delivery

Report the branch, changes, test evidence and any remaining environment limitations. Do not close #10 or claim runtime acceptance until the relevant checks have actually passed.
