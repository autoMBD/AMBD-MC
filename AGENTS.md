# AMBD-MC agent guidance

- Read `docs/development/agent-environment.md` before setting up or updating MathWorks tooling.
- Use the official MATLAB MCP Server, MATLAB Agentic Toolkit and Simulink Agentic Toolkit versions in `tools/agent/official.lock.json`. Simulink tools extend the same MCP server.
- Use `tools/agent/agent-env.ps1 Doctor` for configuration checks and `Smoke` for actual MATLAB/Simulink execution. A successful installation is not runtime acceptance.
- Consult the latest Smoke `skill_eligibility` and capability matrix before selecting a skill. Skip `UNAVAILABLE` / `UNKNOWN` skills, explain their missing products or dependencies, and use an eligible alternative. `ELIGIBLE` means manifest prerequisites were detected; execution still depends on the current license and task inputs.
- Bootstrap and normal Sync use the lock. Updates require explicit `CheckUpdates` / `Sync -Latest`; do not silently follow upstream `main` or run global toolkit update commands.
- Keep upstream tools and skills unmodified in ignored `.agent-env/` bundles. Put project-specific skills beside `.agents/skills/ambd-mathworks`, and project rules in this file. Never rewrite personal MCP settings or remove unowned skills.
- Configure project `ambd_matlab` only. Preserve other servers and user settings. Restart the Codex task after environment changes. Use `new` sessions for automated smoke tests; do not close a user's existing MATLAB session.
- Prefer official model inspection tools before editing models. Explain model/test/code-generation failures separately from missing licenses, toolboxes or agent transport failures.
- Active BLDC/PMSM models are listed in `mc-models/hsp/models.json`; `tools/generate_data_type_from_md.m` owns the Markdown type workflow. Report missing task inputs as SKIP, not PASS.
- All `legacy/` files have separate licensing restrictions documented in README. Never edit, save, regenerate or distribute them. Smoke may inspect saved XML without loading hardware callbacks.
- Store smoke models, reports, caches and generated code in `.agent-env/`. Keep binaries, machine paths and credentials out of Git.
- Run `python -m unittest discover -s tests/agent -v` and `python tools/test_check_spdx.py` after changing environment management. Use a real MCP Smoke when runtime initialization or tool registration changes.

## Documentation and internal records

- Public `docs/` contains reusable user guides, hardware instructions, system/interface specifications and project policy only. Use `manual/`, `hardware/`, `specs/`, `development/` and `project/`; keep the two generator-owned type sources at their current root paths.
- After changing or updating code, models, configuration or workflows, promptly review and synchronize the relevant documents under `docs/` within the same task. Keep documented behavior, interfaces, parameters, commands and usage consistent with the implementation before declaring the task complete.
- Every PR must describe documentation synchronization: identify the relevant `docs/` pages and summarize their updates. If no documentation update is needed, explicitly explain why the changes do not affect the documented implementation or usage. Keep internal task records local according to the rules below.
- All task-specific development/implementation plans, test execution plans, validation/acceptance reports, experiment logs, review notes, audits, source fingerprints and raw evidence are internal. Save them only in ignored `.agent-env/plans/`, `.agent-env/reports/`, `.agent-env/audits/` or the existing tool-owned `.agent-env/` subdirectories. Never commit, force-add, upload as public artifacts or link to them from the public site.
- This local-only rule overrides any skill default such as `docs/superpowers/plans/`. Archived internal documents belong in `.agent-env/internal-docs/`; do not recreate `docs/validation/`, `docs/superpowers/` or internal reports under another public name.
- When organizing public documents, consolidate repeated instructions, update all repository/site links and preserve useful public URLs with redirects. Do not redirect or republish internal-document URLs. Run the documentation tests, strict build and repository/site boundary checks before submitting changes.
