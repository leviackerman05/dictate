import DictateCore
import SwiftUI

struct DictionaryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedID: UUID?
    @State private var draft: DictionaryEntry?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.space3) {
                HStack {
                    Text(Copy.dictionary)
                        .font(.system(.title, design: .serif))
                    Spacer()
                    Button { beginNew() } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Copy.addEntry)
                }
                TextField(Copy.searchDictionary, text: $model.dictionarySearch)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $model.dictionaryFilter) {
                    Text(Copy.all).tag(DictionaryEntryKind?.none)
                    Text(Copy.vocabulary).tag(DictionaryEntryKind?.some(.vocabulary))
                    Text(Copy.corrections).tag(DictionaryEntryKind?.some(.correction))
                }
                .pickerStyle(.segmented)
                if !model.dictionaryNotice.isEmpty {
                    Text(model.dictionaryNotice)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
                List(selection: $selectedID) {
                    ForEach(model.filteredDictionary) { entry in
                        DictionaryRow(entry: entry)
                            .tag(entry.id)
                            .contextMenu {
                                Button(entry.isEnabled ? String(localized: "dictionary.disable") : String(localized: "dictionary.enable")) {
                                    model.setDictionaryEnabled(!entry.isEnabled, for: entry)
                                }
                                Button(Copy.delete, role: .destructive) { model.deleteDictionaryEntry(entry) }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(DesignSystem.Layout.space6)
            .frame(minWidth: DesignSystem.Layout.dictionaryColumnMinWidth, idealWidth: DesignSystem.Layout.dictionaryColumnIdealWidth, maxWidth: DesignSystem.Layout.dictionaryColumnMaxWidth)
            .background(DesignSystem.ColorToken.canvas)

            Divider().overlay(DesignSystem.ColorToken.hairline)

            Group {
                if let draft {
                    DictionaryEditor(model: model, draft: draft, onClose: { self.draft = nil })
                } else {
                    Text(String(localized: "dictionary.selectPrompt"))
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(DesignSystem.ColorToken.surface)
        }
        .onChange(of: selectedID) { _, newValue in
            draft = newValue.flatMap { id in model.dictionary.first(where: { $0.id == id }) }
        }
        .onChange(of: model.dictionary) { _, entries in
            if let id = selectedID { draft = entries.first(where: { $0.id == id }) }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button(String(localized: "dictionary.importReplace")) { model.importDictionary(merge: false) }
                    Button(String(localized: "dictionary.importMerge")) { model.importDictionary(merge: true) }
                    Divider()
                    Button(String(localized: "dictionary.export")) { model.exportDictionary() }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel(String(localized: "dictionary.moreActions"))
            }
        }
    }

    private func beginNew() {
        let entry = DictionaryEntry.vocabulary("")
        selectedID = entry.id
        draft = entry
    }
}

private struct DictionaryRow: View {
    let entry: DictionaryEntry

    var body: some View {
        HStack(spacing: DesignSystem.Layout.space2) {
            Circle()
                .fill(entry.isEnabled ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.hairline)
                .frame(width: DesignSystem.Layout.space2, height: DesignSystem.Layout.space2)
            VStack(alignment: .leading, spacing: DesignSystem.Layout.space1) {
                Text(entry.sourcePhrase.isEmpty ? String(localized: "dictionary.untitled") : entry.sourcePhrase)
                    .foregroundStyle(entry.isEnabled ? DesignSystem.ColorToken.ink : DesignSystem.ColorToken.mutedInk)
                if let target = entry.targetPhrase {
                    Text("→ \(target)")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
            }
        }
        .padding(.vertical, DesignSystem.Layout.space2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(entry.kind == .correction ? Copy.corrections : Copy.vocabulary)
    }
}

private struct DictionaryEditor: View {
    @ObservedObject var model: AppModel
    @State var draft: DictionaryEntry
    let onClose: () -> Void
    @State private var warnings: [DictionaryWarning] = []
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "dictionary.entryType"), selection: $draft.kind) {
                    Text(Copy.vocabulary).tag(DictionaryEntryKind.vocabulary)
                    Text(Copy.corrections).tag(DictionaryEntryKind.correction)
                }
                .pickerStyle(.segmented)

                if draft.kind == .correction {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Layout.space3) {
                        TextField(Copy.heard, text: $draft.sourcePhrase)
                            .textFieldStyle(.roundedBorder)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                            .accessibilityHidden(true)
                        TextField(Copy.written, text: Binding(
                            get: { draft.targetPhrase ?? "" },
                            set: { draft.targetPhrase = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                } else {
                    TextField(Copy.preferredPhrase, text: $draft.sourcePhrase)
                        .textFieldStyle(.roundedBorder)
                }
                Toggle(Copy.enabled, isOn: $draft.isEnabled)
            } header: {
                Text(String(localized: "dictionary.entry"))
            }

            Section(String(localized: "dictionary.example")) {
                Text(exampleText)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(DesignSystem.ColorToken.ink)
                    .frame(maxWidth: DesignSystem.Layout.transcriptMeasure, alignment: .leading)
                if !warnings.isEmpty {
                    ForEach(warnings, id: \.message) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                            .font(.caption)
                    }
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(DesignSystem.ColorToken.recording)
                        .font(.caption)
                }
            }

            Section {
                HStack {
                    Button(Copy.save) { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.ColorToken.action)
                    Button(Copy.cancel, action: onClose)
                    Spacer()
                    Button(Copy.delete, role: .destructive) {
                        model.deleteDictionaryEntry(draft)
                        onClose()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(DesignSystem.Layout.space6)
        .onChange(of: draft.kind) { _, _ in warnings = [] }
        .onChange(of: draft.sourcePhrase) { _, _ in warnings = [] }
    }

    private var exampleText: String {
        if draft.kind == .correction {
            let heard = draft.sourcePhrase.isEmpty ? Copy.heard : draft.sourcePhrase
            let written = draft.targetPhrase?.isEmpty == false ? draft.targetPhrase! : Copy.written
            return "… \(heard) …  →  … \(written) …"
        }
        return draft.sourcePhrase.isEmpty ? String(localized: "dictionary.exampleVocabulary") : "… \(draft.sourcePhrase) …"
    }

    private func save() {
        draft.updatedAt = .now
        do {
            warnings = try model.saveDictionaryEntry(draft)
            onClose()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "dictionary.saveFailed")
        }
    }
}
