import base64
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_release import make_feeds, SPARKLE, version_from_pubspec
from publish_release import validate_artifact, SafeRedirect
import urllib.request


class ReleaseTests(unittest.TestCase):
    def test_feed_escapes_notes_and_uses_exact_version_asset(self):
        with tempfile.TemporaryDirectory() as tmp:
            installer = Path(tmp) / 'MountainFairytale-1.2.3-windows-x64-Setup.exe'
            installer.write_bytes(b'test executable')
            xml, metadata = make_feeds('1.2.3', 42, base64.b64encode(bytes(64)).decode(),
                                       installer, 'Fix <one> & another', 'a' * 40)
            root = ET.fromstring(xml)
            enclosure = root.find('channel/item/enclosure')
            self.assertEqual(enclosure.attrib[f'{{{SPARKLE}}}version'], '1.2.3.42')
            self.assertTrue(enclosure.attrib['url'].endswith('/v1.2.3/' + installer.name))
            self.assertEqual(root.findtext('channel/item/description'), 'Fix <one> & another')
            self.assertEqual(metadata['commit'], 'a' * 40)

    def test_rejects_invalid_signature_or_build(self):
        for build, signature in [(0, 'invalid'), (65536, 'invalid'), (1, 'AAAA')]:
            with self.assertRaises(ValueError):
                make_feeds('1.0.0', build, signature, Path('unused'), '', 'a' * 40)

    def test_windows_version_limit_and_stable_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'pubspec.yaml'
            for version in ['1.0.0-beta+1', '65536.0.0+1', '1.0.0']:
                path.write_text(f'version: {version}\n')
                with self.assertRaises(ValueError):
                    version_from_pubspec(path)

    def test_incomplete_artifact_cannot_be_published(self):
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            validate_artifact({}, 'v1.0.0', 'a' * 40, Path('tool'), Path('.'), 'key')

    def test_publisher_checks_signature_and_rejects_modified_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            installer = directory / 'MountainFairytale-1.2.3-windows-x64-Setup.exe'
            installer.write_bytes(b'test executable')
            xml, metadata = make_feeds('1.2.3', 42, base64.b64encode(bytes(64)).decode(),
                                       installer, 'Notes', 'a' * 40)
            files = {installer.name: installer.read_bytes(), 'appcast.xml': xml,
                     'update.json': json.dumps(metadata).encode()}
            files['SHA256SUMS'] = ''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n'
                                         for name, data in files.items()).encode()
            with patch('publish_release.subprocess.run') as verify:
                verify.return_value.returncode = 0
                self.assertEqual(validate_artifact(files, 'v1.2.3', 'a' * 40,
                    Path('tool'), directory, 'public'), metadata)
                self.assertEqual(verify.call_count, 1)
                verify.return_value.returncode = 1
                with self.assertRaisesRegex(ValueError, 'signature invalid'):
                    validate_artifact(files, 'v1.2.3', 'a' * 40, Path('tool'), directory, 'wrong-key')
            files[installer.name] += b'tampered'
            with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                validate_artifact(files, 'v1.2.3', 'a' * 40, Path('tool'), directory, 'public')

    def test_redirect_does_not_leak_token(self):
        request = urllib.request.Request('https://api.github.com/artifact', headers={'Authorization': 'Bearer secret'})
        redirected = SafeRedirect().redirect_request(request, None, 302, '', {}, 'https://blob.example/artifact.zip')
        self.assertIsNone(redirected.get_header('Authorization'))


if __name__ == '__main__':
    unittest.main()
