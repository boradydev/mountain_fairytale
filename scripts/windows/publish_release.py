"""Manual publisher: only a successful tag build's verified artifact."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

from prepare_release import REPOSITORY, SPARKLE, INSTALLER_ARGUMENTS


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        redirect = super().redirect_request(req, fp, code, msg, headers, newurl)
        # Artifact download redirects to blob storage must not receive a token.
        redirect.remove_header('Authorization')
        return redirect


def request(path, method='GET', body=None, binary=False, content_type='application/json'):
    url = path if path.startswith('https://') else f'https://api.github.com/repos/{REPOSITORY}{path}'
    if not url.startswith(('https://api.github.com/', 'https://uploads.github.com/')):
        raise ValueError('Unexpected authenticated API host')
    data = body if isinstance(body, bytes) else json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        'Authorization': f'Bearer {os.environ["GH_TOKEN"]}',
        'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': content_type, 'User-Agent': 'MountainFairytale-release',
    })
    with urllib.request.build_opener(SafeRedirect()).open(req, timeout=120) as response:
        data = response.read()
    return data if binary else json.loads(data)


def validate_artifact(files, tag, commit, tool, directory, public_key):
    version = tag.removeprefix('v')
    installer_name = f'MountainFairytale-{version}-windows-x64-Setup.exe'
    expected = {installer_name, 'appcast.xml', 'update.json', 'SHA256SUMS'}
    if set(files) != expected:
        raise ValueError('Unexpected or incomplete artifact files')
    sums = {}
    for line in files['SHA256SUMS'].decode('ascii').splitlines():
        digest, name = line.split('  ', 1)
        if name in sums or name not in expected - {'SHA256SUMS'}:
            raise ValueError('Unexpected checksum entry')
        sums[name] = digest
    if set(sums) != expected - {'SHA256SUMS'} or any(
        hashlib.sha256(files[name]).hexdigest() != digest for name, digest in sums.items()
    ):
        raise ValueError('Artifact checksum mismatch')
    metadata = json.loads(files['update.json'])
    if metadata['version'] != version or metadata['commit'] != commit or metadata['schemaVersion'] != 1:
        raise ValueError('Artifact metadata does not match tag commit')
    enclosure = ET.fromstring(files['appcast.xml']).find('channel/item/enclosure')
    if enclosure is None or enclosure.attrib.get('url') != f'https://github.com/{REPOSITORY}/releases/download/{tag}/{installer_name}':
        raise ValueError('Unexpected installer URL')
    if enclosure.attrib.get(f'{{{SPARKLE}}}version') != f'{version}.{metadata["buildNumber"]}' or int(enclosure.attrib['length']) != len(files[installer_name]):
        raise ValueError('Appcast version or file length mismatch')
    if enclosure.attrib.get(f'{{{SPARKLE}}}installerArguments') != INSTALLER_ARGUMENTS:
        raise ValueError('Unexpected installer arguments')
    installer = directory / installer_name
    installer.write_bytes(files[installer_name])
    verified = subprocess.run([str(tool), 'verify', '-p', public_key, '-s',
                               enclosure.attrib[f'{{{SPARKLE}}}edSignature'], str(installer)], capture_output=True)
    if verified.returncode:
        raise ValueError('Installer signature invalid or public key changed')
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tag', required=True)
    parser.add_argument('--tool', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'v\d+\.\d+\.\d+', args.tag):
        raise ValueError('Expected stable vX.Y.Z tag')
    commit = subprocess.check_output(['git', 'rev-parse', f'{args.tag}^{{commit}}'], text=True).strip()
    subprocess.run(['git', 'merge-base', '--is-ancestor', commit, 'origin/master'], check=True)
    runs = request(f'/actions/workflows/flutter-build.yml/runs?event=push&head_sha={commit}&per_page=100')['workflow_runs']
    candidates = [run for run in runs if run['head_branch'] == args.tag and run['conclusion'] == 'success']
    if not candidates:
        raise ValueError('No successful tag CI build found; wait for its checks')
    run = max(candidates, key=lambda item: item['id'])
    artifacts = request(f'/actions/runs/{run["id"]}/artifacts')['artifacts']
    artifact = next((item for item in artifacts if item['name'] == f'windows-release-{args.tag}' and not item['expired']), None)
    if not artifact:
        raise ValueError('Signed release artifact missing or expired; prepare a new version')
    raw = request(artifact['archive_download_url'], binary=True)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate artifact entries')
        files = {name: archive.read(name) for name in names}
    with tempfile.TemporaryDirectory(prefix='mf-publish-') as tmp:
        metadata = validate_artifact(files, args.tag, commit, args.tool, Path(tmp), os.environ['UPDATE_PUBLIC_KEY'])
    try:
        latest = request('/releases/latest')
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        latest = None
    version_tuple = tuple(map(int, metadata['version'].split('.')))
    if latest and re.fullmatch(r'v\d+\.\d+\.\d+', latest['tag_name']):
        if version_tuple <= tuple(map(int, latest['tag_name'][1:].split('.'))):
            raise ValueError('Publication must increase the public version; never overwrite a release')
    try:
        existing = request(f'/releases/tags/{args.tag}')
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        existing = None
    if existing:
        raise ValueError('Release already exists. Inspect an interrupted draft manually; do not overwrite it')
    release = request('/releases', method='POST', body={
        'tag_name': args.tag, 'target_commitish': commit, 'name': f'Mountain Fairytale {args.tag}',
        'body': metadata['description'], 'draft': True, 'prerelease': False,
    })
    # Clients cannot see a half-uploaded installer: publish the complete draft.
    upload = release['upload_url'].split('{', 1)[0]
    for name, data in files.items():
        request(f'{upload}?name={name}', method='POST', body=data, content_type='application/octet-stream')
    request(f'/releases/{release["id"]}', method='PATCH', body={'draft': False, 'make_latest': 'true'})
    print(f'Published {args.tag}: {release["html_url"]}')


if __name__ == '__main__':
    main()
