//
//  SwipeableCard.swift
//  zigni
//
//  Deslizar izquierda  → flip interactivo al dorso (portada + sinopsis de Google Books)
//  Deslizar derecha    → flip de vuelta al frente
//

import SwiftUI

struct SwipeableCard<Content: View>: View {
    let cardWidth: CGFloat
    let canSwipe: Bool
    let bookTitle: String                           // para buscar en Google Books
    @ViewBuilder let content: () -> Content

    @State private var isFlipped: Bool = false
    @State private var dragDegrees: Double = 0
    @State private var gestureDirection: Bool? = nil

    private var totalDegrees: Double {
        (isFlipped ? -180.0 : 0.0) + dragDegrees
    }
    private var showFront: Bool { abs(totalDegrees) < 90 }

    var body: some View {
        ZStack {
            // ── Dorso: portada + sinopsis ─────────────────────────────
            CardBack(bookTitle: bookTitle, shouldFetch: isFlipped)
                .rotation3DEffect(
                    .degrees(totalDegrees + 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.45
                )
                .opacity(showFront ? 0 : 1)

            // ── Frente: contenido normal ──────────────────────────────
            content()
                .rotation3DEffect(
                    .degrees(totalDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.45
                )
                .opacity(showFront ? 1 : 0)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onChanged { v in
                    guard canSwipe else { return }
                    if gestureDirection == nil {
                        if abs(v.translation.height) > abs(v.translation.width) {
                            gestureDirection = false
                        } else if abs(v.translation.width) > abs(v.translation.height) * 2.0 {
                            gestureDirection = true
                        }
                    }
                    guard gestureDirection == true else { return }
                    let raw = v.translation.width / cardWidth * 180.0
                    dragDegrees = isFlipped ? max(0, raw) : min(0, raw)
                }
                .onEnded { v in
                    guard canSwipe else { return }
                    let wasH = gestureDirection == true
                    gestureDirection = nil
                    guard wasH else { return }
                    let progress = abs(dragDegrees) / 180.0
                    let isFling  = isFlipped ? v.velocity.width > 500 : v.velocity.width < -500
                    if progress > 0.35 || isFling {
                        withAnimation(.spring(duration: 0.55, bounce: 0.38)) {
                            isFlipped.toggle()
                            dragDegrees = 0
                        }
                    } else {
                        withAnimation(.spring(duration: 0.44, bounce: 0.48)) {
                            dragDegrees = 0
                        }
                    }
                }
        )
    }
}

// MARK: - Dorso de la tarjeta ─────────────────────────────────────────────────

private struct CardBack: View {
    let bookTitle: String
    let shouldFetch: Bool

    @State private var bookInfo: BookInfo? = nil
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false

    private let cardBG      = Color(red: 0.10,  green: 0.086, blue: 0.075)
    private let titleColor  = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor  = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let emptyColor  = Color(red: 0.29,  green: 0.251, blue: 0.212)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBG)
                .padding(.horizontal, 18)

            if isLoading {
                ProgressView()
                    .tint(titleColor)

            } else if let info = bookInfo {
                bookContent(info)

            } else if hasLoaded {
                // Buscado pero sin resultado
                Text("sin información")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(emptyColor)
            }
        }
        // Arranca la búsqueda en cuanto la tarjeta se gira (shouldFetch = true)
        .task(id: shouldFetch) {
            guard shouldFetch, !hasLoaded, !bookTitle.isEmpty else { return }
            isLoading = true
            bookInfo  = await BookService.shared.fetch(title: bookTitle)
            isLoading = false
            hasLoaded = true
        }
    }

    @ViewBuilder
    private func bookContent(_ info: BookInfo) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Portada ───────────────────────────────────────
                if let url = info.coverURL {
                    HStack {
                        Spacer()
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 110, maxHeight: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 6)
                            case .failure:
                                EmptyView()
                            default:
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(titleColor.opacity(0.12))
                                    .frame(width: 80, height: 120)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 40)
                } else {
                    Spacer().frame(height: 40)
                }

                // ── Autor ─────────────────────────────────────────
                if !info.authors.isEmpty {
                    Text(info.authors)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundStyle(titleColor)
                        .padding(.top, 22)
                        .padding(.horizontal, 34)
                }

                // Separador
                Rectangle()
                    .fill(titleColor.opacity(0.18))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 12)

                // ── Sinopsis ──────────────────────────────────────
                if !info.description.isEmpty {
                    Text(info.description)
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .foregroundStyle(quoteColor.opacity(0.82))
                        .lineSpacing(5)
                        .padding(.top, 16)
                        .padding(.horizontal, 34)
                        .padding(.bottom, 44)
                }
            }
        }
        // Evita que el scroll interior robe el gesto al carrusel
        .scrollBounceBehavior(.basedOnSize)
    }
}
