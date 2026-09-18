"""Focused courses. The previous edition remains a separate, read-only library."""
from deep_authoring import assemble
from expanded_v7 import catalog as previous_catalog
from deep_history import COURSE as history
from deep_industries import COURSE as industries
from deep_health import COURSE as health
from deep_learn import COURSE as learn
from deep_data import COURSE as data
from deep_business import COURSE as business
from deep_philosophy import COURSE as philosophy
from deep_think import COURSE as think
from deep_earth import COURSE as earth
from deep_digital import COURSE as digital

def catalog():
    result = assemble([history, industries, health, learn, data, business,
                       philosophy, think, earth, digital], previous_catalog())
    for lesson in result['lessons']:
        if lesson['pathID'] == 'digital':
            lesson['additionalSources'] = [dict(title='Mozilla · Connection security and site identity',
                url='https://support.mozilla.org/en-US/kb/how-do-i-tell-if-my-connection-is-secure')]
        if lesson['pathID'] == 'learn':
            lesson['additionalSources'] = [dict(title='IES · Organizing Instruction and Study to Improve Student Learning',
                url='https://ies.ed.gov/ncee/wwc/PracticeGuide/1')]
    return result
