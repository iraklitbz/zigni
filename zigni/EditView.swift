//
//  EditView.swift
//  zigni
//

import SwiftUI

struct EditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Quote
    let onSave: (Quote) -> Void

    // Paleta (misma que CardView para consistencia)
    private let bgColor     = Color(red: 0.071, green: 0.059, blue: 0.051)
    private let titleColor  = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor  = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let dimColor    = Color(red: 0.29,  green: 0.251, blue: 0.212)

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

                // ── Campo: texto de la cita ───────────────────────
                TextEditor(text: $draft.text)
                    .font(.system(size: 19, weight: .light, design: .serif))
                    .foregroundStyle(quoteColor)
                    .tint(titleColor)
                    .lineSpacing(7)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 29)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
            }
        }
        // Hace que el teclado suba sin empujar la pantalla de golpe
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    EditView(quote: Quote(bookTitle: "Siddhartha", text: "")) { _ in }
}
