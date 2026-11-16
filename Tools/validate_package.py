"""Static macOS package checks, using standard-library Python and native tools.
Run: python3 Tools/validate_package.py. Does not type-check or run XCTest.
"""
from pathlib import Path
import json
import plistlib
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
swift = sorted((root / 'CreativeMoments').glob('*.swift'))
tests = sorted((root / 'CreativeMomentsTests').glob('*.swift'))
assert len(swift) == 6 and tests, 'Missing app source or tests'
subprocess.run(['xcrun', 'swiftc', '-frontend', '-parse', *map(str, swift + tests)], check=True)
project = json.loads(subprocess.check_output([
    'plutil', '-convert', 'json', '-o', '-', str(root / 'CreativeMoments.xcodeproj/project.pbxproj')
]))
objects = project['objects']
assert project['rootObject'] in objects
for key, value in objects.items():
    for ref in ['fileRef', 'buildConfigurationList', 'productReference', 'mainGroup',
                'productRefGroup', 'containerPortal', 'remoteGlobalIDString', 'target', 'targetProxy']:
        if ref in value:
            assert value[ref] in objects, (key, ref)
    for ref in ['children', 'files', 'buildConfigurations', 'buildPhases', 'dependencies', 'targets']:
        for item in value.get(ref, []):
            assert item in objects, (key, ref, item)
    if value.get('isa') == 'PBXFileReference' and value.get('sourceTree') == '<group>':
        assert (root / value['path']).exists(), value['path']
resources = {objects[objects[item]['fileRef']]['path']
             for value in objects.values() if value.get('isa') == 'PBXResourcesBuildPhase'
             for item in value['files']}
for month in range(1, 13):
    path = f'CreativeMoments/Resources/Scenes/scene-{month:02d}.png'
    assert path in resources, path
    output = subprocess.check_output(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(root / path)], text=True)
    dimensions = [int(line.split(':')[1]) for line in output.splitlines() if 'pixel' in line]
    assert len(dimensions) == 2 and min(dimensions) >= 1000, path
icon = root / 'CreativeMoments/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
output = subprocess.check_output(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', str(icon)], text=True)
assert 'pixelWidth: 1024' in output and 'pixelHeight: 1024' in output and 'hasAlpha: no' in output
for file in ['CreativeMoments/Info.plist', 'CreativeMoments/PrivacyInfo.xcprivacy']:
    plistlib.loads((root / file).read_bytes())
ET.parse(root / 'CreativeMoments.xcodeproj/xcshareddata/xcschemes/CreativeMoments.xcscheme')
for file in (root / 'CreativeMoments/Assets.xcassets').rglob('Contents.json'):
    json.loads(file.read_text())
print(f'PASS: {len(swift)} app sources, {len(tests)} test files, project references, 12 scenes, icon, plists and scheme.')
print('Swift syntax only. NOT RUN: iOS type checking, Xcode build, XCTest or runtime tests.')
