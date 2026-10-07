# Simulink Model License Annotation

Apply this workflow when creating a new `.slx` or `.mdl` model. MATLAB `.m` source files continue to use `%` line-comment headers.

## MCP Availability

Discover the available MATLAB/Simulink MCP capabilities before creating the model. When a callable tool can create/edit model annotations or execute MATLAB commands with Simulink available, use it to add the license annotation as part of model creation. Use the actual tool schema; do not assume a particular server or tool name.

If MCP is absent, cannot edit annotations or execute the required commands, or reports that Simulink is unavailable, report that the model annotation could not be applied. Provide the resolved plain-text header for later insertion and continue independently authorized work. Do not claim that an annotation was created, install a server automatically, or prepend text to `.slx`/`.mdl` files.

## Annotation Content and Placement

1. Select the license using `SKILL.md` and fill the matching [reference template](reference.md). Apply the same selection rules to models as source files: explicit request first, root repository license next, MIT fallback. Set `File:` to the model filename, including `.slx` or `.mdl`.
2. Convert the complete license and file-information blocks to plain text by removing the comment prefixes. Preserve notice wording, line breaks, separators, and metadata alignment. Include the actual license notice, not merely a license name, SPDX identifier, or URL.
3. Add a text annotation (`Simulink.Annotation`) directly to the newly created model's root block diagram. The requested text module is an annotation, not an executable block. Pass the explicit target model name as the containing system, never a subsystem path or an unrelated current model. See the official [Simulink.Annotation documentation](https://www.mathworks.com/help/simulink/slref/simulink.annotation.html).
4. If the MCP exposes MATLAB execution, `Simulink.Annotation(modelName, headerText)` can create it, where `modelName` is the loaded target model's root name and `headerText` is the fully rendered character vector. Prefer structured text arguments or safely escaped MATLAB strings; preserve literal quotes, newlines, and backslashes in metadata.
5. Place the annotation in a readable free area near the top-left of the root canvas, without covering blocks or signal lines. Use plain-text formatting and a readable font; preserve alignment with a monospaced font where available. Do not add ports, connections, or executable behavior.
6. On retry, inspect the target model's existing root annotations first. Reuse or update the matching license annotation instead of adding duplicates; preserve unrelated annotations.
7. Save the intended model after adding the annotation. A header in the MATLAB script that generated the model does not satisfy this requirement.

## Verification

Through the available MCP, read back the saved model's annotations (reload the saved model when practical) and verify that the license annotation belongs directly to the target root, contains the selected license notice and metadata, and has no unresolved template placeholders or source-code comment prefixes. If a model view or screenshot is available, also verify readability and absence of overlap. Report any verification that could not be performed; a successful creation call alone does not verify persistence or layout.
