"""Human-selected published media. Sources and reuse terms checked 2026-09-14.

No generated assets. Keep diagrams uncropped; captions distinguish models, historical
depictions and measurements. Questions never require a network-loaded image.
"""
from copy import deepcopy

PD = ('Public Domain', 'https://creativecommons.org/publicdomain/mark/1.0/')
BY4 = ('CC BY 4.0', 'https://creativecommons.org/licenses/by/4.0/')
SA4 = ('CC BY-SA 4.0', 'https://creativecommons.org/licenses/by-sa/4.0/')
SA3 = ('CC BY-SA 3.0', 'https://creativecommons.org/licenses/by-sa/3.0/')
MEDIA = {}
def M(key, source, url, credit, terms, caption, alt):
    MEDIA[key] = dict(sourceURL=source, url=url, credit=credit, license=terms[0],
                      licenseURL=terms[1], caption=caption, alt=alt)

M('press', 'https://commons.wikimedia.org/wiki/File:Printer_in_1568-ce.png',
  'https://upload.wikimedia.org/wikipedia/commons/f/f8/Printer_in_1568-ce.png',
  'Jost Amman · Ständebuch, 1568', PD,
  'Eine Druckwerkstatt von 1568: Setzen, Einfärben und Drucken sind verschiedene Arbeitsschritte. Der Holzschnitt zeigt eine spätere Werkstatt, nicht Gutenbergs Betrieb um 1450.',
  'Holzschnitt einer Werkstatt: vorne Drucker an der Presse, dahinter Menschen beim Zusammenstellen der Druckformen.')
M('forgetting', 'https://commons.wikimedia.org/wiki/File:Ebbinghaus_curve.png',
  'https://upload.wikimedia.org/wikipedia/commons/8/81/Ebbinghaus_curve.png',
  'Jaap M. J. Murre · Replication and Analysis of Ebbinghaus’ Forgetting Curve, 2015', BY4,
  'Die Kurve zeigt die Ersparnis beim Wiederlernen im untersuchten Silbenexperiment. Sie ist kein genauer Fahrplan dafür, wann du einen beliebigen Inhalt vergisst.',
  'Diagramm: Mit zunehmender Zeit seit dem Lernen sinkt die gemessene Wiederlern-Ersparnis; der Rückgang ist anfangs steiler.')
M('charts', 'https://commons.wikimedia.org/wiki/File:Comparison_of_properly_and_improperly_scaled_picture_graph.svg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Comparison_of_properly_and_improperly_scaled_picture_graph.svg/1049px-Comparison_of_properly_and_improperly_scaled_picture_graph.svg.png',
  'Smallman12q / Wikimedia Commons', ('CC0', 'https://creativecommons.org/publicdomain/zero/1.0/'),
  'Vergleiche die Bildflächen: Wer Höhe und Breite gleichzeitig vergrössert, kann einen Zahlenunterschied visuell übertreiben.',
  'Gegenüberstellung korrekt und irreführend skalierter Bildsymbole. Die zweidimensionale Vergrösserung lässt Unterschiede grösser erscheinen.')
M('compound', 'https://commons.wikimedia.org/wiki/File:Compound_interest.png',
  'https://upload.wikimedia.org/wikipedia/commons/9/9f/Compound_interest.png', 'Pbergerd / Wikimedia Commons', SA4,
  'Veröffentlichtes Modell: 100 Startkapital bei konstant 5 % Zins. Die Kurve illustriert den Zinseszins; sie ist keine Renditeprognose und enthält keine Kosten.',
  'Zinseszinsdiagramm: Das Kapital wächst bei gleichbleibendem prozentualem Zins zunehmend steiler.')
M('lithography', 'https://commons.wikimedia.org/wiki/File:Photolithography_etching_process_(DE).svg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fa/Photolithography_etching_process_%28DE%29.svg/960px-Photolithography_etching_process_%28DE%29.svg.png',
  'Cmglee · deutsche Bearbeitung: Cepheiden / Wikimedia Commons', SA3,
  'Ein vereinfachter Lithografie- und Ätzprozess: Lack auftragen, belichten, entwickeln und das Muster übertragen. Die Schichten sind schematisch dargestellt.',
  'Deutsch beschriftete Schnittbilder zeigen nacheinander Fotolack, Belichtung durch eine Maske, Entwicklung, Ätzen und Entfernen des Lacks.')
