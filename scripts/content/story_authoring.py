"""Small data constructors, not a prose template. Every stage is authored separately."""
from copy import deepcopy
from authoring import sc, multi, order, number, recall

def source(title, url):
    return dict(title=title, url=url)

def topic(slug, path, title, hook, format):
    return dict(id='case.'+slug, pathID=path, title=title, hook=hook, format=format)

def card(kind, title, text, *, image=None, alt=None, caption=None, reveal=None, probe=None, visual=None):
    result=dict(kind=kind, title=title, text=text)
    for key,value in dict(image='Scene-'+image if image else None, imageDescription=alt,
                          caption=caption, reveal=reveal, probe=probe, visual=visual).items():
        if value is not None: result[key]=value
    return result

def bars(title, labels, values, caption):
    return dict(kind='bars',title=title,labels=labels,values=values,caption=caption)

def chain(title, labels, caption):
    return dict(kind='flow',title=title,labels=labels,caption=caption)

def compare(title, labels, caption):
    return dict(kind='compare',title=title,labels=labels,caption=caption)

def matching(prompt, pairs, explanation):
    return dict(prompt=prompt,format='matching',options=[p[0] for p in pairs],correctIndex=0,
                pairs=[dict(left=a,right=b) for a,b in pairs],explanation=explanation)

def chapter(t, n, title, objective, cards, questions, takeaway, mission, src):
    identifier=t['id']+f'.{n}'
    cards=deepcopy(cards);questions=deepcopy(questions)
    assert len(questions)==5 and len(cards)>=3
    for i,q in enumerate(questions,1): q['id']=identifier+f'.q{i}'
    for i,c in enumerate(cards):
        if c.get('probe'): c['probe']['id']=identifier+f'.probe{i}'
    return dict(id=identifier,pathID=t['pathID'],topicID=t['id'],topicOrder=n,order=0,
                title=title,objective=objective,cards=cards,questions=questions,source=src,
                visual=compare('Gedanke zum Mitnehmen',[takeaway,mission],'Eigene Anwendung, kein zusätzliches Prüfungsthema.'),
                reflection=mission,mission=mission,takeaway=takeaway,photo=None)

ILLUSTRATION='KI-Szenenbild · illustrative Rekonstruktion, keine historische Quelle.'
FICTION='KI-Szenenbild · erfundener Lernfall, keine Aufnahme eines tatsächlichen Ereignisses.'
