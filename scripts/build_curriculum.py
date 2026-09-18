"""Deterministic content build; never rewrites historical authoring sources."""
from pathlib import Path
import json, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/content'))
from curated_v8 import catalog
from expanded_v7 import catalog as reference_catalog
c = catalog()
reference = reference_catalog()
for name, data in [('curriculum', c), ('reference-curriculum', reference)]:
    (ROOT / f'Gate/{name}.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

index = ['# Gate · Lernedition 8', '',
    '10 eng gefasste Kurse mit 50 aufeinander aufbauenden Kapiteln. Drei Lernziele je Kapitel, je zwei Prüfungsvarianten. Pro Runde wird genau eine Variante je Ziel gestellt; Lösungsbeispiele sind davon getrennt. Die 100 bisherigen Kurztexte bleiben in der Lesebibliothek, sind aber kein Freigabeweg mehr.', '',
    'Freigabe 5 / 10 / 15 / 20 / 30 Minuten → 1 / 2 / 3 / 4 / 5 zusammenhängende Kapitel. Zeitangaben sind Schätzungen aus tatsächlichem Lesestoff und Aufgaben, keine Wartesperren.', '',
    'Alle Werkstatt-, Produktions- und Rechenfälle ohne ausdrückliche historische Zuschreibung sind eigene didaktische Beispiele. Inhalte sind redaktionell bearbeitet, aber nicht unabhängig fachlich oder mit einer Lernerstudie validiert.', '']
for topic in c['topics']:
    index += ['## ' + topic['title'], '', topic['hook'], '']
    for lesson in [l for l in c['lessons'] if l['topicID'] == topic['id']]:
        words = sum(len((card['text']+' '+card.get('reveal','')).split()) for card in lesson['cards'])
        index.append(f"- **{lesson['title']}** — {lesson['objective']} ({words} Lesewörter; 3 Prüfungsaufgaben aus 6 Varianten.) [Fachquelle]({lesson['source']['url']})")
    index.append('')
(ROOT/'docs/CURRICULUM_V8.md').write_text('\n'.join(index)+'\n')
print(f"v{c['version']}: {len(c['topics'])} courses, {len(c['lessons'])} chapters, {sum(len(l['questions']) for l in c['lessons'])} assessment variants; {len(reference['lessons'])} reference chapters retained.")
