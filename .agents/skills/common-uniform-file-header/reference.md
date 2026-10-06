# Reference Template

## Apply This Reference Exactly

Use this reference when the skill is triggered.

- Replace placeholders only.
- Preserve the separator lines, blank lines, label names, alignment, and line-wrap positions.
- Select the MIT or Apache License 2.0 template according to the skill's License Rules. Do not reword, re-punctuate, or reflow the selected license text.
- Keep the `IN NO EVENT SHALLTHE AUTHORS` line exactly as shown in the template.
- Adapt only the comment token to match the target language. For Simulink annotations, remove each leading `{{C}}` and its one following space (or just `{{C}}` on empty lines), preserving internal indentation and blank lines.

## Exact MIT Template For Line Comments

Use this template for languages that support repeated line comments. Replace `{{C}}` with the language-appropriate comment token such as `%`, `#`, or `//`.

```text
{{C}} =================================================================================
{{C}} The MIT License 
{{C}} MIT许可证
{{C}} 
{{C}} <https://opensource.org/license/mit>
{{C}} 
{{C}} SPDX short identifier / SPDX 短标识符：MIT 
{{C}} 
{{C}} Copyright (c) {{YEAR}} {{COPYRIGHT_HOLDER}}
{{C}} 版权所有 (c) {{YEAR}} {{COPYRIGHT_HOLDER}}
{{C}}
{{C}} Permission is hereby granted, free of charge, to any person obtaining a 
{{C}} copy of this software and associated documentation files (the "Software"), 
{{C}} to deal in the Software without restriction, including without limitation 
{{C}} the rights to use, copy, modify, merge, publish, distribute, sublicense, 
{{C}} and/or sell copies of the Software, and to permit persons to whom the 
{{C}} Software is furnished to do so, subject to the following conditions:
{{C}} 特此向获得本软件及相关文档（合称"本软件"）副本的任何人免费授予不受限制地利用本软
{{C}} 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
{{C}} 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
{{C}} 
{{C}} The above copyright notice and this permission notice shall be included 
{{C}} in all copies or substantial portions of the Software.
{{C}} 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
{{C}} 
{{C}} THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
{{C}} EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
{{C}} MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
{{C}} NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT 
{{C}} HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
{{C}} IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
{{C}} CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
{{C}} SOFTWARE.
{{C}} 本软件系"按原样"提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
{{C}} 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
{{C}} 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
{{C}} 何权利主张、损害赔偿或其他责任承担责任。
{{C}} =================================================================================
{{C}} Project:     {{PROJECT_NAME_AND_LINK}}
{{C}} File:        {{FILE_NAME}}
{{C}} Author:      {{AUTHOR_NAME_AND_EMAIL}}
{{C}} Date:        {{DATE_YYYY_MM_DD}}
{{C}} Version:     {{VERSION}}
{{C}} Description: {{DESCRIPTION_LINE_1}}
{{C}}              {{DESCRIPTION_LINE_2_IF_NEEDED}}
{{C}} =================================================================================
```

## Exact Apache License 2.0 Template For Line Comments

Use when the user explicitly requests Apache License 2.0 or the repository root license identifies Apache License, Version 2.0. Replace `{{C}}` as for the MIT template. The English notice below is the official [Apache application boilerplate](https://www.apache.org/licenses/LICENSE-2.0#apply), rather than the full license terms; it does not replace the repository's full `LICENSE` file.

```text
{{C}} =================================================================================
{{C}} Apache License, Version 2.0
{{C}} Apache许可证，版本2.0
{{C}}
{{C}} <https://www.apache.org/licenses/LICENSE-2.0>
{{C}}
{{C}} SPDX short identifier / SPDX 短标识符：Apache-2.0
{{C}}
{{C}} Copyright {{YEAR}} {{COPYRIGHT_HOLDER}}
{{C}} 版权所有 {{YEAR}} {{COPYRIGHT_HOLDER}}
{{C}}
{{C}} Licensed under the Apache License, Version 2.0 (the "License");
{{C}} you may not use this file except in compliance with the License.
{{C}} You may obtain a copy of the License at
{{C}}
{{C}}     http://www.apache.org/licenses/LICENSE-2.0
{{C}}
{{C}} Unless required by applicable law or agreed to in writing, software
{{C}} distributed under the License is distributed on an "AS IS" BASIS,
{{C}} WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
{{C}} See the License for the specific language governing permissions and
{{C}} limitations under the License.
{{C}} =================================================================================
{{C}} Project:     {{PROJECT_NAME_AND_LINK}}
{{C}} File:        {{FILE_NAME}}
{{C}} Author:      {{AUTHOR_NAME_AND_EMAIL}}
{{C}} Date:        {{DATE_YYYY_MM_DD}}
{{C}} Version:     {{VERSION}}
{{C}} Description: {{DESCRIPTION_LINE_1}}
{{C}}              {{DESCRIPTION_LINE_2_IF_NEEDED}}
{{C}} =================================================================================
```

## Default Comment Mapping

Use these mappings without asking the user:

- `.m` -> `%`
- `.py` -> `#`
- `.c` -> `//`
- `.h` -> `//`
- `.cpp` -> `//`
- `.slx`, `.mdl` -> plain text in a model-root annotation; no comment token and no raw file header insertion

For another explicitly requested language or file type, infer the idiomatic comment token automatically.

## Metadata Fill Rules

- `{{YEAR}}`: current copyright year for the new file or model unless context supplies a specific year
- `{{COPYRIGHT_HOLDER}}`: the rights holder identified by the user or project context; do not assume a license publisher (such as the Apache Software Foundation) is the holder. Ask if it cannot be inferred.
- `{{PROJECT_NAME_AND_LINK}}`: preferred format is `Project Name <https://example.com/repo>`
- `{{FILE_NAME}}`: the base name of the file being created
- `{{AUTHOR_NAME_AND_EMAIL}}`: preferred format is `Name <email@example.com>`
- `{{DATE_YYYY_MM_DD}}`: current date
- `{{VERSION}}`: default `0.1.0` for a new file
- `{{DESCRIPTION_LINE_1}}` and `{{DESCRIPTION_LINE_2_IF_NEEDED}}`: concise purpose statement wrapped to match the template's alignment

If the description fits on one line, omit the continuation line completely rather than leaving a placeholder.

## Block Comment Fallback

If the target language does not support repeated line comments, keep the internal text identical and wrap it in the language's standard block-comment syntax.

Example structure:

```text
/* =================================================================================
 * The MIT License 
 * MIT许可证
 * ...
 * Description: {{DESCRIPTION_LINE_1}}
 *              {{DESCRIPTION_LINE_2_IF_NEEDED}}
 * ================================================================================= */
```

Use block comments only when line comments are not idiomatic or not supported.
