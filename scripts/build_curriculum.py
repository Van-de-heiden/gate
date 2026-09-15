"""Build only the curated edition; older authoring files remain an archive."""
from pathlib import Path
import json, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/content'))
from expanded_v7 import catalog
c = catalog()
(ROOT / 'Gate/curriculum.json').write_text(json.dumps(c, ensure_ascii=False, indent=2) + '\n')

media = [(l, card['media']) for l in c['lessons'] for card in l['cards'] if card.get('media')]
lines = ['# Medien und Originalquellen · Gate 0.7', '',
 'Abbildungen werden gezielt eingesetzt; eine Pflichtabbildung pro Kapitel gibt es nicht. Die 15 bisherigen veröffentlichten Abbildungen bleiben erhalten. Keine generierten Lernbilder. Recherche: 15. September 2026. Abbildungen bleiben unbeschnitten; deutsche Bildbeschreibungen, Quellen, Urheber und Lizenzen sind in der App erreichbar. HTTPS-Abruf beim ersten Öffnen, danach lokaler Cache. Bei fehlendem Netz steht eine Bildbeschreibung bereit; die Quelle kann später erneut geladen werden.', '',
 '| Kapitel | Abbildung / Quelle | Urheber | Nutzung | Fachquelle |', '| --- | --- | --- | --- | --- |']
for l,m in media:
 lines.append(f"| {l['title']} | [Original]({m['sourceURL']}) · [Bilddatei]({m['url']}) | {m['credit']} | [{m['license']}]({m['licenseURL']}) | [{l['source']['title']}]({l['source']['url']}) |")
lines += ['', 'Weitere Fachquelle im Phishing-Kapitel: [Mozilla · Verbindungsverschlüsselung und Website-Identität](https://support.mozilla.org/en-US/kb/how-do-i-tell-if-my-connection-is-secure).']
(ROOT/'docs/MEDIA_SOURCES.md').write_text('\n'.join(lines)+'\n')
print(f"Curated v{c['version']}: {len(c['topics'])} topics, {len(c['lessons'])} chapters, {sum(len(l['questions']) for l in c['lessons'])} questions, {len(media)} published images.")

index = ['# Gate 0.7 · 100 eigenständige Kapitel', '', 'Jede Runde behandelt ein Kapitel. Der Katalog hat keine Mindestlesedauer und keine feste Fragenquote. Alle Beispiele ohne historische Zuschreibung sind didaktische Gedankenfälle. Quellen stehen am jeweiligen Kapitel.', '']
for topic in c['topics']:
 index += ['## '+topic['title'], '']
 for l in c['lessons']:
  if l['topicID'] == topic['id']:
   index.append(f"- **{l['title']}** — {l['objective']} [Fachquelle]({l['source']['url']})")
 index.append('')
(ROOT/'docs/CURRICULUM_V7.md').write_text('\n'.join(index)+'\n')
