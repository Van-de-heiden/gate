"""Authored lesson constructors. No network/LLM generation at runtime."""
def sc(prompt, good, bad1, bad2, explanation):
    return dict(prompt=prompt, format='singleChoice', options=[good,bad1,bad2], correctIndex=0, explanation=explanation)
def multi(prompt, options, correct, explanation):
    return dict(prompt=prompt, format='multipleChoice', options=options, correctIndex=0, correctIndices=correct, explanation=explanation)
def order(prompt, steps, explanation):
    return dict(prompt=prompt, format='ordering', options=steps, correctIndex=0, correctOrder=list(range(len(steps))), explanation=explanation)
def number(prompt, answer, unit, explanation, tolerance=0.01):
    return dict(prompt=prompt, format='numeric', options=[], correctIndex=0, numberAnswer=answer, tolerance=tolerance, unit=unit, explanation=explanation)
def recall(prompt, answers, explanation, cloze=False):
    return dict(prompt=prompt, format='cloze' if cloze else 'recall', options=[], correctIndex=0, acceptedAnswers=answers.split('|'), explanation=explanation)
def L(path, slug, title, objective, theory, case, limit, mission, pairs, decision, exercise, retrieval, transfer, source=None):
    terms=[dict(left=a,right=b) for a,b in pairs]
    questions=[decision,dict(prompt='Ordne die Begriffe ihrer Bedeutung in diesem Kapitel zu.',format='matching',options=[p['left'] for p in terms],correctIndex=0,pairs=terms,explanation='; '.join(p['left']+': '+p['right'] for p in terms)+'.'),retrieval,exercise,transfer]
    for i,q in enumerate(questions): q['id']=f'{path}.{slug}.q{i+1}'
    return dict(id=f'{path}.{slug}',pathID=path,order=0,title=title,objective=objective,
        cards=[dict(title='Der Gedanke',text=theory),dict(title='Ein Fall aus dem Leben',text=case),dict(title='Die entscheidende Grenze',text=limit),dict(title='Begriffe im Zusammenhang',text='\n\n'.join(p['left']+' — '+p['right'] for p in terms))],
        visual=dict(kind='compare',title='Drei Anker',labels=[p['left']+' · '+p['right'] for p in terms],values=None,caption='Nutze die Begriffe, um den Fall selbst zu erklären.'),
        photo=None,reflection='Erkläre den Fall ohne Vorlage. Welche Entscheidung würdest du treffen, und welche Information könnte deine Meinung ändern?',
        mission=mission,takeaway=objective,source=source,questions=questions)
