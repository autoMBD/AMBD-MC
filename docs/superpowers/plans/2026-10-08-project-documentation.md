# Issue #6 project documentation implementation plan

**Goal:** Replace the public template site with an accurate motor-control manual and enforce publication checks.

**Architecture:** Keep existing page URLs and type-source paths. Move the two motor README guides into the manual with repository entry-point links. Publish design specifications and dated evidence through explicit navigation; exclude work plans and the license-header audit from the build.

**Tech stack:** MkDocs Material, pinned Python dependencies, Python unittest, GitHub Pages Actions.

## Tasks

- [x] Replace the ten template pages in `docs/` with project introduction, executable setup paths, architecture, scenarios, FAQ, real history, license scope and contribution links. Preserve historical URLs.
- [x] Create `docs/manual/pmsm.md` and `docs/manual/bldc.md` from the corresponding model READMEs; leave concise repository pointers. Add `docs/manual/index.md` and `docs/validation/index.md` for prerequisites and evidence boundaries.
- [x] Correct stale prose and links in type references/specifications without changing type tables. Convert repository links to GitHub URLs and local evidence links to explicitly local paths. Preserve dated results.
- [x] Add `docs/documentation.md` describing source ownership, the completed content disposition inventory, build commands and publication policy. No independent manual manuscript was found among tracked files; use the current repository guides as the manual source.
- [x] Pin documentation dependencies in `requirements-docs.txt`; set `site_url`, full navigation, exclusions and strict validation in `mkdocs.yml`. Build under `.agent-env/docs/site`.
- [x] Add failing fixture tests for a generated-site checker: missing targets and anchors, valid project-prefix links, search/sitemap consistency and private publication rejection. Implement the checker and confirm tests pass. Apply the project MIT header to new Python files.
- [x] Update the Pages workflow to run unit tests, strict build and blocking link/publication checks before artifact upload. External failures require an exact, documented exception.
- [x] Run the full documentation pipeline, source-header check, protected-file diff/hash checks and browser preview. Have an independent reviewer inspect content and CI changes, resolve actionable findings, then hand off to the authorized commit, push and PR steps with `Closes #6` and actual validation results.

## Verification commands

From the repository root, use the documentation virtual environment:

```powershell
python -m unittest discover -s tests/docs -v
python -m mkdocs build --strict
python tools/docs/check_site.py .agent-env/docs/site --external
python tools/test_check_spdx.py
git diff --check
```

The checker must fail on broken built-site links, missing anchors, inconsistent search/sitemap entries or accidentally published private paths. It must not treat a locally present `.agent-env` file as a published attachment. This task does not change or re-execute the motor algorithms, models, tool environment or hardware tests; historical runtime results remain attributed to their original reports. Main deployment is verified after merge by the Pages workflow; this PR validates its exact build artifact before merge.

## Actual verification

- Strict MkDocs build: 44 published pages, zero validation warnings.
- Site checker: local links, anchors, search/sitemap consistency and publication boundaries passed.
- 17 regression tests passed, including real HTTP failure/retry fixtures.
- 47 external/source checks passed under 9 exact documented HTTP exceptions (6 MathWorks 403; 3 NXP 404 confirmed available in browser).
- Browser preview: homepage layout and Hall search results verified; no browser warning/error logs.
- Both type-source table/marker sequences unchanged; no algorithm, model, dictionary, runtime-environment or legacy change.
- Independent review: corrected the copied BLDC standalone-build claim and PMSM latest-report wording.
- MATLAB/Simulink/hardware execution was not repeated for this documentation-only change.
