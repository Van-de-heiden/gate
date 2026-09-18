"""Small authoring vocabulary; prose, cases and answers are editorial inputs.

Three objectives per chapter, with two authored assessment variants each.
Worked examples are deliberately NOT graded questions.
"""
from copy import deepcopy


def choice(prompt, correct, other1, other2, explanation):
    return dict(prompt=prompt, options=[correct, other1, other2], correctIndex=0,
                format='singleChoice', explanation=explanation)


def number(prompt, answer, unit, explanation, tolerance=0.01):
    return dict(prompt=prompt, options=[], correctIndex=0, format='numeric',
                numberAnswer=answer, unit=unit, tolerance=tolerance, explanation=explanation)


def recall(prompt, answers, explanation):
    return dict(prompt=prompt, options=[], correctIndex=0, format='recall',
                acceptedAnswers=answers, explanation=explanation)


def matching(prompt, pairs, explanation):
    return dict(prompt=prompt, options=[right for _, right in pairs], correctIndex=0,
                format='matching', pairs=[dict(left=a, right=b) for a, b in pairs],
                explanation=explanation)


def ordering(prompt, steps, explanation):
    return dict(prompt=prompt, options=steps, correctIndex=0, format='ordering',
                correctOrder=list(range(len(steps))), explanation=explanation)


def unit(title, objective, sections, exercise, solution, families, diagram=None):
    assert len(sections) >= 2 and len(families) == 3
    assert all(len(f) == 2 for f in families)
    return dict(title=title, objective=objective, sections=sections,
                exercise=exercise, solution=solution, families=families, diagram=diagram)


def course(path, slug, title, hook, source, units):
    assert len(units) == 5, slug
    return dict(path=path, slug=slug, title=title, hook=hook, source=source, units=units)


def assemble(courses, previous):
    topics, lessons = [], []
    for c in courses:
        topic_id = 'deep.' + c['slug']
        topics.append(dict(id=topic_id, pathID=c['path'], title=c['title'],
                           hook=c['hook'], format='Vertiefung in fünf Kapiteln'))
        prior = [l for l in previous['lessons'] if l['pathID'] == c['path']]
        media = [card['media'] for l in prior for card in l['cards'] if card.get('media')]
        for i, u in enumerate(c['units']):
            identifier = f'{topic_id}.{i+1}'
            questions = []
            for group, variants in enumerate(u['families']):
                for variant, original in enumerate(variants):
                    q = deepcopy(original)
                    q['id'] = f'{identifier}.v8.q{group+1}.{variant+1}'
                    q['skillID'] = f'{identifier}.skill{group+1}'
                    # Content correct indices are balanced too; UI also shuffles once.
                    if q['format'] == 'singleChoice':
                        shift = (i + group + variant) % len(q['options'])
                        q['options'] = q['options'][shift:] + q['options'][:shift]
                        q['correctIndex'] = (-shift) % len(q['options'])
                    questions.append(q)
            cards = [dict(title=h, text=t, kind='scene' if n==0 else 'explanation')
                     for n, (h, t) in enumerate(u['sections'])]
            # Reuse original illustrations only where their subject is taught.
            placements = {'history': {0: 0, 3: 1}, 'industries': {0: 0, 2: 1},
                          'learn': {3: 0}, 'data': {1: 0}, 'business': {2: 0},
                          'think': {0: 0}}
            media_index = placements.get(c['path'], {0: 0}).get(i)
            if media_index is not None and media_index < len(media):
                cards[1]['media'] = deepcopy(media[media_index])
            if u['diagram']:
                cards[1]['visual'] = u['diagram']
            cards.append(dict(title='Versuche es selbst', text=u['exercise'],
                              reveal=u['solution'], kind='workedExample'))
            lessons.append(dict(id=identifier, pathID=c['path'], order=i+1,
                topicID=topic_id, topicOrder=i+1, title=u['title'], objective=u['objective'],
                cards=cards, questions=questions, reflection=u['objective'],
                takeaway=u['objective'], source=dict(title=c['source'][0], url=c['source'][1])))
    return dict(version=8, paths=deepcopy(previous['paths']), topics=topics, lessons=lessons)
