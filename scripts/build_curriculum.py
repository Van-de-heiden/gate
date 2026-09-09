"""Merge authored additions without removing v0.2 chapters or changing their IDs."""
from pathlib import Path
import json,sys,importlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/content'))
from enrichment import UPDATES
path=ROOT/'Gate/curriculum.json'
c=json.loads(path.read_text())
original_ids=set(UPDATES)
assert original_ids <= {l['id'] for l in c['lessons']}
base=[l for l in c['lessons'] if l['id'] in original_ids]
pathmeta={
'learn':('Denken & Wissen','learning'),'think':('Denken & Wissen','learning'),'data':('Denken & Wissen','money'),
'digital':('Alltag & Entwicklung','digital'),'economy':('Geld & Wirtschaft','money'),'science':('Natur & Technik','science'),
'earth':('Natur & Technik','science'),'history':('Mensch & Gesellschaft','history')}
paths=[]
for p in c['paths']:
 if p['id'] in pathmeta:
  p['category'],p['artwork']=pathmeta[p['id']];paths.append(p)
for l in base:
 text,mission,q1,q2=UPDATES[l['id']]
 l['cards']=[x for x in l['cards'] if x['title']!='Im Alltag anwenden']+[dict(title='Im Alltag anwenden',text=text)]
 l['mission']=mission
 l['artwork']=pathmeta[l['pathID']][1]
 # Preserve all four original questions, then attach two format extensions.
 l['questions']=[q for q in l['questions'] if not q['id'].endswith(('.extra1','.extra2'))]
 for i,q in enumerate([q1,q2],1):
  q['id']=l['id']+f'.extra{i}';l['questions'].append(q)
lessons=base[:]
for module in ['foundations','data_digital','economy_science','earth_history','philosophy','business','money','industries','health','development','communication','civics']:
 m=importlib.import_module(module)
 if hasattr(m,'PATH'): paths.append(m.PATH)
 for l in m.LESSONS:
  l['order']=1+max([x['order'] for x in lessons if x['pathID']==l['pathID']],default=0)
  meta=next(p for p in paths if p['id']==l['pathID']);l['artwork']=meta['artwork']
  assert l['source']
  lessons.append(l)
for i,p in enumerate(paths,1):p['number']=f'{i:02d}'
# More precise further-reading destinations for the introductory money/civics chapters.
sources={
'money.budget':('Investor.gov · Save for a Rainy Day','https://www.investor.gov/introduction-investing/investing-basics/save-and-invest/save-rainy-day'),
'money.diversify':('Investor.gov · Asset Allocation and Diversification','https://www.investor.gov/introduction-investing/getting-started/asset-allocation'),
'money.costs':('Investor.gov · Understanding Fees','https://www.investor.gov/introduction-investing/getting-started/understanding-fees'),
'civics.federalism':('ch.ch · Swiss Federalism','https://www.ch.ch/en/political-system/operation-and-organisation-of-switzerland/federalism/'),
}
for l in lessons:
 if l['id'] in sources: l['source']=dict(zip(['title','url'],sources[l['id']]))
 # Replace a generic term list by an exact visual comparison where the numbers teach the concept.
 visuals={
 'money.compound':(['Start','Nach Jahr 1','Nach Jahr 2'],[1000,1050,1102.5],'Modell: 5 % jährlich, ohne Kosten und Steuern; keine Prognose.'),
 'industries.software':(['100 Kunden','90 Kunden'],[3000,2700],'Monatlicher Umsatz bei konstant 30 CHF pro Kunde.'),
 'business.cash':(['Heute vorhanden','Morgen fällig'],[1000,3000],'Franken im beschriebenen Beispiel; die offene Forderung ist noch kein Kontoguthaben.'),
 'data.charts':(['Vorher','Nachher'],[98,100],'Bewusst mit Nullbasis: Die absolute Veränderung beträgt 2 Einheiten.'),
 'earth.stocks':(['Zufluss','Abfluss','Nettozunahme'],[4,3,1],'Liter pro Minute. Der Bestand wächst um 1 Liter pro Minute.'),
 }
 if l['id'] in visuals:
  labels,values,caption=visuals[l['id']];l['visual']=dict(kind='bars',title='Das Beispiel im Bild',labels=labels,values=values,caption=caption)
assert len(paths)==16 and len(lessons)==96
assert all(len([l for l in lessons if l['pathID']==p['id']])==6 for p in paths)
path.write_text(json.dumps(dict(version=3,paths=paths,lessons=lessons),ensure_ascii=False,indent=2)+'\n')
print(f'{len(paths)} paths, {len(lessons)} chapters, {sum(len(l["questions"]) for l in lessons)} questions; all original IDs retained.')
