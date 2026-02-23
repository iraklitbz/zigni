//
//  SwipeableCard.swift
//  zigni
//
//  Deslizar izquierda  → flip interactivo al dorso (portada + sinopsis de Google Books)
//  Al completar el flip → ContentView expande el dorso a pantalla completa
//  Desde la vista expandida → overscroll abajo → colapsa de vuelta a cara A
//

import SwiftUI

struct SwipeableCard<Content: View>: View {
    let cardWidth: CGFloat
    let canSwipe: Bool
    let bookTitle: String
    @Binding var isFlipped: Bool              // ContentView gestiona este estado
    @ViewBuilder let content: () -> Content

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

// MARK: - Dorso compacto (durante la animación 3D, tamaño de tarjeta)

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
        }
        .task(id: shouldFetch) {
            // Solo precarga la caché; el contenido lo muestra ExpandedCardBack
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

                if !info.authors.isEmpty {
                    Text(info.authors)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundStyle(titleColor)
                        .padding(.top, 22)
                        .padding(.horizontal, 34)
                }

                Rectangle()
                    .fill(titleColor.opacity(0.18))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 12)

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
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Vista expandida a pantalla completa

struct ExpandedCardBack: View {
    let bookTitle: String
    let onDismiss: () -> Void

    @State private var bookInfo: BookInfo? = nil
    @State private var isLoading = false
    @State private var contentVisible = false   // false hasta que la animación de expansión termina
    @State private var hasDismissed = false

    private let cardBG     = Color(red: 0.10,  green: 0.086, blue: 0.075)
    private let titleColor = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let emptyColor = Color(red: 0.29,  green: 0.251, blue: 0.212)

    var body: some View {
        ZStack {
            cardBG.ignoresSafeArea()

            // Contenido solo visible tras la animación de expansión
            if contentVisible {
                if isLoading {
                    ProgressView()
                        .tint(titleColor)
                        .transition(.opacity)
                } else if let info = bookInfo {
                    expandedContent(info)
                        .transition(.opacity)
                } else {
                    Text("sin información")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(emptyColor)
                        .transition(.opacity)
                }
            }
        }
        // Swipe derecha siempre disponible, sin importar el estado del contenido
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { v in
                    guard !hasDismissed else { return }
                    let isHorizontal = abs(v.translation.width) > abs(v.translation.height) * 1.5
                    let isRightSwipe = v.translation.width > 60 || v.velocity.width > 450
                    guard isHorizontal && isRightSwipe else { return }
                    hasDismissed = true
                    onDismiss()
                }
        )
        .task {
            // Esperar a que la animación de expansión termine antes de mostrar nada
            try? await Task.sleep(for: .milliseconds(520))
            guard !hasDismissed else { return }

            // Arrancar fetch y mostrar contenido a la vez
            withAnimation(.easeIn(duration: 0.25)) { isLoading = true }
            withAnimation(.easeIn(duration: 0.25)) { contentVisible = true }

            guard !bookTitle.isEmpty else {
                withAnimation { isLoading = false }
                return
            }

            bookInfo = await BookService.shared.fetch(title: bookTitle)
            withAnimation(.spring(duration: 0.4)) { isLoading = false }
        }
    }

    @ViewBuilder
    private func expandedContent(_ info: BookInfo) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if let url = info.coverURL {
                    HStack {
                        Spacer()
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Color.clear
                            default:
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(titleColor.opacity(0.12))
                            }
                        }
                        .frame(width: 130, height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
                        Spacer()
                    }
                    .padding(.top, 88)
                } else {
                    Spacer().frame(height: 88)
                }

                if !info.authors.isEmpty {
                    Text(info.authors)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundStyle(titleColor)
                        .padding(.top, 26)
                        .padding(.horizontal, 34)
                }

                Rectangle()
                    .fill(titleColor.opacity(0.18))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 14)

                if !info.description.isEmpty {
                    Text(info.description)
                        .font(.system(size: 15, weight: .light, design: .serif))
                        .foregroundStyle(quoteColor.opacity(0.88))
                        .lineSpacing(6)
                        .padding(.top, 20)
                        .padding(.horizontal, 34)
                        // Padding extra al final → el usuario "ve" que puede seguir bajando
                        .padding(.bottom, 120)
                }
            }
        }
        // Siempre permite bounce para que el overscroll sea detectado
        .scrollBounceBehavior(.always)
        // Detecta overscroll al final para contenido largo Y corto.
        // Para contenido corto, hay un "overscroll natural en reposo" = containerSize - contentSize
        // que hay que restar para medir solo el desplazamiento real del usuario.
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            let rawOverscroll   = geo.contentOffset.y + geo.containerSize.height - geo.contentSize.height
            let naturalAtRest   = max(0, geo.containerSize.height - geo.contentSize.height)
            return rawOverscroll - naturalAtRest
        } action: { _, overscroll in
            guard !hasDismissed, overscroll > 60 else { return }
            hasDismissed = true
            onDismiss()
        }
    }
}
