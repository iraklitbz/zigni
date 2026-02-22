//
//  EditView.swift
//  zigni
//

import SwiftUI

struct EditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Quote
    let onSave: (Quote) -> Void

    // Paleta
    private let bgColor     = Color(red: 0.071, green: 0.059, blue: 0.051)
    private let titleColor  = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor  = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let accentColor = Color(red: 0.48,  green: 0.384, blue: 0.282)

    init(quote: Quote, onSave: @escaping (Quote) -> Void) {
        _draft = State(initialValue: quote)
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Botón "listo" (esquina superior derecha) ──────
                HStack {
                    Spacer()
                    Button {
                        onSave(draft)
                        dismiss()
                    } label: {
                        Text("listo")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(titleColor)
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 34)
                }

                // ── Campo: título del libro ───────────────────────
                TextField("título del libro", text: $draft.bookTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(titleColor)
                    .tint(titleColor)
                    .padding(.top, 28)
                    .padding(.horizontal, 34)

                Rectangle()
                    .fill(titleColor.opacity(0.22))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 14)

                // ── Pasajes (todos editables) ─────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(draft.passages.enumerated()), id: \.element.id) { index, _ in
                            if index > 0 {
                                Rectangle()
                                    .fill(titleColor.opacity(0.12))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 34)
                                    .padding(.vertical, 24)
                            }
                            TextEditor(text: $draft.passages[index].text)
                                .scrollDisabled(true)
                                .font(.system(size: 19, weight: .light, design: .serif))
                                .foregroundStyle(quoteColor)
                                .tint(titleColor)
                                .lineSpacing(7)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 80)
                                .padding(.horizontal, 29)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            // ── Botón añadir pasaje (flota abajo a la derecha) ────
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        draft.passages.append(Passage())
                        draft.updatedAt = Date()
                    } label: {
                        Text("+")
                            .font(.system(size: 30, weight: .ultraLight))
                            .foregroundStyle(accentColor)
                            .frame(width: 48, height: 48)
                    }
                    .padding(.bottom, 52)
                    .padding(.trailing, 32)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    EditView(quote: Quote(bookTitle: "Siddhartha", text: "La sabiduría no puede transmitirse.")) { _ in }
}