M('overlay', 'https://commons.wikimedia.org/wiki/File:Photolithography_overlay_error_(DE).svg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/e/e6/Photolithography_overlay_error_%28DE%29.svg/960px-Photolithography_overlay_error_%28DE%29.svg.png',
  'Cepheiden / Wikimedia Commons', SA3,
  'Die veröffentlichten Schemata machen verschiedene Überlagerungsfehler sichtbar. Auch scharfe Einzelmuster können gegeneinander verschoben oder verdreht sein.',
  'Schematische Vergleiche von Musterebenen: korrekte Ausrichtung sowie Verschiebung, Drehung und weitere Ausrichtungsfehler.')
M('cleanroom', 'https://commons.wikimedia.org/wiki/File:Scientist_in_the_LCN_cleanroom_photolithography_lab.jpg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3e/Scientist_in_the_LCN_cleanroom_photolithography_lab.jpg/960px-Scientist_in_the_LCN_cleanroom_photolithography_lab.jpg',
  'O. Usher · UCL MAPS, 2013', ('CC BY 3.0', 'https://creativecommons.org/licenses/by/3.0/'),
  'Reales Lithografielabor am London Centre for Nanotechnology. Die orange Beleuchtung hilft, den lichtempfindlichen Lack vor ungeeigneten Lichtanteilen zu schützen.',
  'Eine Person in Reinraumkleidung arbeitet in einem orange beleuchteten Lithografielabor.')
M('clock', 'https://commons.wikimedia.org/wiki/File:Circadian_rhythm_labeled.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/5/55/Circadian_rhythm_labeled.jpg', 'NIH / NIGMS', PD,
  'Licht erreicht über die Augen das System der inneren Uhr. Das NIH-Schema zeigt einen Signalweg, keine persönliche Schlafempfehlung.',
  'Schematische Darstellung des Weges von Licht über das Auge zur inneren Uhr im Gehirn.')
M('water', 'https://commons.wikimedia.org/wiki/File:Water_cycle.png',
  'https://upload.wikimedia.org/wikipedia/commons/9/94/Water_cycle.png', 'John M. Even / USGS', PD,
  'Der Wasserkreislauf verbindet Speicher und Flüsse: Verdunstung, Kondensation, Niederschlag, Versickerung und Abfluss. Die englischen Pfeilbeschriftungen zeigen diese Wege.',
  'USGS-Landschaftsdiagramm mit Meer, Wolken, Bergen und Grundwasser. Pfeile verbinden Verdunstung, Niederschlag und Rückfluss.')
M('market', 'https://commons.wikimedia.org/wiki/File:Supply-and-demand.svg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/7/7a/Supply-and-demand.svg/960px-Supply-and-demand.svg.png',
  'Paweł Zdziarski (faxe), Astarot / Wikimedia Commons', SA3,
  'Ein Modell, keine Marktstatistik: P steht für Preis, Q für Menge, S für Angebot und D für Nachfrage. Eine verschobene Nachfragekurve verändert den Schnittpunkt.',
  'Angebots- und Nachfragekurven mit Preis auf der senkrechten und Menge auf der waagrechten Achse; zwei Nachfragekurven treffen das Angebot an verschiedenen Punkten.')
M('cash', 'https://commons.wikimedia.org/wiki/File:Company_Cash_Cycle.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/7/79/Company_Cash_Cycle.jpg', 'Georgeobancroft / Wikimedia Commons', SA3,
  'Der Geldkreislauf eines Unternehmens: Ausgaben, Bestand und Forderungen können Geld binden, bevor ein Kunde bezahlt. Das Schema enthält nicht die Zahlen unseres Falls.',
  'Kreislaufschema zu Geld, Beschaffung, Lagerbestand, Verkauf und Forderungen eines Unternehmens.')
