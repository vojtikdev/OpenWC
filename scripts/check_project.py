"""Check native project/resource wiring without pretending to compile Swift."""
from pathlib import Path
import hashlib
import json
import plistlib
import runpy
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
project = root / 'OpenWC.xcodeproj/project.pbxproj'
before = hashlib.sha256(project.read_bytes()).hexdigest()
model = runpy.run_path(str(root / 'make_project.py'))
assert hashlib.sha256(project.read_bytes()).hexdigest() == before, 'Generated project was out of date'
objects = model['objects']
source_ids = objects[model['sourcephase']]['files']
source_names = {objects[objects[ref]['fileRef']]['path'] for ref in source_ids}
assert source_names == {p.name for p in (root / 'OpenWC').glob('*.swift')}, 'Missing Swift source'
resource_ids = objects[model['resourcephase']]['files']
resource_paths = {objects[objects[ref]['fileRef']]['path'] for ref in resource_ids}
assert {'Legal/TERMS_OF_SERVICE.md', 'Legal/PRIVACY_POLICY.md', 'Legal/COPYRIGHT.md'} <= resource_paths
for path in resource_paths:
    assert (root / ('OpenWC/' + path if path == 'Assets.xcassets' else path)).exists(), path
for p in (root / 'OpenWC').rglob('*.json'):
    json.loads(p.read_text())
plistlib.loads((root / 'OpenWC/Info.plist').read_bytes())
ET.parse(root / 'OpenWC.xcodeproj/xcshareddata/xcschemes/OpenWC.xcscheme')
for configuration in model['projectconfigs']:
    value = objects[configuration]
    assert value['buildSettings']['ONLY_ACTIVE_ARCH'] == ('YES' if value['name'] == 'Debug' else 'NO')
assert objects[model['package']]['requirement'] == {'kind': 'exactVersion', 'version': '2.55.4'}
print('PASS: deterministic project, Swift source wiring, legal resources, plist, scheme, assets, architecture and SDK pin')
