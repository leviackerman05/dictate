import DictateCore
import SwiftUI

struct DictionaryView: View {
    @ObservedObject var model: AppModel
    @State private var draft: DictionaryEntry?

    var body: some View {
        dictionaryList
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.ColorToken.background)
        .sheet(item: $draft) { entry in
            DictionaryEditor(
                model: model,
                draft: entry,
                isNew: !model.dictionary.contains(where: { $0.id == entry.id }),
                onClose: { draft = nil }
            )
            .frame(width: DesignSystem.Layout.onboardingWidth, height: 520)
            .background(DesignSystem.ColorToken.surface)
        }
    }

    private var dictionaryList: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Copy.dictionary)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(String(localized: "dictionary.pageDetail"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Spacer()
                Button(action: beginNew) {
                    Label(String(localized: "dictionary.addRule"), systemImage: "plus")
                }
                .buttonStyle(DictionaryPrimaryButtonStyle())
                .accessibilityLabel(String(localized: "dictionary.addRule"))
            }

            if !model.dictionaryNotice.isEmpty {
                Label(model.dictionaryNotice, systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .transition(.opacity)
            }

            if model.dictionary.isEmpty {
                emptyDictionaryState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(String.localizedStringWithFormat(String(localized: "dictionary.ruleCount"), model.dictionary.count))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                            Spacer()
                            if model.dictionary.count > 6 {
                                SearchField(text: $model.dictionarySearch, prompt: Copy.searchDictionary)
                                    .frame(width: 240)
                            }
                        }

                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(visibleEntries) { entry in
                                    DictionaryRow(
                                        entry: entry,
                                        isSelected: false,
                                        onEdit: { draft = entry },
                                        onDelete: { model.deleteDictionaryEntry(entry) },
                                        onToggleEnabled: { enabled in model.setDictionaryEnabled(enabled, for: entry) }
                                    )
                                    .contextMenu {
                                        Button(entry.isEnabled ? String(localized: "dictionary.disable") : String(localized: "dictionary.enable")) {
                                            model.setDictionaryEnabled(!entry.isEnabled, for: entry)
                                        }
                                        Button(Copy.delete, role: .destructive) { model.deleteDictionaryEntry(entry) }
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .scrollContentBackground(.hidden)
                        .background(DesignSystem.ColorToken.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.ColorToken.border) }
                    }
                    .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
                }
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.ColorToken.background)
        .animation(.easeOut(duration: DesignSystem.Motion.feedback), value: model.dictionary.isEmpty)
    }

    private var emptyDictionaryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText.opacity(0.7))
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(String(localized: "dictionary.empty.title"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(String(localized: "dictionary.empty.detail"))
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private func beginNew() {
        draft = DictionaryEntry.vocabulary("")
    }

    private var visibleEntries: [DictionaryEntry] {
        let query = model.dictionarySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.dictionary }
        return model.dictionary.filter { entry in
            entry.sourcePhrase.localizedCaseInsensitiveContains(query) ||
                (entry.targetPhrase?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}

private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let isSelected: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleEnabled: (Bool) -> Void

    @State private var isHovered = false

    private var kindColor: Color {
        entry.kind == .correction ? DesignSystem.ColorToken.coralIndex : DesignSystem.ColorToken.mossIndex
    }

    private var actionTint: Color {
        isSelected ? DesignSystem.ColorToken.inverseText : DesignSystem.ColorToken.primaryText
    }

    private var actionHoverBackground: Color {
        isSelected ? DesignSystem.ColorToken.inverseText.opacity(0.16) : DesignSystem.ColorToken.raisedSurface
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? DesignSystem.ColorToken.inverseText : kindColor)
                .frame(width: 4, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(entry.sourcePhrase.isEmpty ? String(localized: "dictionary.untitled") : entry.sourcePhrase)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    if entry.kind == .correction, let target = entry.targetPhrase {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isSelected ? DesignSystem.ColorToken.inverseText.opacity(0.7) : DesignSystem.ColorToken.secondaryText)
                        Text(target)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(isSelected ? DesignSystem.ColorToken.inverseText.opacity(0.85) : DesignSystem.ColorToken.secondaryText)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 7) {
                    Text(entry.kind == .correction ? Copy.corrections : Copy.vocabulary)
                    Text("•")
                    Text(entry.updatedAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? DesignSystem.ColorToken.inverseText.opacity(0.78) : DesignSystem.ColorToken.secondaryText)
            }
            .opacity(entry.isEnabled ? 1 : 0.55)

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                if isHovered {
                    Toggle("", isOn: Binding(
                        get: { entry.isEnabled },
                        set: { enabled in onToggleEnabled(enabled) }
                    ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(DesignSystem.ColorToken.action)
                        .accessibilityLabel(entry.isEnabled ? String(localized: "dictionary.disable") : String(localized: "dictionary.enable"))
                    DictionaryRowIconButton(
                        systemName: "pencil",
                        help: String(localized: "dictionary.editAction"),
                        tint: actionTint,
                        hoverBackground: actionHoverBackground,
                        action: onEdit
                    )
                    DictionaryRowIconButton(
                        systemName: "trash",
                        help: String(localized: "dictionary.deleteAction"),
                        tint: isSelected ? DesignSystem.ColorToken.inverseText : DesignSystem.ColorToken.failure,
                        hoverBackground: actionHoverBackground,
                        action: onDelete
                    )
                }
            }
            .frame(width: isHovered ? 80 : 0, alignment: .trailing)
            .clipped()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .foregroundStyle(isSelected ? DesignSystem.ColorToken.inverseText : DesignSystem.ColorToken.primaryText)
        .background(
            isSelected ? DesignSystem.ColorToken.action : (isHovered ? DesignSystem.ColorToken.raisedSurface : .clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            if isHovered && !isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignSystem.ColorToken.border.opacity(0.6), lineWidth: DesignSystem.Layout.hairline)
            }
        }
        .padding(.vertical, 2)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onEdit)
        .onHover { hovering in
            withAnimation(.easeOut(duration: DesignSystem.Motion.feedback)) { isHovered = hovering }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct DictionaryRowIconButton: View {
    let systemName: String
    let help: String
    let tint: Color
    let hoverBackground: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(isHovered ? hoverBackground : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovered = $0 }
    }
}

private enum DictionaryEditorFocus: Hashable {
    case source
    case target
    case notes
}

private struct DictionaryEditor: View {
    @ObservedObject var model: AppModel
    @State var draft: DictionaryEntry
    let isNew: Bool
    let onClose: () -> Void

    @State private var warnings: [DictionaryWarning] = []
    @State private var warningsConfirmed = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: DictionaryEditorFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorHeader
                .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DictionaryTypeSelector(selection: $draft.kind)
                        .onChange(of: draft.kind) { _, _ in resetFeedback() }

                    Group {
                        if draft.kind == .correction {
                            HStack(alignment: .bottom, spacing: 10) {
                                LabeledField(title: Copy.heard, isFocused: focusedField == .source) {
                                    TextField(Copy.heard, text: $draft.sourcePhrase)
                                        .focused($focusedField, equals: .source)
                                        .onSubmit {
                                            focusedField = .target
                                        }
                                }
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                                    .padding(.bottom, 12)
                                    .accessibilityHidden(true)
                                LabeledField(title: Copy.written, isFocused: focusedField == .target) {
                                    TextField(Copy.written, text: targetBinding)
                                        .focused($focusedField, equals: .target)
                                        .onSubmit { save() }
                                }
                            }
                        } else {
                            LabeledField(title: Copy.preferredPhrase, isFocused: focusedField == .source) {
                                TextField(Copy.preferredPhrase, text: $draft.sourcePhrase)
                                    .focused($focusedField, equals: .source)
                                    .onSubmit { save() }
                            }
                        }
                    }
                    .animation(.spring(response: DesignSystem.Motion.stateMorph, dampingFraction: 0.85), value: draft.kind)

                    LabeledField(title: String(localized: "dictionary.notes"), isFocused: focusedField == .notes) {
                        TextEditor(text: notesBinding)
                            .font(.system(size: 13, design: .rounded))
                            .frame(minHeight: 96, maxHeight: 150)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .notes)
                    }

                    examplePanel

                    if !errorMessage.isEmpty {
                        errorLabel
                    }
                    if !warnings.isEmpty {
                        warningsPanel
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)

            footer
                .padding(.top, 16)
        }
        .padding(28)
        .background(DesignSystem.ColorToken.background)
        .onAppear {
            // A brand-new rule is immediately typeable.
            if isNew { focusedField = .source }
        }
        .onChange(of: draft.sourcePhrase) { _, _ in resetFeedback() }
        .onChange(of: draft.targetPhrase) { _, _ in resetFeedback() }
    }

    private var editorHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isNew ? String(localized: "dictionary.newRuleTitle") : String(localized: "dictionary.editRuleTitle"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                HStack(spacing: 6) {
                    Circle()
                        .fill(draft.kind == .correction ? DesignSystem.ColorToken.coralIndex : DesignSystem.ColorToken.mossIndex)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(draft.kind == .correction ? Copy.corrections : Copy.vocabulary)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
            }
            Spacer()
            Toggle(Copy.enabled, isOn: $draft.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(DesignSystem.ColorToken.action)
        }
    }

    private var examplePanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.ColorToken.action)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "dictionary.example"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                Text(exampleText)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                .stroke(DesignSystem.ColorToken.border.opacity(0.7), lineWidth: DesignSystem.Layout.hairline)
        }
    }

    private var warningsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(warnings, id: \.message) { warning in
                Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.ColorToken.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if warningsConfirmed {
                Text(String(localized: "dictionary.saveAgainHint"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.ColorToken.warning)
                    .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.ColorToken.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                .stroke(DesignSystem.ColorToken.warning.opacity(0.35), lineWidth: DesignSystem.Layout.hairline)
        }
    }

    private var errorLabel: some View {
        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DesignSystem.ColorToken.failure)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.ColorToken.failure.opacity(0.10), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                    .stroke(DesignSystem.ColorToken.failure.opacity(0.35), lineWidth: DesignSystem.Layout.hairline)
            }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !isNew {
                Button {
                    model.deleteDictionaryEntry(draft)
                    onClose()
                } label: {
                    Label(Copy.delete, systemImage: "trash")
                }
                .buttonStyle(DictionaryDeleteButtonStyle())
                .accessibilityLabel(Copy.delete)
            }
            Spacer()
            Button(Copy.cancel, action: onClose)
                .buttonStyle(DictionarySecondaryButtonStyle())
            Button(Copy.save, action: save)
                .buttonStyle(DictionaryPrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel(Copy.save)
        }
    }

    private var targetBinding: Binding<String> {
        Binding(
            get: { draft.targetPhrase ?? "" },
            set: { draft.targetPhrase = $0 }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { draft.notes ?? "" },
            set: { draft.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var exampleText: String {
        if draft.kind == .correction {
            let heard = draft.sourcePhrase.isEmpty ? Copy.heard : draft.sourcePhrase
            let written: String
            if let target = draft.targetPhrase, !target.isEmpty {
                written = target
            } else {
                written = Copy.written
            }
            return "… \(heard) …  →  … \(written) …"
        }
        return draft.sourcePhrase.isEmpty ? String(localized: "dictionary.exampleVocabulary") : "… \(draft.sourcePhrase) …"
    }

    private func resetFeedback() {
        warnings = []
        warningsConfirmed = false
        errorMessage = ""
    }

    private func save() {
        draft.updatedAt = .now
        do {
            // Validate locally first so a rejected or broad entry never hits
            // the model; a brand-new entry is appended by the model because
            // its id is not in the dictionary yet.
            let pending = try DictionaryValidator.validate(draft, against: model.dictionary.filter { $0.id != draft.id })
            guard pending.isEmpty || warningsConfirmed else {
                // First Save on a broad pattern: surface the advisories and
                // stay open; a second Save confirms and persists.
                warnings = pending
                warningsConfirmed = true
                return
            }
            _ = try model.saveDictionaryEntry(draft)
            onClose()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "dictionary.saveFailed")
            focusFirstInvalidField(for: error)
        }
    }

    private func focusFirstInvalidField(for error: Error) {
        guard let validationError = error as? DictionaryValidationError else { return }
        switch validationError {
        case .emptySource, .vocabularyCannotHaveTarget, .duplicate:
            focusedField = .source
        case .emptyTarget, .correctionRequiresTarget:
            focusedField = .target
        case .unsupportedSchema:
            break
        }
    }
}

private struct DictionaryPrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(DesignSystem.ColorToken.inverseText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DesignSystem.ColorToken.action, in: Capsule())
            .overlay {
                Capsule().fill(.white.opacity(isHovered ? 0.14 : 0))
            }
            .shadow(
                color: DesignSystem.ColorToken.action.opacity(configuration.isPressed ? 0.18 : 0.32),
                radius: configuration.isPressed ? 1.5 : 4,
                y: configuration.isPressed ? 0.5 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.75), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeOut(duration: DesignSystem.Motion.feedback)) { isHovered = hovering }
            }
    }
}

