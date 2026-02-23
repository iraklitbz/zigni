//
//  ContentView.swift
//  zigni
//

import SwiftUI

struct ContentView: View {
    @State private var store       = QuotesStore()
    @State private var editingQuote: Quote? = nil
    @State private var newQuoteID: Quote.ID? = nil
    @State private var scrolledID: Quote.ID? = nil
    @State private var draftHolder = DraftQuote()
    @State private var hasLaunched = false
    @State private var focusNewTitle = false

    // ── Flip / expansión del dorso ────────────────────────────────────
    @State private var flippedCardID: Quote.ID? = nil   // qué tarjeta está girada
    @State private var expandedCardID: Quote.ID? = nil  // qué tarjeta está expandida a pantalla completa

    // ── Modo edición ──────────────────────────────────────────────────
    @State private var editingIsNew = false

    private let bgColor     = Color(red: 0.071, green: 0.059, blue: 0.051)
    private let accentColor = Color(red: 0.48,  green: 0.384, blue: 0.282)

    var body: some View {
        // ignoresSafeArea aquí para que geo.size.height = pantalla completa
        GeometryReader { geo in
            let cardH = geo.size.height * 0.84

            ZStack {
                bgColor.ignoresSafeArea()

                // ── Carrusel ──────────────────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(store.quotes) { quote in
                            SwipeableCard(
                                cardWidth: geo.size.width,
                                canSwipe: quote.id != newQuoteID,
                                bookTitle: quote.bookTitle,
                                isFlipped: flipBinding(for: quote.id)
                            ) {
                                if quote.id == newQuoteID {
                                    EditableCardView(
                                        draft: draftHolder,
                                        existingTitles: store.existingTitles.filter { !$0.isEmpty }
                                    )
                                } else {
                                    CardView(quote: quote)
                                        .onTapGesture {
                                            if let id = newQuoteID { commitOrDelete(id: id) }
                                            editingIsNew = false
                                            focusNewTitle = false
                                            editingQuote = quote
                                        }
                                }
                            }
                            .frame(height: cardH)
                            .scrollTransition(
                                .animated(.spring(duration: 0.48, bounce: 0.38))
                            ) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.84)
                                    .opacity(phase.isIdentity ? 1.0 : 0.38)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrolledID)
                .contentMargins(
                    .vertical,
                    (geo.size.height - cardH) / 2,
                    for: .scrollContent
                )
                // El ScrollView ocupa toda la pantalla incluidas safe areas
                .ignoresSafeArea()

                // ── Degradados: capas independientes que cubren la pantalla entera ──
                // Así no hay corte visual en el notch ni en el home indicator
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [bgColor, bgColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 130)
                    Spacer()
                    LinearGradient(
                        colors: [bgColor.opacity(0), bgColor],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 130)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // ── Dorso expandido a pantalla completa ───────────────
                if let eid = expandedCardID,
                   let eq  = store.quotes.first(where: { $0.id == eid }) {
                    ExpandedCardBack(bookTitle: eq.bookTitle) {
                        withAnimation(.spring(duration: 0.55, bounce: 0.3)) {
                            flippedCardID  = nil
                            expandedCardID = nil
                        }
                    }
                    .ignoresSafeArea()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.88, anchor: .center).combined(with: .opacity),
                        removal:   .scale(scale: 0.88, anchor: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(10)
                }

                // ── Botón "+" ─────────────────────────────────────────
                if newQuoteID == nil && editingQuote == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button { enterCreateMode(focusTitle: true) } label: {
                                Text("+")
                                    .font(.system(size: 30, weight: .ultraLight))
                                    .foregroundStyle(accentColor)
                                    .frame(width: 48, height: 48)
                            }
                            .padding(.bottom, 52)
                            .padding(.trailing, 32)
                        }
                    }
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        // Arranque en frío: esperamos un poco más para que el scroll esté listo
        .onAppear {
            guard !hasLaunched else { return }
            hasLaunched = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                enterCreateMode(focusTitle: true)
            }
        }
        // Cuando una tarjeta se gira al dorso → esperamos a que el flip 3D casi termine
        // y entonces expandimos a pantalla completa
        .onChange(of: flippedCardID) { _, newID in
            if let newID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    guard flippedCardID == newID else { return }
                    withAnimation(.spring(duration: 0.48, bounce: 0.22)) {
                        expandedCardID = newID
                    }
                }
            } else {
                withAnimation(.spring(duration: 0.38)) {
                    expandedCardID = nil
                }
            }
        }
        .onChange(of: scrolledID) { _, newID in
            guard let createID = newQuoteID, newID != createID else { return }
            commitOrDelete(id: createID)
        }
        .sheet(item: $editingQuote) { quote in
            EditView(quote: quote, focusOnAppear: focusNewTitle, isNewQuote: editingIsNew) { updated in
                let titleEmpty = updated.bookTitle.trimmingCharacters(in: .whitespaces).isEmpty
                let passagesEmpty = updated.passages.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                if titleEmpty && passagesEmpty {
                    store.delete(updated)
                } else {
                    store.update(updated)
                }
            }
            .presentationBackground(bgColor)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .onDisappear {
                focusNewTitle = false
            }
        }
    }

    // MARK: - Flip binding

    private func flipBinding(for id: Quote.ID) -> Binding<Bool> {
        Binding(
            get: { flippedCardID == id },
            set: { flippedCardID = $0 ? id : nil }
        )
    }

    // MARK: - Modo creación

    private func enterCreateMode(focusTitle: Bool = false) {
        focusNewTitle = focusTitle
        editingIsNew = true
        let q = store.addQuote()
        editingQuote = q
    }

    private func commitOrDelete(id: Quote.ID) {
        defer { newQuoteID = nil }
        guard let q = store.quotes.first(where: { $0.id == id }) else { return }
        if draftHolder.isEmpty {
            store.delete(q)
        } else {
            store.delete(q)
            store.mergeOrCreate(title: draftHolder.bookTitle, text: draftHolder.text)
        }
    }
}

#Preview {
    ContentView()
}
