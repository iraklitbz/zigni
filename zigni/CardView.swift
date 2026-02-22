//
//  CardView.swift
//  zigni
//

import SwiftUI

struct CardView: View {
    let quote: Quote

    // Paleta
    private let cardBG      = Color(red: 0.11, green: 0.094, blue: 0.082)
    private let titleColor  = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor  = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let emptyColor  = Color(red: 0.29,  green: 0.251, blue: 0.212)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBG)

            VStack(alignment: .leading, spacing: 0) {

                // ── Título del libro ──────────────────────────────
                Text(quote.bookTitle.isEmpty ? "título del libro" : quote.bookTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(quote.bookTitle.isEmpty ? emptyColor : titleColor)
                    .padding(.top, 38)
                    .padding(.horizontal, 34)

                // Línea separadora sutil
                Rectangle()
                    .fill(titleColor.opacity(0.18))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 14)

                Spacer()

                // ── Texto de la cita ──────────────────────────────
                Text(quote.text.isEmpty ? "toca para escribir tu cita…" : quote.text)
                    .font(.system(size: 19, weight: .light, design: .serif))
                    .foregroundStyle(quote.text.isEmpty ? emptyColor : quoteColor)
                    .lineSpacing(7)
                    .lineLimit(5)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 46)
            }
        }
        .padding(.horizontal, 18)
    }
}

#Preview {
    ZStack {
        Color(red: 0.071, green: 0.059, blue: 0.051).ignoresSafeArea()
        CardView(quote: Quote(
            bookTitle: "El principito",
            text: "Lo esencial es invisible a los ojos. Solo se ve bien con el corazón.",
            createdAt: Date()
        ))
        .frame(height: 560)
    }
}
