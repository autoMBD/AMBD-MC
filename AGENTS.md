# AMBD-MC agent guidance

- Read `docs/agent-environment.md` before setting up or updating MathWorks tooling.
- Use the official MATLAB MCP Server, MATLAB Agentic Toolkit and Simulink Agentic Toolkit versions in `tools/agent/official.lock.json`. Simulink tools extend the same MCP server.
- Use `tools/agent/agent-env.ps1 Doctor` for configuration checks and `Smoke` for actual MATLAB/Simulink execution. A successful installation is not runtime acceptance.
- Consult the latest Smoke `skill_eligibility` and capability matrix before selecting a skill. Skip `UNAVAILABLE` / `UNKNOWN` skills, explain their missing products or dependencies, and use an eligible alternative. `ELIGIBLE` means manifest prerequisites were detected; execution still depends on the current license and task inputs.
- Bootstrap and normal Sync use the lock. Updates require explicit `CheckUpdates` / `Sync -Latest`; do not silently follow upstream `main` or run global toolkit update commands.
- Keep upstream tools and skills unmodified in ignored `.agent-env/` bundles. Put project-specific skills beside `.agents/skills/ambd-mathworks`, and project rules in this file. Never rewrite personal MCP settings or remove unowned skills.
- Configure project `ambd_matlab` only. Preserve other servers and user settings. Restart the Codex task after environment changes. Use `new` sessions for automated smoke tests; do not close a user's existing MATLAB session.
- Prefer official model inspection tools before editing models. Explain model/test/code-generation failures separately from missing licenses, toolboxes or agent transport failures.
- `main` currently has no active `.slx` models under `mc-models/` and no `tools/generate_data_type_from_md.m`. Report missing integrations as SKIP, not PASS. Do not import another branch's model changes to satisfy an environment check.
- All `legacy/` files have separate licensing restrictions documented in README. Never edit, save, regenerate or distribute them. Smoke may inspect saved XML without loading hardware callbacks.
- Store smoke models, reports, caches and generated code in `.agent-env/`. Keep binaries, machine paths and credentials out of Git.
- Run `python -m unittest discover -s tests/agent -v` and `python tools/test_check_spdx.py` after changing environment management. Use a real MCP Smoke when runtime initialization or tool registration changes.
