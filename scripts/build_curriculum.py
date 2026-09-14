"""Build only the curated edition; older authoring files remain an archive."""
from pathlib import Path
import json, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/content'))
from curated_v6 import catalog, REVIEW
c = catalog()
(ROOT / 'Gate/curriculum.json').write_text(json.dumps(c, ensure_ascii=False, indent=2) + '\n')
(ROOT / 'scripts/content/review_v6.json').write_text(json.dumps(REVIEW, ensure_ascii=False, indent=2) + '\n')
media = [(l, card['media']) for l in c['lessons'] for card in l['cards'] if card.get('media')]
lines = ['# Medien und Originalquellen · Gate 0.6', '',
 'Jedes aktive Kapitel enthält eine veröffentlichte Abbildung und eine konkrete Beobachtungsaufgabe. Keine generierten Lernbilder. Recherche: 14. September 2026. Abbildungen bleiben unbeschnitten; deutsche Bildbeschreibungen, Quellen, Urheber und Lizenzen sind in der App erreichbar. HTTPS-Abruf beim ersten Öffnen, danach lokaler Cache. Bei fehlendem Netz steht eine Bildbeschreibung bereit; die Quelle kann später erneut geladen werden.', '',
 '| Kapitel | Abbildung / Quelle | Urheber | Nutzung | Fachquelle |', '| --- | --- | --- | --- | --- |']
for l,m in media:
 lines.append(f"| {l['title']} | [Original]({m['sourceURL']}) · [Bilddatei]({m['url']}) | {m['credit']} | [{m['license']}]({m['licenseURL']}) | [{l['source']['title']}]({l['source']['url']}) |")
lines += ['', 'Weitere Fachquelle im Phishing-Kapitel: [Mozilla · Verbindungsverschlüsselung und Website-Identität](https://support.mozilla.org/en-US/kb/how-do-i-tell-if-my-connection-is-secure).']
(ROOT/'docs/MEDIA_SOURCES.md').write_text('\n'.join(lines)+'\n')
print(f"Curated v{c['version']}: {len(c['topics'])} topics, {len(c['lessons'])} chapters, {sum(len(l['questions']) for l in c['lessons'])} questions, {len(media)} published images.")
