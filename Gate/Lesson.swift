import Foundation

struct LessonQuestion: Identifiable {
    let id: String
    let prompt: String
    let answers: [String]
    let correctAnswer: Int
    let explanation: String
}

struct GateLesson {
    let title: String
    let body: String
    let estimatedMinutes: Int
    let questions: [LessonQuestion]

    static func make(failureLevel: Int) -> GateLesson {
        let level = max(0, failureLevel)
        let multiplier = pow(1.2, Double(level))
        let questionCount = min(Int(ceil(3 * multiplier)), questionBank.count)
        let estimatedMinutes = max(2, Int(ceil(2 * multiplier)))
        let offset = min(level, questionBank.count - 1)
        let rotated = Array(questionBank[offset...]) + Array(questionBank[..<offset])

        return GateLesson(
            title: "Aktives Erinnern",
            body: "Lesen erzeugt leicht das Gefühl, etwas verstanden zu haben. Lernen entsteht erst, wenn du den Gedanken ohne Vorlage aus dem Gedächtnis zurückholst. Schliess deshalb kurz die Augen, formuliere den Kern in eigenen Worten und beantworte danach die Fragen.",
            estimatedMinutes: estimatedMinutes,
            questions: Array(rotated.prefix(questionCount))
        )
    }

    private static let questionBank: [LessonQuestion] = [
        LessonQuestion(
            id: "recall",
            prompt: "Welche Methode stärkt Erinnerung am zuverlässigsten?",
            answers: ["Den Text mehrfach ansehen", "Den Inhalt aktiv ohne Vorlage abrufen", "Wichtige Sätze farbig markieren"],
            correctAnswer: 1,
            explanation: "Aktiver Abruf zwingt das Gehirn, die Gedächtnisspur tatsächlich zu benutzen."
        ),
        LessonQuestion(
            id: "spacing",
            prompt: "Warum sind verteilte Wiederholungen wirksamer als eine lange Sitzung?",
            answers: ["Vergessen und erneutes Abrufen festigen die Spur", "Sie vermeiden jede geistige Anstrengung", "Die Reihenfolge spielt keine Rolle"],
            correctAnswer: 0,
            explanation: "Ein wenig Vergessen macht den nächsten Abruf anspruchsvoller und dadurch wirksamer."
        ),
        LessonQuestion(
            id: "illusion",
            prompt: "Was ist die typische Illusion beim blossen Wiederlesen?",
            answers: ["Vertrautheit wird mit Beherrschung verwechselt", "Der Text wird automatisch kürzer", "Man erinnert sich nur an Bilder"],
            correctAnswer: 0,
            explanation: "Bekanntheit fühlt sich wie Wissen an, beweist aber keinen selbständigen Abruf."
        ),
        LessonQuestion(
            id: "feedback",
            prompt: "Wann ist Feedback nach einer Übungsfrage besonders nützlich?",
            answers: ["Nach einem eigenen Antwortversuch", "Bevor man die Frage liest", "Nur wenn alles richtig war"],
            correctAnswer: 0,
            explanation: "Erst der eigene Versuch macht sichtbar, welche Lücke das Feedback schliessen soll."
        ),
        LessonQuestion(
            id: "interleave",
            prompt: "Was bedeutet verschachteltes Üben?",
            answers: ["Verschiedene Aufgabentypen sinnvoll mischen", "Eine Aufgabe hundertmal identisch lösen", "Beim Lernen gleichzeitig Videos ansehen"],
            correctAnswer: 0,
            explanation: "Das Mischen verlangt, bei jeder Aufgabe die passende Methode neu zu erkennen."
        ),
        LessonQuestion(
            id: "explain",
            prompt: "Woran erkennst du am ehesten, ob du etwas verstanden hast?",
            answers: ["Du kannst es einfach und ohne Vorlage erklären", "Du erkennst die Seite wieder", "Du hast den Satz unterstrichen"],
            correctAnswer: 0,
            explanation: "Eine klare Erklärung in eigenen Worten legt Verständnis ebenso wie Lücken offen."
        ),
        LessonQuestion(
            id: "difficulty",
            prompt: "Welche Übung ist meist lernwirksamer?",
            answers: ["Eine leicht anstrengende Abrufaufgabe", "Eine völlig mühelose Wiederholung", "Eine Ablenkung zwischen jedem Satz"],
            correctAnswer: 0,
            explanation: "Erwünschte Schwierigkeit erhöht die Verarbeitung, solange die Aufgabe lösbar bleibt."
        ),
        LessonQuestion(
            id: "summary",
            prompt: "Was ist der Kern dieser Lektion?",
            answers: ["Wissen prüfen statt Vertrautheit sammeln", "Mehr markieren bedeutet mehr verstehen", "Lernen soll keinerlei Anstrengung verursachen"],
            correctAnswer: 0,
            explanation: "Selbständiger Abruf ist der ehrlichere und wirksamere Lernnachweis."
        )
    ]
}
