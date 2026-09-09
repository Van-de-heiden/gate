import SwiftUI

struct LessonView: View {
    @ObservedObject var controller: ScreenTimeController

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LEKTION ZUR FREIGABE")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundColor(.secondary)
                Text(controller.lesson.title)
                    .font(.title2.weight(.semibold))
                Text("Etwa \(controller.lesson.estimatedMinutes) Minuten · danach 5 aktive Minuten")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text(controller.lesson.body)
                .font(.body)
                .lineSpacing(5)

            if controller.cooldownRemaining > 0 {
                cooldownView
            } else {
                questions
                Button("Prüfung abgeben") {
                    controller.submitLesson()
                }
                .buttonStyle(LessonSubmitButtonStyle())
                .disabled(!controller.canSubmitLesson)
                .opacity(controller.canSubmitLesson ? 1 : 0.45)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var questions: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(controller.lesson.questions.enumerated()), id: \.element.id) { index, question in
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(index + 1). \(question.prompt)")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(question.answers.enumerated()), id: \.offset) { answerIndex, answer in
                        Button {
                            controller.chooseAnswer(answerIndex, for: question)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(UnicodeScalar(65 + answerIndex)!))
                                    .font(.caption.monospaced().weight(.semibold))
                                    .frame(width: 18, height: 18)
                                    .background(Circle().stroke(Color.secondary, lineWidth: 1))
                                Text(answer)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(answerBackground(question: question, answerIndex: answerIndex))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func answerBackground(question: LessonQuestion, answerIndex: Int) -> Color {
        controller.answers[question.id] == answerIndex
            ? Color.primary.opacity(0.12)
            : Color.primary.opacity(0.045)
    }

    private var cooldownView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 8) {
                Text("ABKÜHLZEIT")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                if let until = controller.cooldownUntil, until > Date() {
                    Text(until, style: .timer)
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    Text("Danach kannst du die umfangreichere Prüfung erneut versuchen.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Button("Weiter") {
                        controller.refreshSharedState()
                    }
                    .buttonStyle(LessonSubmitButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.primary.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct LessonSubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.primary.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