M('parliament', 'https://commons.wikimedia.org/wiki/File:Nationalratssaal_w%C3%A4hrend_Session.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/1/17/Nationalratssaal_w%C3%A4hrend_Session.jpg',
  'Parlamentsdienste / Schweizerische Bundesversammlung · parlament.ch',
  ('Nutzung mit Quellenangabe', 'https://commons.wikimedia.org/wiki/File:Nationalratssaal_w%C3%A4hrend_Session.jpg'),
  'Der Nationalratssaal während einer Session. Das Foto zeigt die parlamentarische Ebene; Volksabstimmung, Gericht und Regierung erfüllen andere Aufgaben.',
  'Blick in den besetzten Nationalratssaal im Bundeshaus mit den halbkreisförmig angeordneten Sitzreihen.')
M('survivors', 'https://commons.wikimedia.org/wiki/File:Survivorship-bias.svg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/b/b2/Survivorship-bias.svg/960px-Survivorship-bias.svg.png',
  'Martin Grandjean, McGeddon / Wikimedia Commons', SA4,
  'Modernes, hypothetisches Schema zum Survivorship Bias, keine originale Trefferstatistik: Sichtbar sind Schäden an zurückgekehrten Flugzeugen. Die nicht zurückgekehrten fehlen.',
  'Flugzeugsilhouette mit roten Punkten als hypothetischen Schäden. Die entscheidende Frage ist, welche Flugzeuge in dieser Auswahl nicht vorkommen.')
M('socrates', 'https://commons.wikimedia.org/wiki/File:Jacques-Louis_David_-_The_Death_of_Socrates_-_Google_Art_Project.jpg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/99/Jacques-Louis_David_-_The_Death_of_Socrates_-_Google_Art_Project.jpg/960px-Jacques-Louis_David_-_The_Death_of_Socrates_-_Google_Art_Project.jpg',
  'Jacques-Louis David · Der Tod des Sokrates, 1787 · The Metropolitan Museum of Art', PD,
  'David malte diese Szene 1787, lange nach Sokrates. Das Werk ist eine spätere Deutung; Kleidung, Gesten und Anordnung sind kein unmittelbarer Augenzeugenbericht.',
  'Gemälde: Sokrates sitzt auf einem Bett, hebt einen Finger und greift nach einem Becher; um ihn stehen und sitzen trauernde Menschen.')
M('phishing', 'https://commons.wikimedia.org/wiki/File:PhishingTrustedBank.png',
  'https://upload.wikimedia.org/wikipedia/commons/d/d0/PhishingTrustedBank.png', 'Andrew Levine / Wikimedia Commons', PD,
  'Ein veröffentlichtes, fiktives Phishing-Beispiel. Die Aufmachung als Banknachricht belegt nicht, dass Absender und Link wirklich zur Bank gehören.',
  'Nachgebaute E-Mail einer fiktiven Bank mit einer Aufforderung und einem Link; Beispiel für vorgetäuschte Vertrauenswürdigkeit.')
M('epictetus', 'https://commons.wikimedia.org/wiki/File:Epictetus.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/9/90/Epictetus.jpg',
  'Historische Darstellung von Epiktet · Urheber nicht angegeben / Wikimedia Commons', PD,
  'Eine spätere Darstellung von Epiktet, kein zeitgenössisches Porträt. Die Abbildung ordnet die Person ein; ihre Erscheinung beweist keine philosophische Aussage.',
  'Historische gezeichnete Darstellung des Philosophen Epiktet.')
M('shoes', 'https://commons.wikimedia.org/wiki/File:Running_shoes.jpg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a7/Running_shoes.jpg/960px-Running_shoes.jpg', 'Tiia Monto / Wikimedia Commons', SA4,
  'Ein konkreter Startreiz: Bereitgelegte Schuhe machen den ersten Handlungsschritt sichtbar. Das Foto illustriert Vorbereitung, keine Produktempfehlung.',
  'Ein Paar bereitgelegte Laufschuhe.')
