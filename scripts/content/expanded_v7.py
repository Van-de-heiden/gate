"""Source-led expansion. Each entry is a standalone case, not a duration quota."""
from copy import deepcopy
from curated_v6 import catalog as previous_catalog
from pathlib import Path
import json

GROUPS = {
'history': ('case.press', 'Geschichte an Wendepunkten', 'Erfindungen, Macht und überraschende Spuren der Vergangenheit.'),
'industries': ('case.chip', 'Wie Technik wirklich funktioniert', 'Von winzigen Schaltern bis zu weltweiten Produktionsketten.'),
'health': ('case.sleep', 'Der Körper hinter dem Alltag', 'Schlaf, Sinne und die Mechanismen, die du täglich erlebst.'),
'learn': ('case.recall', 'Lernen und Gedächtnis', 'Warum Vertrautheit täuscht und wie Verständnis entsteht.'),
'data': ('case.rates', 'Was Zahlen verraten', 'Vergleiche, Experimente und die Fragen hinter einer Statistik.'),
'business': ('case.cash', 'Unternehmen von innen', 'Entscheidungen zwischen Kunden, Kosten und knappen Ressourcen.'),
'philosophy': ('case.stoic', 'Gedanken mit Konsequenzen', 'Philosophische Streitfragen an konkreten Entscheidungen prüfen.'),
'think': ('case.images', 'Urteile auf dem Prüfstand', 'Bilder, Argumente und die unsichtbaren Lücken einer guten Geschichte.'),
'earth': ('case.heat', 'Ein Planet in Bewegung', 'Wasser, Gestein, Luft und Energie als zusammenhängende Vorgänge.'),
'digital': ('case.phishing', 'Die unsichtbare digitale Welt', 'Verstehen, was zwischen einem Klick und seiner Wirkung passiert.'),
}

def catalog():
    c = deepcopy(previous_catalog())
    c['version'] = 7
    for p in c['paths']:
        p['title'] = GROUPS[p['id']][1]
        p['subtitle'] = GROUPS[p['id']][2]
    for t in c['topics']:
        _, t['title'], t['hook'] = GROUPS[t['pathID']]
        t['format'] = 'Entdeckungsreihe'
    for path, entries in json.loads(Path(__file__).with_name('chapters_v7.json').read_text()).items():
        for entry in entries:
            slug, title, headings, paragraphs, source, question, takeaway = entry
            identifier = 'discovery.' + path + '.' + slug
            prompt, options, explanation = question
            q = dict(id=identifier+'.v7.q1', prompt=prompt, options=options,
                     correctIndex=0, explanation=explanation, format='singleChoice')
            cards = [dict(title=h, text=p, kind='scene' if i==0 else 'evidence')
                     for i,(h,p) in enumerate(zip(headings,paragraphs))]
            cards.append(dict(title='Dein Urteil', text='Entscheide am neuen Fall. Diese Aufgabe zählt zum Ergebnis.',
                              kind='decision', probe=deepcopy(q)))
            c['lessons'].append(dict(id=identifier,pathID=path,
                order=1+sum(l['pathID']==path for l in c['lessons']),
                topicID=GROUPS[path][0],topicOrder=1+sum(l['pathID']==path for l in c['lessons']),
                title=title,objective=takeaway,cards=cards,questions=[q],takeaway=takeaway,
                reflection='',source=dict(title=source[0],url=source[1])))
    return c
