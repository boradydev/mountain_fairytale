"""Validate version/tag, sign an installer, and generate the two release feeds."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

REPOSITORY = 'boradydev/mountain_fairytale'
SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
INSTALLER_ARGUMENTS = '/SILENT /SP- /NOICONS /NORESTART /UPDATE=1'


def version_from_pubspec(path=Path('pubspec.yaml')):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$', path.read_text(encoding='utf-8'), re.M)
    if not match or any(int(n) > 65535 for n in match[1].split('.')):
        raise ValueError('Expected stable Windows version x.y.z+build in pubspec.yaml')
    return match[1]


def make_feeds(version, build, signature, installer, description, commit):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not 1 <= build <= 65535:
        raise ValueError('Invalid release version or build number')
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Invalid Ed25519 signature')
    if not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise ValueError('Expected a full commit SHA')
    ET.register_namespace('sparkle', SPARKLE)
    rss = ET.Element('rss', version='2.0')
    channel = ET.SubElement(rss, 'channel')
    ET.SubElement(channel, 'title').text = 'Mountain Fairytale'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'Mountain Fairytale {version}'
    ET.SubElement(item, 'description').text = description
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/{REPOSITORY}/releases/download/v{version}/{installer.name}',
        'length': str(installer.stat().st_size), 'type': 'application/octet-stream',
        f'{{{SPARKLE}}}version': f'{version}.{build}',
        f'{{{SPARKLE}}}shortVersionString': version,
        f'{{{SPARKLE}}}os': 'windows-x64',
        f'{{{SPARKLE}}}edSignature': signature,
        f'{{{SPARKLE}}}installerArguments': INSTALLER_ARGUMENTS,
    })
    metadata = dict(schemaVersion=1, version=version, buildNumber=build,
                    description=description, commit=commit)
    return ET.tostring(rss, encoding='utf-8', xml_declaration=True), metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--validate-tag')
    parser.add_argument('--build', type=int, required=True)
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--tool', type=Path)
    parser.add_argument('--commit')
    args = parser.parse_args()
    version = version_from_pubspec()
    if not 1 <= args.build <= 65535:
        raise ValueError('Windows build number must be 1..65535; do not wrap it')
    if args.validate_tag and args.validate_tag != f'v{version}':
        raise ValueError('Tag must match pubspec.yaml')
    if args.directory is None:
        print(version)
        return
    installer = args.directory / f'MountainFairytale-{version}-windows-x64-Setup.exe'
    public_key = os.environ['UPDATE_PUBLIC_KEY'].strip()
    if len(base64.b64decode(public_key, validate=True)) != 32:
        raise ValueError('Expected a base64 Ed25519 public key')
    private_key = os.environ['UPDATE_PRIVATE_KEY'].strip()
    # Temp file is outside the artifact folder and always removed, including on
    # signing failure. Neither the key nor command output is written to logs.
    with tempfile.TemporaryDirectory(prefix='mf-sign-') as directory:
        key = Path(directory) / 'private.key'
        key.write_text(private_key, encoding='utf-8')
        result = subprocess.run([str(args.tool), 'sign', '-f', str(key), str(installer)],
                                capture_output=True, text=True)
        if result.returncode:
            raise ValueError('Installer signing failed; check the signing secret')
        signature = result.stdout.strip()
    result = subprocess.run([str(args.tool), 'verify', '-p', public_key, '-s', signature, str(installer)],
                            capture_output=True)
    if result.returncode:
        raise ValueError('Signature verification failed: public/private key mismatch')
    description = Path('release-notes.md').read_text(encoding='utf-8').strip()
    if not description or len(description) > 16000:
        raise ValueError('Release notes must contain 1..16000 characters')
    xml, metadata = make_feeds(version, args.build, signature, installer, description, args.commit)
    (args.directory / 'appcast.xml').write_bytes(xml)
    (args.directory / 'update.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    files = [installer, args.directory / 'appcast.xml', args.directory / 'update.json']
    (args.directory / 'SHA256SUMS').write_text(''.join(
        f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n' for file in files), encoding='ascii')


if __name__ == '__main__':
    main()
