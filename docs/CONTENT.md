# Aktiver Katalog · Version 6

Die Ausgabe enthält 10 Themen, 15 eigenständige Kapitel und 35 Fragen. 15 Zwischenfragen zählen zum selben Ergebnis wie die Abschlussfragen; jede wird nur einmal gewertet. Jede Abbildung ist veröffentlicht und mit einer Beobachtungsaufgabe verbunden. Es gibt keine generierten Lehrbilder und keine isolierte Prozentrechnung auf Nachkommastellen.

## Quellen und Aufbau

`scripts/content/curated_v6.py` ist die einzige aktive redaktionelle Quelle. `scripts/build_curriculum.py` erzeugt daraus `Gate/curriculum.json`, die Mediennachweise und das Inhaltsprüfprotokoll. Alte Module bleiben als Archiv erhalten, werden aber nicht in die App importiert. Die Entscheidungen für alle 144 bisherigen Kapitel stehen in `CURRICULUM_REVIEW.md`.

Die Themen sind unterschiedlich lang: sieben bestehen aus einem Kapitel, eines aus zwei und zwei aus drei Kapiteln. Umfang und Fragenzahl entstehen aus dem Inhalt. Weder Freigabeminuten noch Konsumzeit oder Fehlerzahl verlängern ein Thema. Jede Frage hat einen benannten Zweck; falsche Antworten stehen für ein konkretes Missverständnis. Aufgaben verlangen Beobachten, Erklären, Zuordnen, Ordnen oder Übertragen.

## Auswahl und Fortsetzen

Eine neue Freigaberunde zeigt zwei verschiedene zufällige Themen. Kürzlich gelernte Themen werden vermieden, solange mindestens zwei andere verfügbar sind. Wenn möglich kommen die Vorschläge aus verschiedenen Bereichen. Die Auswahl wird unter der UUID der Anfrage gespeichert. Schliessen, Neustart und andere gewünschte Freigabeminuten würfeln sie nicht neu. Gewählte Themen sind fest; Fehlversuche wiederholen nur Kapitel hinter den tatsächlichen Lücken. Eine andere App hat ihre eigene Auswahl. Nach erfolgreicher Freigabe wird das Angebot entfernt.

In der freiwilligen Bibliothek kann jedes Thema direkt geöffnet werden. Fällige Wiederholungen bleiben auf ein Thema beschränkt und können nur eine einzige Frage enthalten. Das Auswahlsystem funktioniert auch bei einem kleinen künftigen Katalog; es erfindet keine zweite Option, wenn nur ein Thema vorhanden ist.

## Migration

Fragen tragen `.v6.q…`-IDs. Version 5 hatte `.v5.q…`; alte Erinnerungsdaten geben den neuen Fragen deshalb keinen Lernstatus. Historische Ergebnisse, alte Abschluss-IDs und persönliche Notizen bleiben erhalten. Die Oberfläche markiert ein aktuelles Kapitel erst als erarbeitet, wenn seine aktuellen Fragen entsprechend bearbeitet wurden.

Veraltete offene und nicht bestandene Sitzungen werden entfernt; ihre Notizen werden vorher gesichert. Bestandene Sitzungen bleiben bis zur erteilten Freigabe erhalten. Veraltete Themenangebote werden verworfen. Eine laufende Sitzung dieser Version bleibt unverändert gespeichert.

## Medien

Jedes Kapitel besitzt mindestens eine vollständige, zugeordnete Abbildung mit Urheber, Lizenz, Quelle, deutscher Bildbeschreibung und erklärender Bildunterschrift. Historische Darstellungen, schematische Modelle und Forschungsdaten werden unterschieden. Bei den bewerteten Zwischenfragen lässt sich die Kapitelabbildung erneut öffnen.

Bilder werden derzeit beim ersten Öffnen über HTTPS geladen und danach in einem validierten, begrenzten Cache gespeichert. Der Erstabruf braucht eine Verbindung. Bei Ausfall bleiben Bildbeschreibung und Erklärung sichtbar; erneuter Abruf ist möglich. Quellen- und Dateiadressen sind dokumentiert; die tatsächliche Darstellung aller Bilder auf dem iPhone bleibt ein Gerätecheck.
