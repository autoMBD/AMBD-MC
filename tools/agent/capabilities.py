# SPDX-License-Identifier: MIT
"""Report skill eligibility from the dependency fields in official manifests."""
from pathlib import Path
import re


def _dependency_list(text, key):
    match = re.search(r'^' + re.escape(key) + r':([^\n]*)(\n(?:[ \t]+[^\n]*\n|[ \t]*\n)*)?', text + '\n', re.M)
    if not match:
        return []
    inline = match[1].strip()
    if inline == '[]':
        return []
    if inline and not inline.startswith('#'):
        raise ValueError('Unsupported dependency list syntax: ' + key)
    items = []
    for line in (match[2] or '').splitlines():
        value = line.strip()
        if not value or value.startswith('#'):
            continue
        if not value.startswith('- '):
            raise ValueError('Unsupported dependency list item: ' + key)
        items.append(value[2:].split(' #', 1)[0].strip().strip('"\''))
    return items


def skills(root: Path, matlab: dict, tools) -> dict:
    installed = {product['Name'] for product in matlab.get('toolboxes', [])}
    selected = {path.name for path in root.iterdir() if path.is_dir()}
    result = {}
    for name in sorted(selected):
        try:
            text = (root / name / 'manifest.yaml').read_text(encoding='utf-8')
            match = re.search(r'^matlab-release:\s*[\"\']?(>=R\d{4}[ab])[\"\']?\s*$', text, re.M)
            if not match:
                raise ValueError('Unknown MATLAB release constraint; inspect the official manifest')
            release_ok = matlab['release'] >= match[1][3:]
            missing_products = sorted(set(_dependency_list(text, 'required-products')) - installed)
            missing_tools = sorted(set(_dependency_list(text, 'required-tools')) - set(tools))
            missing_skills = sorted(set(_dependency_list(text, 'required-skills')) - selected)
            result[name] = {'status': 'UNAVAILABLE' if missing_products or missing_tools or missing_skills or not release_ok else 'ELIGIBLE',
                            'missing_products': missing_products, 'missing_tools': missing_tools,
                            'missing_skills': missing_skills, 'release_compatible': release_ok}
        except (OSError, ValueError, KeyError) as error:
            result[name] = {'status': 'UNKNOWN', 'reason': str(error)}
    return result