M('greenhouse', 'https://commons.wikimedia.org/wiki/File:The_green_house_effect.svg',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d5/The_green_house_effect.svg/960px-The_green_house_effect.svg.png',
  'ZooFari / Wikimedia Commons, 2009', SA3,
  'Ein veröffentlichtes Schema der Energiebilanz von 2009, keine aktuellen Messwerte. Unterscheide einfallendes Sonnenlicht von der Wärmestrahlung der Erde.',
  'Diagramm der Strahlungswege zwischen Sonne, Atmosphäre, Erdoberfläche und Weltraum; ein Teil der Wärmestrahlung wird in der Atmosphäre absorbiert und wieder ausgesendet.')
M('frequencies', 'https://link.springer.com/article/10.1007/s10459-020-10025-8',
  'https://media.springernature.com/lw685/springer-static/image/art%3A10.1007%2Fs10459-020-10025-8/MediaObjects/10459_2020_10025_Fig1_HTML.png',
  'Karin Binder, Stefan Krauss, Ralf Schmidmaier, Leah T. Braun · Abbildung 1, 2021', BY4,
  'Veröffentlichtes medizinisches Lehrbeispiel mit eigenen Modellzahlen. Oben Wahrscheinlichkeiten, unten natürliche Häufigkeiten: Uns interessiert die Gruppierung. Die Zahlen gehören nicht zum Paketfall und sind keine persönliche Diagnose.',
  'Zwei Baumdiagramme desselben medizinischen Lehrbeispiels vergleichen bedingte Wahrscheinlichkeiten mit Anzahlen in den jeweiligen Teilgruppen.')

# Card index 0 sets the scene; index 1 accompanies its explanation. Reuse only when
# the particular image helps understand the chapter, never as a media quota.
PLACEMENTS = {
 'press': ['history.print', 'history.sources', 'case.press.1', 'case.press.2', 'case.press.4'],
 'forgetting': ['learn.spacing', 'case.recall.3'],
 'charts': ['data.charts', 'science.scale'],
 'compound': ['money.compound', 'case.compound.1', 'case.compound.2'],
 'lithography': ['case.chip.1'],
 'overlay': ['case.chip.2'], 'cleanroom': ['case.chip.3', 'case.chip.4'],
 'clock': ['health.sleep', 'case.sleep.2'],
 'water': ['earth.water', 'earth.stocks'],
 'market': ['economy.elasticity'],
 'cash': ['business.cash', 'case.cash.1', 'case.cash.2'],
 'parliament': ['civics.federalism', 'civics.powers', 'civics.participation'],
 'survivors': ['think.survivors', 'data.sample'],
 'socrates': ['philosophy.questions', 'case.socrates.1', 'history.photos'],
 'phishing': ['digital.phishing'], 'epictetus': ['philosophy.control', 'case.stoic.1'],
 'shoes': ['development.environment', 'case.habit.1'],
 'greenhouse': ['earth.greenhouse'], 'frequencies': ['case.rates.3'],
}

def apply_media(lessons):
    by_id = {l['id']: l for l in lessons}
    for key, ids in PLACEMENTS.items():
        for lesson_id in ids:
            assert lesson_id in by_id, lesson_id
            card = by_id[lesson_id]['cards'][1]
            assert 'media' not in card, lesson_id
            card['media'] = deepcopy(MEDIA[key])

def write_credits(root):
    lines = ['# Recherchierte Lernmedien', '', 'Quellen und Nutzungsbedingungen geprüft am 14. September 2026. Die App zeigt vollständige Abbildungen, Bildbeschreibungen, Urheber, Quelle und Lizenz. Alle Lernfragen funktionieren auch ohne Bildabruf. Bilder werden beim ersten Öffnen über HTTPS geladen und anschliessend lokal zwischengespeichert.', '', 'Keine dieser Abbildungen wurde für Gate generiert. Historische Darstellungen, didaktische Modelle und Messdaten werden in ihren Bildunterschriften unterschieden.', '']
    for key, media in MEDIA.items():
        lines += [f'## {key}', '', f'[{media["credit"]}]({media["sourceURL"]}) · [{media["license"]}]({media["licenseURL"]})', '', media['caption'], '', 'Kapitel: ' + ', '.join(PLACEMENTS[key]), '']
    (root / 'docs/MEDIA_SOURCES.md').write_text('\n'.join(lines))
