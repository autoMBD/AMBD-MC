# SPDX-License-Identifier: MIT
"""Pinned official releases, integrity-checked cache, and update inventories."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen
import zipfile

REPOSITORIES = {
    'matlab': 'matlab/matlab-agentic-toolkit',
    'simulink': 'matlab/simulink-agentic-toolkit',
    'mcp': 'matlab/matlab-mcp-server',
}


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, mode='w', encoding='utf-8',
                                     delete=False, suffix='.tmp') as stream:
        tmp = Path(stream.name)
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    try:
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def validate_lock(lock: dict) -> None:
    try:
        if lock['schema_version'] != 1 or lock['platform'] != 'windows-x64':
            raise ValueError('Unsupported lock schema or platform')
        if set(lock['components']) != set(REPOSITORIES):
            raise ValueError('Lock must include MATLAB, Simulink and MCP components')
        for key, repo in REPOSITORIES.items():
            component = lock['components'][key]
            if component['repository'] != repo or not re.fullmatch('[0-9a-f]{40}', component['commit']):
                raise ValueError('Expected an official repository and immutable commit')
            tag = component['tag']
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', tag) or tag in ('main', 'latest'):
                raise ValueError('Expected a pinned release tag')
            if not component['artifacts']:
                raise ValueError('Component has no artifacts')
            for asset in component['artifacts']:
                name = asset['name']
                if not re.fullmatch(r'[A-Za-z0-9_.-]+', name) or name in ('.', '..'):
                    raise ValueError('Unsafe artifact name')
                if not re.fullmatch('[0-9a-f]{64}', asset['sha256']) or not isinstance(asset['size'], int) or asset['size'] <= 0:
                    raise ValueError('Invalid SHA-256 or artifact size')
                allowed = {
                    f'https://github.com/{repo}/releases/download/{tag}/{name}',
                    f'https://codeload.github.com/{repo}/zip/{component["commit"]}',
                }
                if asset['url'] not in allowed:
                    raise ValueError('Artifact URL is not pinned to the official source')
        for toolkit, groups in lock['skill_groups'].items():
            if toolkit not in ('matlab', 'simulink') or not isinstance(groups, list):
                raise ValueError('Invalid skill group selection')
            if any(not re.fullmatch('[a-z0-9-]+', group) for group in groups):
                raise ValueError('Unsafe skill group name')
    except (KeyError, TypeError) as error:
        raise ValueError(f'Incomplete lock: {error}') from error


def read_lock(path: Path) -> dict:
    lock = json.loads(path.read_text(encoding='utf-8'))
    validate_lock(lock)
    return lock


def lock_id(lock: dict) -> str:
    payload = {key: lock[key] for key in ('schema_version', 'platform', 'components', 'skill_groups')}
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()[:16]


def sha256(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def request(url: str):
    headers = {'User-Agent': 'AMBD-MC-agent-env', 'Accept': 'application/vnd.github+json'}
    if urlsplit(url).hostname == 'api.github.com' and os.environ.get('GITHUB_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GITHUB_TOKEN']
    return urlopen(Request(url, headers=headers), timeout=60)


def api(path: str) -> dict:
    with request('https://api.github.com/' + path) as response:
        return json.load(response)


def obtain(asset: dict, cache: Path, offline: bool = False) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / asset['sha256']
    if target.exists():
        if target.stat().st_size == asset['size'] and sha256(target) == asset['sha256']:
            return target
        raise ValueError(f'Cached artifact failed SHA-256 integrity check: {asset["name"]}')
    if offline:
        raise FileNotFoundError(f'Offline cache missing: {asset["name"]} ({asset["sha256"]})')
    with tempfile.NamedTemporaryFile(dir=cache, delete=False) as stream:
        tmp = Path(stream.name)
        try:
            with request(asset['url']) as response:
                shutil.copyfileobj(response, stream)
        except Exception:
            stream.close()
            tmp.unlink(missing_ok=True)
            raise
    try:
        if tmp.stat().st_size != asset['size'] or sha256(tmp) != asset['sha256']:
            raise ValueError(f'Download failed SHA-256 integrity check: {asset["name"]}')
        os.replace(tmp, target)
    finally:
        tmp.unlink(missing_ok=True)
    return target


def extract(archive: Path, destination: Path) -> None:
    """Validate every member before extracting any, including Windows paths."""
    with zipfile.ZipFile(archive) as zipped:
        members = zipped.infolist()
        if sum(member.file_size for member in members) > 1024 * 1024 * 1024:
            raise ValueError('Uncompressed archive exceeds 1 GiB')
        for member in members:
            path = PurePosixPath(member.filename.replace('\\', '/'))
            mode = member.external_attr >> 16
            if path.is_absolute() or '..' in path.parts or ':' in member.filename or stat.S_ISLNK(mode):
                raise ValueError(f'Unsafe archive member: {member.filename}')
            if not (destination / str(path)).resolve().is_relative_to(destination.resolve()):
                raise ValueError('Archive member escapes destination')
        destination.mkdir(parents=True, exist_ok=True)
        zipped.extractall(destination)


def inventory(toolkits: dict[str, Path], groups: dict) -> dict:
    result = {'tools': {}, 'skills': {}}
    for name, root in toolkits.items():
        for group in groups.get(name, []):
            directory = root / 'skills-catalog' / group
            if not directory.is_dir():
                raise ValueError(f'Skill group not found: {name}/{group}')
            for skill in sorted(directory.glob('*/SKILL.md')):
                # Include supporting resources: a changed reference is a skill update too.
                digester = hashlib.sha256()
                for file in sorted(p for p in skill.parent.rglob('*') if p.is_file()):
                    digester.update(file.relative_to(skill.parent).as_posix().encode())
                    digester.update(file.read_bytes())
                result['skills'][f'{name}/{group}/{skill.parent.name}'] = digester.hexdigest()
        tools_file = root / 'tools' / 'tools.json'
        if tools_file.exists():
            content = json.loads(tools_file.read_text(encoding='utf-8'))
            tools = content if isinstance(content, list) else content.get('tools', [])
            for tool in tools:
                result['tools'][tool['name']] = hashlib.sha256(json.dumps(tool, sort_keys=True).encode()).hexdigest()
    return result


def inventory_diff(before: dict, after: dict) -> dict:
    result = {}
    for category in ('tools', 'skills'):
        old, new = before.get(category, {}), after.get(category, {})
        result[category] = {
            'added': sorted(new.keys() - old.keys()),
            'removed': sorted(old.keys() - new.keys()),
            'changed': sorted(key for key in old.keys() & new.keys() if old[key] != new[key]),
        }
    return result


def latest_releases() -> dict:
    return {key: api(f'repos/{repo}/releases/latest') for key, repo in REPOSITORIES.items()}


def resolve_latest(groups: dict, cache: Path, releases: dict | None = None) -> dict:
    """Resolve latest once; future installations use only this returned lock."""
    components = {}
    for key, release in (releases or latest_releases()).items():
        repo = REPOSITORIES[key]
        tag = release['tag_name']
        commit = api(f'repos/{repo}/commits/{quote(tag, safe="")}')['sha']
        wanted = ({'matlab-mcp-server-windows-x64.exe', 'matlab-mcp-core-server-win64.exe',
                   'MATLABMCPServerToolbox.mltbx'} if key == 'mcp' else
                  {'agenticToolkitInstaller.mltbx'} if key == 'simulink' else set())
        assets = []
        for asset in release['assets']:
            if asset['name'] in wanted:
                digest = asset.get('digest') or ''
                if not digest.startswith('sha256:'):
                    raise ValueError(f'GitHub did not provide SHA-256 for {asset["name"]}')
                assets.append({'name': asset['name'], 'url': asset['browser_download_url'],
                               'sha256': digest[7:], 'size': asset['size']})
        if key != 'mcp':
            url = f'https://codeload.github.com/{repo}/zip/{commit}'
            cache.mkdir(parents=True, exist_ok=True)
            tmp = None
            try:
                with request(url) as response, tempfile.NamedTemporaryFile(dir=cache, delete=False) as stream:
                    tmp = Path(stream.name)
                    shutil.copyfileobj(response, stream)
                digest = sha256(tmp)
                size = tmp.stat().st_size
                os.replace(tmp, cache / digest)
            finally:
                if tmp:
                    tmp.unlink(missing_ok=True)
            assets.append({'name': repo.split('/')[1] + '.zip', 'url': url, 'sha256': digest, 'size': size})
        components[key] = {'repository': repo, 'tag': tag, 'commit': commit,
                           'release_url': release['html_url'], 'artifacts': assets}
    lock = {'schema_version': 1, 'platform': 'windows-x64', 'components': components, 'skill_groups': groups}
    validate_lock(lock)
    return lock
