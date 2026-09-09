"""Static checks only. Swift tests and an Xcode build are separate checks."""
import json
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / "Gate/curriculum.json").read_text())
assert len(catalog["paths"]) == 8
assert len(catalog["lessons"]) == 24
questions = [q for lesson in catalog["lessons"] for q in lesson["questions"]]
assert len(questions) == 96 and len({q["id"] for q in questions}) == 96
for path in catalog["paths"]:
    lessons = [l for l in catalog["lessons"] if l["pathID"] == path["id"]]
    assert sorted(l["order"] for l in lessons) == [1, 2, 3]
for lesson in catalog["lessons"]:
    assert len(lesson["cards"]) >= 2
    assert lesson["source"]["url"].startswith("https://")
    assert lesson["reflection"] and lesson["takeaway"]
    visual = lesson["visual"]
    if visual["kind"] == "bars":
        assert len(visual["labels"]) == len(visual["values"])
        assert all(v >= 0 for v in visual["values"])
    for q in lesson["questions"]:
        assert len(q["options"]) >= 3
        assert len(set(q["options"])) == len(q["options"])
        assert 0 <= q["correctIndex"] < len(q["options"])
        assert q["explanation"]
    if lesson.get("photo"):
        assert lesson["photo"]["url"].startswith("https://svs.gsfc.nasa.gov/")
        assert lesson["photo"]["credit"] and lesson["photo"]["sourceURL"]

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
assert len(identifiers) == 10
assert all(i == "ch.mauruspichler.gate" or i.startswith("ch.mauruspichler.gate.") for i in identifiers)
assert "Gate/Info.plist" in project and "GateWidgetExtension" in project
assert "IPHONEOS_DEPLOYMENT_TARGET = 16.0" not in project
assert "GateConstants" not in "\n".join(p.read_text() for p in ROOT.rglob("*.swift"))
assert "GateStorage" not in "\n".join(p.read_text() for p in ROOT.rglob("*.swift"))
ET.parse(ROOT / "Gate.xcodeproj/xcshareddata/xcschemes/Gate.xcscheme")
print("PASS: 8 paths, 24 lessons, 96 unique questions; plist, target ID and scheme checks.")
