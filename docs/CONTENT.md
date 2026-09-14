# Lerninhalte · Version 5

144 redaktionell überarbeitete Kapitel in 16 Lernwegen, darunter zwölf zusammenhängende Lernfälle. Jedes Kapitel beginnt mit einer konkreten Situation, erklärt den entscheidenden Zusammenhang und lässt ihn anwenden. Nützliche fachliche Erklärungen wurden übernommen; neue Einstiege und Prüfungsaufgaben ersetzen das bisherige Gerüst und alle alten Aufgaben.

Der Katalog enthält 295 begründete Verständnisfragen: 144 davon stehen als bewertete Zwischenfragen im Leser. Diese Fragen zählen genau einmal, werden mit der Abgabe gesperrt und erscheinen im Abschluss nicht erneut. Die übrigen Aufgaben prüfen zusätzliche Unterschiede oder den Transfer. Aktuell verwenden die Kapitel zwei oder drei Aufgaben, die Fälle insgesamt acht oder neun. Das sind redaktionelle Entscheidungen dieser Ausgabe, keine Quoten des Schedulers. Eine spätere Ausgabe kann andere sinnvolle Umfänge haben.

Keine Zahlen-Eingabefragen, vorgeschriebenen Dezimalstellen oder versteckten Zeitvorgaben. Der Paketfall prüft Grundhäufigkeit, Fehlalarm, Unsicherheit und eine sinnvolle Nachprüfung. Er verlangt keine Prozentrechnung. Die allgemeine Unterstützung alter Aufgabenformate bleibt für gespeicherte Ergebnisse erhalten.

Die Freigabedauer 5/10/15/20/30 Minuten bestimmt ausschliesslich die Konsumfreigabe. Nutzungszeit und Fehlversuche fügen keine Lernkapitel oder Aufgaben hinzu. Eine neue Runde behandelt ein vollständiges konkretes Thema. Eine Fehlerrunde behandelt die Kapitel der offenen Lücken desselben Themas; eine fällige Wiederholung enthält nur die ausgewählten fälligen Aufgaben. Ein einzelnes Grundlagenkapitel ist ebenfalls ein vollständiges Thema.

19 recherchierte externe Abbildungen stehen an 39 passenden Stellen: historische Darstellungen, reale Fotos und veröffentlichte Diagramme. Quellen, Nutzungsbedingungen, Alt-Texte und Einordnung sind in [MEDIA_SOURCES.md](MEDIA_SOURCES.md) dokumentiert und in der App sichtbar. Keine generierten Lernbilder. Der erste Abruf benötigt Internet; bereits geladene Abbildungen werden bis zu einem Cache-Limit von 64 MB gespeichert. Eine nicht erreichbare Abbildung blockiert weder Lesen noch Prüfung. Diagramme werden vollständig dargestellt und lassen sich vergrössern.

## Fortschritt beim Update

Kapitel-IDs bleiben stabil. Jede geänderte Frage hat eine neue v5-ID; alte richtige Antworten gelten nicht als gelöste neue Aufgaben. Lernhistorie, erarbeitete Kapitel, vorhandene Erinnerungsdaten und bereits bestandene, noch nicht eingelöste Ergebnisse bleiben erhalten. Unfertige Runden mit ersetzten Fragen starten neu, eigene Notizen werden in die neuen Runden übernommen. Aktuelle Runden speichern Leseposition, Antwortreihenfolge, Abgaben und Fragenstand weiterhin.

## Reproduzieren

`python3 scripts/build_curriculum.py` baut ausschliesslich aus den Autorendateien und der eingefrorenen historischen Basis. `editorial_v5.py` muss alle 144 Kapitel genau einmal bearbeiten; `researched_media.py` liefert die Quellen und erzeugt die Medienübersicht. Der aktuelle Ausgabekatalog wird niemals als Bau-Eingabe verwendet.

`python3 scripts/validate.py` prüft Zuordnung, Eindeutigkeit, Antwortschemata, die Zugehörigkeit bewerteter Zwischenfragen, Mediennachweise und das Xcode-Projekt. `swift test` prüft Wertung, Migration, Wiederholung und Bildschirmzeitregeln; der Simulator-Build prüft die native Oberfläche. Fachliche Qualität und Lesefluss werden zusätzlich anhand der tatsächlich formulierten Kapitel beurteilt, nicht aus Wortzahl oder Verweildauer abgeleitet.