private struct DictionarySecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(DesignSystem.ColorToken.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
            .overlay {
                Capsule().stroke(
                    isHovered ? DesignSystem.ColorToken.primaryText.opacity(0.25) : DesignSystem.ColorToken.border,
                    lineWidth: DesignSystem.Layout.hairline
                )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.75), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeOut(duration: DesignSystem.Motion.feedback)) { isHovered = hovering }
            }
    }
}

private struct DictionaryDeleteButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(DesignSystem.ColorToken.failure)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isHovered ? DesignSystem.ColorToken.failure.opacity(0.14) : .clear, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.75), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeOut(duration: DesignSystem.Motion.feedback)) { isHovered = hovering }
            }
    }
}

private struct DictionaryTypeSelector: View {
    @Binding var selection: DictionaryEntryKind
    @State private var hoveredKind: DictionaryEntryKind?

    var body: some View {
        HStack(spacing: 4) {
            typeButton(Copy.vocabulary, icon: "textformat.abc", kind: .vocabulary)
            typeButton(Copy.corrections, icon: "arrow.triangle.2.circlepath", kind: .correction)
        }
        .padding(4)
        .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.ColorToken.border) }
    }

    private func typeButton(_ title: String, icon: String, kind: DictionaryEntryKind) -> some View {
        Button { selection = kind } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(selection == kind ? DesignSystem.ColorToken.primaryText : (hoveredKind == kind ? DesignSystem.ColorToken.primaryText.opacity(0.85) : DesignSystem.ColorToken.secondaryText))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == kind ? DesignSystem.ColorToken.action.opacity(0.16) : (hoveredKind == kind ? DesignSystem.ColorToken.border.opacity(0.5) : .clear),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: DesignSystem.Motion.feedback)) { hoveredKind = hovering ? kind : nil }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    var isFocused = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            content()
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                        .stroke(
                            isFocused ? DesignSystem.ColorToken.focusRing : DesignSystem.ColorToken.border,
                            lineWidth: isFocused ? 1.5 : DesignSystem.Layout.hairline
                        )
                }
                .shadow(color: isFocused ? DesignSystem.ColorToken.focusRing.opacity(0.16) : .clear, radius: 5)
                .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.8), value: isFocused)
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isFocused ? DesignSystem.ColorToken.focusRing : DesignSystem.ColorToken.secondaryText)
                .padding(.leading, 11)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(.vertical, 9)
                .accessibilityLabel(prompt)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.ColorToken.disabledText)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 9)
                .accessibilityLabel(String(localized: "dictionary.clearSearch"))
                .transition(.opacity)
            }
        }
        .frame(height: 32)
        .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                .stroke(
                    isFocused ? DesignSystem.ColorToken.focusRing : DesignSystem.ColorToken.border,
                    lineWidth: isFocused ? 1.5 : DesignSystem.Layout.hairline
                )
        }
        .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.8), value: isFocused)
    }
}
