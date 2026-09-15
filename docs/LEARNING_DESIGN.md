> Stand 0.7: [100 Kapitel und Quellen](CURRICULUM_V7.md). Eine neue Runde umfasst ein Kapitel; Abbildungen sind optional. Die nachfolgende Dokumentation der Ausgabe 0.6 bleibt als Historie erhalten.

# Lern- und Oberflächendesign · Version 6

Die Rückmeldung nach Ausgabe 5 war weiterhin: zu viele ähnliche Kapitel, zu wenig Erkenntnis und zu wenige Bilder. Diese Ausgabe reduziert deshalb 144 Kapitel auf 15 und schreibt die verbleibenden Kapitel neu.

## Woran sich ein Kapitel messen muss

- Eine eigenständige Frage mit einer konkreten Entdeckung, beispielsweise Platon als abwesender «Augenzeuge» im Sokrates-Gemälde.
- Eine veröffentlichte Abbildung, an der der Leser etwas erkennen, verfolgen oder vergleichen kann.
- Eine verständliche Erklärung des Mechanismus und seiner Grenzen.
- Eine Anwendung, die mehr verlangt als eine Zahl oder einen Satz auswendig wiederzugeben.
- Keine Mindestwortzahl, erzwungene Lernzeit oder feste Fragenzahl.

Das Prüfprotokoll `scripts/content/review_v6.json` verknüpft jedes Kapitel mit seiner Entdeckung, Bildaufgabe, Fachquelle und den Zwecken seiner Fragen. Es ist ein redaktionelles Arbeitsprotokoll, kein Nachweis für extern geprüfte Lehrqualität. Gefallen, Schwierigkeit und Lernerfolg müssen zusätzlich mit Nutzern beobachtet werden.

## Ablauf

Eine neue Pflichtrunde beginnt mit zwei gespeicherten zufälligen Themenvorschlägen. Titel und Einstieg beschreiben die konkrete Entdeckung; Kapitelzahl, Aufgaben und ungefähre Dauer helfen bei der Wahl. Das Auswählen startet genau dieses Thema. Die Bibliothek zeigt dieselben Themen ohne parallelen, doppelt aufgeführten Grundlagenkatalog.

Kurze Leseseiten wechseln mit Originalabbildungen und bewerteten Aufgaben. Abbildungen lassen sich unbeschnitten vergrössern und bei Zwischenfragen erneut öffnen. Nach der Abgabe bleibt die Antwort gesperrt; die Begründung erklärt auch einen Fehler. Die Schlussrunde enthält nur noch nicht unterwegs gewertete Fragen. Bestehen erfordert weiterhin 80 Prozent über die tatsächliche Gesamtzahl.

## Visuelle Sprache

Die native Startseitenlandschaft variiert mit der lokalen Tageszeit: Morgenlicht, blauer Tageshimmel, Abendfarben und Midnight Blue mit Sternen. Wiese, Baum und Wolken bilden den gesamten Hintergrund. Tankanzeige, Lernaktion und App-Textliste stehen ohne separate Karten darin. Abgerundete Systemschrift und grüne/blaue Akzente bleiben konsistent. Die Lernabbildungen sind recherchierte Medien; die dekorative Landschaft erklärt keinen Fachinhalt.

Die Landschaft läuft ohne Animationsschleife; nur der Wechsel der Tagesphase blendet sanft über. Reduce Motion deaktiviert diese Überblendung. VoiceOver, Dynamic Type, Bildzoom, echte Netzfehler und die Übergänge zwischen Themenwahl, Leser, Ergebnis und Pause gehören zum Gerätetest. Aufbau und Vorschauen der Startseite sind in [HOME_LANDSCAPE.md](HOME_LANDSCAPE.md) dokumentiert.
