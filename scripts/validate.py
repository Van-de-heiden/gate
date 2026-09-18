"""Static checks only. Swift tests and an Xcode build are separate checks."""
import json
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / "Gate/curriculum.json").read_text())
assert catalog['version'] == 8
assert len(catalog['paths']) == 10
assert len(catalog['lessons']) == 50
assert len(catalog['topics']) == 10
questions = [q for l in catalog['lessons'] for q in l['questions']]
assert len(questions) == len({q['id'] for q in questions}) == 300
assert {len(l['questions']) for l in catalog['lessons']} == {6}
assert {q.get('format', 'singleChoice') for q in questions} == {'singleChoice', 'ordering', 'matching', 'numeric', 'recall'}
media = []
for path in catalog['paths']:
    lessons = [l for l in catalog['lessons'] if l['pathID'] == path['id']]
    assert sorted(l['order'] for l in lessons) == list(range(1, len(lessons) + 1))
for topic in catalog['topics']:
    chapters = [l for l in catalog['lessons'] if l.get('topicID') == topic['id']]
    assert [l['topicOrder'] for l in chapters] == list(range(1, len(chapters) + 1))
    assert all(l['pathID'] == topic['pathID'] for l in chapters)
for lesson in catalog['lessons']:
    assert lesson['source']['url'].startswith('https://')
    assert len(lesson['cards']) >= 3
    assert not any(c.get('probe') for c in lesson['cards']), 'Practice must not leak graded answers'
    assert any(c.get('reveal') for c in lesson['cards']), 'Each chapter needs a worked example'
    words = sum(len((c['text']+' '+c.get('reveal','')).split()) for c in lesson['cards'])
    assert words >= 180, (lesson['id'], 'Too little explanation', words)
    families = {q['skillID'] for q in lesson['questions']}
    assert len(families) == 3
    assert all(sum(q['skillID'] == skill for q in lesson['questions']) == 2 for skill in families)
    assert any(all(q['format'] != 'singleChoice' for q in lesson['questions'] if q['skillID'] == skill) for skill in families)
    assert lesson['cards'][0]['kind'] == 'scene'
    for card in lesson['cards']:
        assert card['title'].strip() and card['text'].strip()
        assert not card.get('image'), 'No synthetic teaching photos'
        if card.get('media'):
            item = card['media']; media.append(item)
            assert all(item.get(key) for key in ['alt','caption','credit','license','licenseURL','url','sourceURL'])
            assert all(item[key].startswith('https://') for key in ['url','sourceURL','licenseURL'])
    for q in lesson['questions']:
        assert q['id'].startswith(lesson['id'] + '.v8.q')
        assert q['prompt'] and q['explanation']
        options = q['options']; assert len(set(options)) == len(options)
        kind = q.get('format', 'singleChoice')
        if kind == 'singleChoice': assert len(options) >= 2 and 0 <= q['correctIndex'] < len(options)
        elif kind == 'multipleChoice': assert 0 < len(q['correctIndices']) < len(options) and set(q['correctIndices']) <= set(range(len(options)))
        elif kind == 'ordering': assert sorted(q['correctOrder']) == list(range(len(options)))
        elif kind == 'numeric': assert isinstance(q['numberAnswer'], (int,float)) and q['tolerance'] >= 0
        elif kind == 'recall': assert q['acceptedAnswers'] and all(a.strip() for a in q['acceptedAnswers'])
        elif kind == 'matching': assert len(q['pairs']) == len(options) >= 3
assert len({m['url'] for m in media}) >= 10
assert all(len([l for l in catalog['lessons'] if l['topicID'] == t['id']]) == 5 for t in catalog['topics'])
reference = json.loads((ROOT/'Gate/reference-curriculum.json').read_text())
assert reference['version'] == 7 and len(reference['lessons']) == 100
assert len({c['media']['url'] for l in reference['lessons'] for c in l['cards'] if c.get('media')}) == 15
assert (ROOT / 'Gate/Assets.xcassets/AppIcon.appiconset/GateIcon.png').is_file()

for file in list(ROOT.rglob("*.plist")) + list(ROOT.rglob("*.entitlements")):
    with file.open("rb") as stream:
        value = plistlib.load(stream)
    if file.name == "Info.plist" and file.parent.name.endswith("Extension"):
        assert value["CFBundleIdentifier"] == "$(PRODUCT_BUNDLE_IDENTIFIER)", file
        assert value["CFBundleExecutable"] == "$(EXECUTABLE_NAME)", file
        assert "NSExtensionPointIdentifier" in value["NSExtension"], file

project = (ROOT / "Gate.xcodeproj/project.pbxproj").read_text()
definitions = re.findall(r"^\s*([A-F0-9]{24})\s*(?:/\*.*?\*/)?\s*=\s*\{", project, re.M)
# TargetAttributes repeat IDs as metadata, not object definitions.
objects = project.split("/* Begin PBXProject section */")[0] + project.split("/* End PBXProject section */")[1]
refs = set(re.findall(r"\b[A-F0-9]{24}\b", project))
assert refs <= set(definitions), f"Unknown IDs: {refs - set(definitions)}"
identifiers = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", project)
assert len(identifiers) == 12
assert all(i == "ch.mauruspichler.gate" or i.startswith("ch.mauruspichler.gate.") for i in identifiers)
assert "Gate/Info.plist" in project and "GateWidgetExtension" in project
assert identifiers.count("ch.mauruspichler.gate.report") == 2
report_plist = plistlib.loads((ROOT / "GateReportExtension/Info.plist").read_bytes())
assert report_plist["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.deviceactivityui.report-extension"
report_entitlements = plistlib.loads((ROOT / "GateReportExtension/GateReportExtension.entitlements").read_bytes())
assert report_entitlements == {"com.apple.developer.family-controls": True}
report_target = re.search(r"C50000000000000000000001 /\* GateReportExtension \*/ = \{(.*?)\n\s*\};", project, re.S).group(1)
assert "C20000000000000000000001, C20000000000000000000002" in report_target
assert "B20000000000000000000002" not in report_target  # No shared state/storage in the private report.
assert "IPHONEOS_DEPLOYMENT_TARGET = 16.0" not in project
assert "GateConstants" not in "\n".join(p.read_text() for p in ROOT.rglob("*.swift"))
assert "GateStorage" not in "\n".join(p.read_text() for p in ROOT.rglob("*.swift"))
ET.parse(ROOT / "Gate.xcodeproj/xcshareddata/xcschemes/Gate.xcscheme")
print(f"PASS: 50 focused chapters; {len(questions)} assessment variants; {len(media)} source-image placements; 100 historical chapters and 15 original images retained; project/plist/scheme checks.")
