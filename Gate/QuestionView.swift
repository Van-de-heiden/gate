import SwiftUI

struct QuestionView: View {
    let item: SessionQuestion
    let response: QuestionResponse?
    let answer: (QuestionResponse) -> Void
    @State private var order: [Int] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.question.prompt).font(.headline).fixedSize(horizontal: false, vertical: true)
            if let hint = item.question.hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
            switch item.question.kind {
            case .singleChoice, .multipleChoice: choices
            case .ordering: ordering
            case .matching: matching
            case .recall, .cloze, .numeric: textEntry
            }
        }
    }

    private var choices: some View {
        VStack(spacing: 10) {
            if item.question.kind == .multipleChoice {
                Text("Wähle alle zutreffenden Antworten.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(item.optionOrder, id: \.self) { index in
                let selected = response?.indices.contains(index) == true
                Button {
                    GateKeyboard.dismiss()
                    if item.question.kind == .singleChoice { answer(QuestionResponse(indices: [index])) }
                    else {
                        var indices = Set(response?.indices ?? [])
                        if !indices.insert(index).inserted { indices.remove(index) }
                        answer(QuestionResponse(indices: indices.sorted()))
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.question.kind == .multipleChoice
                              ? (selected ? "checkmark.square.fill" : "square")
                              : (selected ? "largecircle.fill.circle" : "circle"))
                            .font(.body).padding(.top, 2).accessibilityHidden(true)
                        Text(item.question.options[index]).font(.subheadline).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? Color.primary.opacity(0.09) : GateDesign.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var ordering: some View {
        VStack(spacing: 10) {
            Text("Bringe die Schritte mit den Pfeilen in die richtige Reihenfolge.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(order.enumerated()), id: \.element) { position, index in
                HStack(spacing: 10) {
                    Text("\(position + 1)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(item.question.options[index]).font(.subheadline)
                    Spacer(minLength: 0)
                    Button { move(position, by: -1) } label: { Image(systemName: "arrow.up").frame(width: 36, height: 44) }
                        .disabled(position == 0).accessibilityLabel("\(item.question.options[index]) nach oben")
                    Button { move(position, by: 1) } label: { Image(systemName: "arrow.down").frame(width: 36, height: 44) }
                        .disabled(position == order.count - 1).accessibilityLabel("\(item.question.options[index]) nach unten")
                }.padding(.horizontal, 12).padding(.vertical, 6).background(GateDesign.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Button(response == nil ? "Reihenfolge übernehmen" : "Reihenfolge gespeichert") {
                answer(QuestionResponse(indices: order))
            }.buttonStyle(GateButtonStyle(prominent: false))
        }.onAppear { order = response?.indices.isEmpty == false ? response!.indices : item.optionOrder }
    }

    private func move(_ position: Int, by delta: Int) {
        guard order.indices.contains(position + delta) else { return }
        order.swapAt(position, position + delta)
        answer(QuestionResponse(indices: order))
    }

    private var matching: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jede Antwort gehört genau zu einem Begriff.").font(.caption).foregroundStyle(.secondary)
            ForEach(Array((item.question.pairs ?? []).enumerated()), id: \.offset) { index, pair in
                VStack(alignment: .leading, spacing: 8) {
                    Text(pair.left).font(.subheadline.weight(.medium))
                    Picker(pair.left, selection: Binding(
                        get: { response?.matches[index] ?? -1 },
                        set: { value in
                            var result = response ?? QuestionResponse()
                            if value < 0 { result.matches.removeValue(forKey: index) }
                            else {
                                // Choosing an occupied answer releases the old pair instead of creating duplicates.
                                result.matches = result.matches.filter { $0.value != value }
                                result.matches[index] = value
                            }
                            answer(result)
                        })) {
                            Text("Zuordnung wählen").tag(-1)
                            ForEach(item.optionOrder, id: \.self) { option in
                                Text(item.question.pairs![option].right).tag(option)
                            }
                        }.pickerStyle(.menu).labelsHidden().tint(.primary)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var textEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                TextField(item.question.kind == .numeric ? "Dein Ergebnis" : "Gesuchter Begriff", text: Binding(
                    get: { response?.text ?? "" }, set: { answer(QuestionResponse(text: $0)) }))
                    .keyboardType(item.question.kind == .numeric ? .numbersAndPunctuation : .default)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.done).onSubmit { GateKeyboard.dismiss() }
                    .padding(14).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(item.question.prompt)
                if let unit = item.question.unit { Text(unit).font(.subheadline).foregroundStyle(.secondary) }
            }
            HStack {
                Text(item.question.kind == .numeric
                     ? "Komma oder Punkt als Dezimalzeichen; Einheit steht daneben."
                     : "Ein Begriff genügt. Grossschreibung und Umlaute sind flexibel.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Fertig") { GateKeyboard.dismiss() }.font(.subheadline.weight(.medium))
            }
        }
    }
}
