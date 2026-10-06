---
name: uniform-file-header
description: Add standardized license headers to newly created source or script files and root-level license annotations to new MATLAB/Simulink models when MATLAB/Simulink MCP is available. Use for new .c, .h, .m, .py, .cpp, .slx, or .mdl files, other user-specified source files, or requests to add or update a header or license banner. Select the license from explicit user instructions or the repository root license, with MIT as the fallback; includes MIT and Apache License 2.0 templates.
---

# Uniform File Header

## Use This Skill

Apply this skill whenever creating a new source or script file or MATLAB/Simulink model, especially:

- `.c`
- `.h`
- `.m`
- `.py`
- `.cpp`
- `.slx`, `.mdl` (Simulink models; use a root-level text annotation)
- Any other language or script format explicitly requested by the user

Also apply it when the user asks to add, replace, or standardize a file header.

## Required Workflow

1. Determine the target file name and format. For source files, infer comment syntax; for Simulink models, follow [simulink-models.md](simulink-models.md).
2. Select the license using the License Rules below before generating the header.
3. Insert the header at the very top of a new source file before any code. For a new model, place the equivalent plain text in an annotation at the model root through available MATLAB/Simulink MCP tools.
4. Copy the license block and file-information block using the exact layout from [reference.md](reference.md). Do not reflow, paraphrase, or redesign the template.
5. Fill metadata from context when available:
   - `Project:` known repository or product name, including project URL when known
   - `File:` target file name
   - `Author:` known author name and email
   - `Date:` current date in `YYYY-MM-DD`
   - `Version:` default `0.1.0` for a new file unless context clearly implies another starting version
   - `Description:` concise, context-aware summary of the file's purpose
6. If project name/link is unknown, ask the user.
7. If author name/email is unknown, ask the user.
8. Do not ask for comment syntax for the default formats. Infer it automatically.
9. If the user specifies another source language or file type, infer the correct comment syntax automatically and still apply the same header structure. Model annotations use plain text without comment tokens.

## Comment Syntax Rules

Use line comments when the language supports them:

- `.m` -> `%`
- `.py` -> `#`
- `.c`, `.h`, `.cpp` -> `//`

For other file types, infer the idiomatic comment syntax from the language:

- Prefer a single-line comment token repeated on every line when available.
- If the language only supports block comments, wrap the same internal text in the language's standard block-comment form while preserving line order, blank lines, labels, and alignment as closely as the syntax allows.
- Do not ask the user for the comment token unless the language itself is ambiguous and cannot be inferred from the requested file type.

## License Rules

Select the license in this order:

1. An explicit user request for the new file or model takes precedence. For Apache License 2.0, use `Apache-2.0`.
2. Otherwise inspect the repository root license (for example, `LICENSE`, `LICENSE.txt`, `LICENSE.md`, or `COPYING`). Identify the actual license from its contents, not the filename or a dependency notice. If it licenses the repository under Apache License, Version 2.0, use `Apache-2.0` automatically. Honor other clearly identified repository licenses as well.
3. If no repository license is declared and the user has not selected one, default to MIT (`MIT`). If root declarations conflict or require a choice between multiple licenses, resolve the applicable license from project instructions or ask only for that missing choice; do not silently default to MIT.

- For MIT, use the exact bilingual MIT block from [reference.md](reference.md).
- For Apache License 2.0, use the exact Apache template from [reference.md](reference.md), including its official application notice and `Apache-2.0` identifier.
- For another selected license, use the corresponding license notice and SPDX identifier while preserving:
  - the top and bottom separator lines
  - blank-line positions
  - the file-information section layout
  - the metadata field labels and alignment

If the repository already contains an established header for the selected license, follow that project pattern first. A header for a different license does not override the selection above. Otherwise use the bundled MIT/Apache template or the official notice for another license. Selecting a new-file header does not change the repository license or relicense existing files.

## Metadata Rules

Infer metadata from the immediate context before asking:

- Read nearby files in the same repository when needed to discover the project name, project URL, author name, or author email.
- Reuse an existing repository header style when present.
- If the context clearly identifies project and author from git config, use those values directly.
- If either project or author information is still unknown after checking context, ask the user only for the missing fields.

## Description Formatting Rules

- Keep the `Description:` label and value alignment exactly as shown in [reference.md](reference.md).
- Write a short, concrete description based on the file's actual role.
- If the description exceeds one line, continue on the next line with the exact continuation indent from the reference template.
- Do not change the label names, colon positions, or separator widths.

## Quality Check

Before finalizing the file, verify:

- For source files, the header is the first content in the file and the comment prefix matches the language
- For models created through available MATLAB/Simulink MCP, the saved model contains a readable license text annotation at the model root, as verified in [simulink-models.md](simulink-models.md)
- The license follows explicit user instructions, otherwise the root repository license, with MIT only as the fallback
- The license notice and SPDX identifier agree (`MIT` or `Apache-2.0` for the bundled templates)
- The file-information block matches the reference layout exactly
- `File`, `Date`, `Version`, and `Description` are filled
- `Project` and `Author` are filled from context or were explicitly requested from the user

## Additional Resource

- For exact MIT and Apache License 2.0 templates, alignment, and comment-style examples, read [reference.md](reference.md)
- For new Simulink models and MCP-based root annotations, read [simulink-models.md](simulink-models.md)
