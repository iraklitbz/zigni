//
//  EditableCardView.swift
//  zigni
//

import SwiftUI
import Observation

// Guarda el borrador en memoria sin re-renderizar ContentView en cada tecla
@Observable
final class DraftQuote {
    var bookTitle: String = ""
    var text: String = ""

    var isEmpty: Bool {
        bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func reset() {
        bookTitle = ""
        text = ""
    }
}

// Tarjeta con campos de texto activos (modo creación inline)
struct EditableCardView: View {
    @Bindable var draft: DraftQuote
    @FocusState private var focused: Field?

    private let cardBG     = Color(red: 0.11,  green: 0.094, blue: 0.082)
    private let titleColor = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let emptyColor = Color(red: 0.29,  green: 0.251, blue: 0.212)

    enum Field { case title, text }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBG)

            VStack(alignment: .leading, spacing: 0) {

                // ── Título del libro ──────────────────────────────
                TextField("título del libro", text: $draft.bookTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(titleColor)
                    .tint(titleColor)
                    .focused($focused, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focused = .text }
                    .padding(.top, 38)
                    .padding(.horizontal, 34)

                Rectangle()
                    .fill(titleColor.opacity(0.18))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 14)

                Spacer()

                // ── Texto de la cita (con placeholder manual) ────
                ZStack(alignment: .topLeading) {
                    if draft.text.isEmpty {
                        Text("escribe tu cita aquí…")
                            .font(.system(size: 19, weight: .light, design: .serif))
                            .foregroundStyle(emptyColor)
                            .lineSpacing(7)
                            .allowsHitTesting(false)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $draft.text)
                        .font(.system(size: 19, weight: .light, design: .serif))
                        .foregroundStyle(quoteColor)
                        .tint(titleColor)
                        .lineSpacing(7)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($focused, equals: .text)
                }
                .padding(.horizontal, 29)
                .padding(.bottom, 46)
            }
        }
        .padding(.horizontal, 18)
        .onAppear {
            // Esperamos un poco para que el scroll se asiente antes de subir el teclado
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                focused = .text
            }
        }
    }
}
