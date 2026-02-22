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
    @State private var deletingID: Quote.ID? = nil

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
                                onDeleteTriggered: {
                                    handleDelete(quote: quote, cardH: cardH)
                                }
                            ) {
                                if quote.id == newQuoteID {
                                    EditableCardView(draft: draftHolder)
                                } else {
                                    CardView(quote: quote)
                                        .onTapGesture {
                                            if let id = newQuoteID { commitOrDelete(id: id) }
                                            editingQuote = quote
                                        }
                                }
                            }
                            .frame(height: quote.id == deletingID ? 0 : cardH)
                            .clipped()
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

                // ── Botón "+" ─────────────────────────────────────────
                if newQuoteID == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button { enterCreateMode() } label: {
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
        .onAppear {
            guard !hasLaunched else { return }
            hasLaunched = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                enterCreateMode()
            }
        }
        .onChange(of: scrolledID) { _, newID in
            guard let createID = newQuoteID, newID != createID else { return }
            commitOrDelete(id: createID)
        }
        .sheet(item: $editingQuote) { quote in
            EditView(quote: quote) { updated in store.update(updated) }
                .presentationBackground(bgColor)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
    }

    // MARK: - Borrado

    private func handleDelete(quote: Quote, cardH: CGFloat) {
        withAnimation(.spring(duration: 0.32, bounce: 0.08)) {
            deletingID = quote.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            store.delete(quote)
            deletingID = nil
        }
    }

    // MARK: - Modo creación

    private func enterCreateMode() {
        draftHolder.reset()
        let q = store.addQuote()
        newQuoteID = q.id
        withAnimation(.spring(duration: 0.5)) { scrolledID = q.id }
    }

    private func commitOrDelete(id: Quote.ID) {
        defer { newQuoteID = nil }
        guard let q = store.quotes.first(where: { $0.id == id }) else { return }
        if draftHolder.isEmpty {
            store.delete(q)
        } else {
            var saved = q
            saved.bookTitle = draftHolder.bookTitle
            saved.text      = draftHolder.text
            store.update(saved)
        }
    }
}

#Preview {
    ContentView()
}
