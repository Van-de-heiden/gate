"""Exact, hand-authored relationships for the stages without a new scene image.

Indices select the card where the relationship is taught. Never generate numbers
or historically significant details inside bitmap illustrations.
"""
from story_authoring import bars, chain, compare

VISUALS = {
 'case.press.4': (1, compare('Drei Ebenen der Spur', [
  'Beobachtung: Ein erhaltenes Druckobjekt kann direkt untersucht werden.',
  'Deutung: Die Herstellung vieler gleicher Seiten wird technisch erleichtert.',
  'Offene Frage: Wer las den Text, verstand ihn und änderte deshalb sein Handeln?'
 ], 'Objekt, technische Möglichkeit und gesellschaftliche Wirkung sind unterschiedliche Belege.')),
 'case.stoic.3': (1, chain('Verantwortung nach einer Absage', [
  'Fakt: Ein Angebot wurde abgelehnt.',
  'Prüfung: Welche Gründe sind tatsächlich bekannt?',
  'Handlung: Sachlich nachfragen oder das eigene Angebot verbessern.',
  'Grenze: Die Entscheidung der anderen Person bleibt nicht garantiert.'
 ], 'Die Unterscheidung begrenzt Kontrollansprüche, nicht deine Verantwortung.')),
 'case.stoic.4': (1, compare('Zwei Arten von Erfolg', [
  'Handlung: Ich frage respektvoll nach einer konkreten Rückmeldung.',
  'Ergebnis: Die andere Person entscheidet, ob und wie sie antwortet.'
 ], 'Die Qualität der eigenen Antwort lässt sich beurteilen, auch wenn das erhoffte Ergebnis ausbleibt.')),
 'case.socrates.3': (1, compare('Nötig ist nicht dasselbe wie genug', [
  'Notwendig: Ohne diese Bedingung fehlt eine Voraussetzung.',
  'Hinreichend: Wenn diese Bedingung erfüllt ist, reicht sie für das Ergebnis.'
 ], 'Prüfe getrennt: Braucht es Geld für jedes erfolgreiche Leben? Reicht Geld allein aus?')),
 'case.socrates.4': (2, chain('Eine Definition wird belastbarer', [
  'Behauptung formulieren', 'Passendes Gegenbeispiel prüfen',
  'Definition begründet ändern', 'Verbleibende Wertfrage benennen'
 ], 'Eine sichtbare Revision ist ein Denkschritt, keine Niederlage im Gespräch.')),
 'case.chip.2': (1, chain('Ein vereinfachter Schichtaufbau', [
  'Muster für eine Schicht vorbereiten', 'Zur vorhandenen Struktur ausrichten',
  'Muster übertragen und weiterverarbeiten', 'Für weitere Schichten erneut prüfen'
 ], 'Schema, kein vollständiger Fertigungsablauf. Ausrichtung und Wiederholung sind beide wichtig.')),
 'case.sleep.2': (1, compare('Zwei Einflüsse auf deinen Abend', [
  'Schlafdruck: Baut sich während des Wachseins auf.',
  'Tagesrhythmus: Zeitliche Organisation, unter anderem durch Licht beeinflusst.'
 ], 'Ein vereinfachtes Erklärmodell, keine persönliche Schlafmessung.')),
 'case.sleep.4': (2, chain('Ein begrenzter Abendversuch', [
  'Eine konkrete Änderung festlegen', 'An mehreren Abenden beobachten',
  'Unterschiedliche Tagesbedingungen mitdenken', 'Vorsichtig auswerten und anpassen'
 ], 'Eine einzelne Nacht kann weder die Ursache beweisen noch eine Erkrankung diagnostizieren.')),
 'case.habit.2': (1, chain('Die Haustür bekommt einen anderen Anschluss', [
  'Auslöser: Zuhause ankommen', 'Umgebung: Schuhe bereit, Telefon an anderem Ort',
  'Handlung: Den vereinbarten kleinen Gang beginnen'
 ], 'Eine greifbare Handlung ersetzt das unspezifische «Heute bin ich diszipliniert».')),
 'case.habit.4': (1, bars('Fünf Gelegenheiten im Lernfall', [
  'Plan umgesetzt', 'Plan nicht umgesetzt'
 ], [4, 1], '4 von 5 = 80 % Umsetzung. Das ist nicht automatisch 80 % weniger Bildschirmzeit.')),
 'case.deal.3': (1, bars('Der Auftrag unter deiner Grenze', [
  'Angebotener Umsatz', 'Erwartete Kosten'
 ], [2200, 2400], 'Im vereinfachten Beispiel fehlen 200 CHF zur Kostendeckung. Die Alternative zur Einigung bleibt zu prüfen.')),
 'case.deal.4': (2, compare('Was muss die Einigung klären?', [
  'Leistung und Umfang', 'Termin und Zuständigkeit', 'Preis und Zahlungsfolge',
  'Umgang mit Änderungen', 'Gemeinsames Verständnis'
 ], 'Kommunikationshilfe, keine vollständige Vertrags- oder Rechtsberatung.')),
 'case.sunk.2': (0, bars('Wert ab der heutigen Entscheidung', [
  'Reparieren: 180 − 120', 'Sofort verkaufen'
 ], [60, 50], 'Der Unterschied beträgt 10 CHF. Die unwiederbringlichen 300 CHF sind für beide Möglichkeiten identisch.')),
 'case.sunk.4': (2, compare('Was ändert die Zukunftsrechnung?', [
  'Relevant: Ein neuer geprüfter Kostenvoranschlag oder ein entdeckter Schaden.',
  'Allein unzureichend: Es ist inzwischen noch mehr unwiederbringlich ausgegeben.'
 ], 'Neue Tatsachen können eine Regel ändern; blosse Rechtfertigung alter Ausgaben genügt nicht.')),
 'case.rates.3': (1, bars('Die Alarme im veränderten Eingang', [
  'Echte Alarme', 'Fehlalarme'
 ], [90, 90], '100 beschädigte und 900 unbeschädigte Pakete; dieselben Modellraten. 90 von 180 Alarmen = 50 %.')),
 'case.recall.2': (1, chain('Vom Fehler zum besseren Modell', [
  'Eigene Antwort: Kopieren garantiert Wahrheit.',
  'Korrektur: Kopiergenauigkeit und Wahrheit unterscheiden.',
  'Gegenprobe: Eine falsche Jahreszahl exakt kopieren.',
  'Spätere Frage: Den Unterschied ohne Vorlage erklären.'
 ], 'Die Erklärung repariert eine Annahme; eine gemerkte Antwortposition tut das nicht.')),
 'case.recall.4': (2, compare('Gleiche Struktur, andere Oberfläche', [
  'Druckform: Ein Fehler wird in viele Abzüge übernommen.',
  'Tabellenprogramm: Ein falscher Eingangswert fliesst in viele Berichte.'
 ], 'Übertragbar ist die Prüfung der Vorlage – nicht jede historische oder technische Eigenschaft.')),
}
