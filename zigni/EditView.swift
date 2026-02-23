//
//  EditView.swift
//  zigni
//

import SwiftUI
import UIKit

// MARK: - Preference key para capturar frames de cada passage
private struct PassageFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct EditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Quote
    @FocusState private var titleFocused: Bool
    let focusOnAppear: Bool
    let onSave: (Quote) -> Void

    // Paleta
    private let bgColor     = Color(red: 0.071, green: 0.059, blue: 0.051)
    private let cardBg      = Color(red: 0.11,  green: 0.094, blue: 0.082)
    private let titleColor  = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor  = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let accentColor = Color(red: 0.48,  green: 0.384, blue: 0.282)

    // ── Modo selección ────────────────────────────────────────────────
    @State private var selectedPassageID: UUID? = nil
    @State private var dragOffset: [UUID: CGFloat] = [:]
    @State private var showDeleteConfirm = false

    // ── Reordenación ──────────────────────────────────────────────────
    @State private var reorderingID: UUID? = nil
    @State private var reorderDragY: CGFloat = 0
    @State private var passageFrames: [UUID: CGRect] = [:]

    init(quote: Quote, focusOnAppear: Bool = false, onSave: @escaping (Quote) -> Void) {
        _draft = State(initialValue: quote)
        self.focusOnAppear = focusOnAppear
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Barra superior ────────────────────────────────────
                HStack {
                    Spacer()
                    if selectedPassageID != nil {
                        // OK reemplaza "listo" en modo selección
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedPassageID = nil
                                showDeleteConfirm = false
                            }
                        } label: {
                            Text("ok")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(bgColor)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(titleColor))
                        }
                        .padding(.trailing, 34)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Button {
                            onSave(draft)
                            dismiss()
                        } label: {
                            Text("listo")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(titleColor)
                        }
                        .padding(.trailing, 34)
                        .transition(.opacity)
                    }
                }
                .padding(.top, 58)
                .animation(.spring(duration: 0.3), value: selectedPassageID)

                // ── Campo: título del libro ───────────────────────────
                TextField("título del libro", text: $draft.bookTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(titleColor)
                    .tint(titleColor)
                    .focused($titleFocused)
                    .disabled(selectedPassageID != nil)
                    .padding(.top, 28)
                    .padding(.horizontal, 34)

                Rectangle()
                    .fill(titleColor.opacity(0.22))
                    .frame(height: 0.5)
                    .padding(.horizontal, 34)
                    .padding(.top, 14)

                // ── Pasajes ───────────────────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(draft.passages.enumerated()), id: \.element.id) { index, passage in
                            if index > 0 {
                                Rectangle()
                                    .fill(titleColor.opacity(0.12))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 34)
                                    .padding(.vertical, 24)
                            }
                            passageRow(passage: passage, index: index)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onPreferenceChange(PassageFrameKey.self) { frames in
                    passageFrames = frames
                }
            }

            // ── Botón añadir pasaje ───────────────────────────────────
            if selectedPassageID == nil && reorderingID == nil {
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
                .transition(.opacity)
            }

            // ── Notch de eliminar ─────────────────────────────────────
            if selectedPassageID != nil {
                VStack {
                    Spacer()
                    deleteNotch
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: selectedPassageID)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            guard focusOnAppear else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                titleFocused = true
            }
        }
    }

    // MARK: - Passage Row

    @ViewBuilder
    private func passageRow(passage: Passage, index: Int) -> some View {
        let isSelected   = selectedPassageID == passage.id
        let isReordering = reorderingID == passage.id
        let xOffset      = dragOffset[passage.id] ?? 0
        // Cuando hay offset activo o está seleccionada, mostramos Text (SwiftUI nativo)
        // para que el offset/transform funcione correctamente (UITextView no sigue transforms).
        let isDragging   = xOffset != 0

        ZStack(alignment: .leading) {

            // ── Fondo de selección ────────────────────────────────────
            if isSelected {
                // Fondo
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.08))
                    .padding(.horizontal, 24)
                // Borde izquierdo — separado para no romper el padding del fondo
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2)
                    .padding(.leading, 24)
            }

            // ── Contenido de texto ────────────────────────────────────
            // Cuando está seleccionada o deslizando: Text nativo (sigue el offset sin glitches).
            // En reposo: TextEditor editable.
            if isSelected || isDragging {
                Text(passage.text.isEmpty ? " " : passage.text)
                    .font(.system(size: 19, weight: .light, design: .serif))
                    .foregroundStyle(quoteColor)
                    .lineSpacing(7)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                    .padding(.leading, isSelected ? 42 : 29)   // aire extra desde el borde izquierdo
                    .padding(.trailing, 29)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            } else {
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
        // Capturar frame ANTES del offset (posición de layout real)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: PassageFrameKey.self,
                    value: [passage.id: geo.frame(in: .global)]
                )
            }
        )
        .scaleEffect(isReordering ? 1.02 : 1.0)
        .shadow(color: isReordering ? accentColor.opacity(0.15) : .clear, radius: 8)
        // Un solo offset para swipe horizontal + reorder vertical
        .offset(x: xOffset, y: isReordering ? reorderDragY : 0)
        // ── Gestos ───────────────────────────────────────────────────
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard reorderingID == nil else { return }
                    // Permitir swipe solo si: nada seleccionado, o esta misma frase está seleccionada
                    guard selectedPassageID == nil || selectedPassageID == passage.id else { return }
                    if value.translation.width < 0 {
                        dragOffset[passage.id] = value.translation.width
                    }
                }
                .onEnded { _ in
                    guard reorderingID == nil else { return }
                    let offset = dragOffset[passage.id] ?? 0
                    if selectedPassageID == passage.id {
                        // Swipe sobre la frase ya seleccionada → deseleccionar
                        haptic(.soft)
                        withAnimation(.spring(duration: 0.3)) {
                            selectedPassageID = nil
                            showDeleteConfirm = false
                        }
                    } else if selectedPassageID == nil && offset < -50 {
                        haptic(.soft)
                        withAnimation(.spring(duration: 0.3)) {
                            selectedPassageID = passage.id
                            draft.featuredPassageID = passage.id
                            showDeleteConfirm = false
                        }
                    }
                    withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                        dragOffset[passage.id] = 0
                    }
                }
        )
        .simultaneousGesture(
            reorderingID == nil && selectedPassageID == nil
            ? LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    haptic(.medium)
                    withAnimation(.spring(duration: 0.3)) {
                        reorderingID = passage.id
                        reorderDragY = 0
                    }
                }
            : nil
        )
        .simultaneousGesture(
            reorderingID == passage.id
            ? DragGesture()
                .onChanged { value in
                    reorderDragY = value.translation.height
                    checkReorderCrossing(for: passage)
                }
                .onEnded { _ in
                    haptic(.soft)
                    withAnimation(.spring(duration: 0.3)) {
                        reorderingID = nil
                        reorderDragY = 0
                    }
                }
            : nil
        )
        .zIndex(isReordering ? 1 : 0)
        .animation(.spring(duration: 0.3), value: isSelected)
        .animation(.spring(duration: 0.25), value: isReordering)
    }

    // MARK: - Delete Notch

    private var deleteNotch: some View {
        ZStack(alignment: .bottom) {
            // Tooltip de confirmación — flota sobre el notch
            if showDeleteConfirm {
                VStack(spacing: 10) {
                    Text("¿Seguro que deseas\neliminar este quote?")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(quoteColor.opacity(0.85))

                    Button {
                        deleteSelectedPassage()
                    } label: {
                        Text("Eliminar")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBg)
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
                )
                .offset(y: -60)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
            }

            // El notch en sí
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    showDeleteConfirm.toggle()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(showDeleteConfirm ? Color.red.opacity(0.5) : Color.red)
                    .frame(width: 64, height: 46)
            }
            .background(
                RoundedRectangle(cornerRadius: 23)
                    .fill(cardBg)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
            )
        }
        .padding(.bottom, 44)
    }

    // MARK: - Helpers

    private func deleteSelectedPassage() {
        guard let id = selectedPassageID else { return }
        haptic(.rigid)
        withAnimation(.spring(duration: 0.3)) {
            draft.passages.removeAll { $0.id == id }
            if draft.featuredPassageID == id {
                draft.featuredPassageID = nil
            }
            selectedPassageID = nil
            showDeleteConfirm = false
        }
    }

    private func checkReorderCrossing(for passage: Passage) {
        guard let currentFrame = passageFrames[passage.id] else { return }
        let centerY = currentFrame.midY + reorderDragY

        for other in draft.passages where other.id != passage.id {
            guard let otherFrame = passageFrames[other.id] else { continue }
            if centerY > otherFrame.minY && centerY < otherFrame.maxY {
                if let fromIdx = draft.passages.firstIndex(where: { $0.id == passage.id }),
                   let toIdx   = draft.passages.firstIndex(where: { $0.id == other.id }) {
                    selectionHaptic()
                    withAnimation(.spring(duration: 0.25)) {
                        draft.passages.swapAt(fromIdx, toIdx)
                    }
                }
                break
            }
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func selectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

#Preview {
    EditView(quote: Quote(bookTitle: "Siddhartha", text: "La sabiduría no puede transmitirse.")) { _ in }
}
