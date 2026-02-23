//
//  EditView.swift
//  zigni
//

import SwiftUI
import UIKit
import VisionKit

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
    @FocusState private var focusedPassageID: UUID?
    let focusOnAppear: Bool
    let isNewQuote: Bool
    let onSave: (Quote) -> Void

    // Paleta
    private let bgColor     = Color(red: 0.071, green: 0.059, blue: 0.051)
    private let cardBg      = Color(red: 0.11,  green: 0.094, blue: 0.082)
    private let titleColor  = Color(red: 0.58,  green: 0.472, blue: 0.333)
    private let quoteColor  = Color(red: 0.918, green: 0.890, blue: 0.847)
    private let accentColor = Color(red: 0.48,  green: 0.384, blue: 0.282)

    // ── Teclado ───────────────────────────────────────────────────────
    @State private var keyboardVisible = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var clipboardText: String? = nil

    // ── Escáner de cámara ─────────────────────────────────────────────
    @State private var showScanner = false

    // ── Geometría ─────────────────────────────────────────────────────
    @State private var screenWidth: CGFloat = 390

    // ── Modo selección (multi) ─────────────────────────────────────────
    @State private var selectedPassageIDs: Set<UUID> = []
    @State private var dragOffset: [UUID: CGFloat] = [:]
    @State private var showDeleteConfirm = false

    // ── Reordenación ──────────────────────────────────────────────────
    @State private var reorderingID: UUID? = nil
    @State private var reorderDragY: CGFloat = 0
    @State private var passageFrames: [UUID: CGRect] = [:]

    init(quote: Quote, focusOnAppear: Bool = false, isNewQuote: Bool = false, onSave: @escaping (Quote) -> Void) {
        _draft = State(initialValue: quote)
        self.focusOnAppear = focusOnAppear
        self.isNewQuote = isNewQuote
        self.onSave = onSave
    }

    private var focusedPassageIsEmpty: Bool {
        guard let id = focusedPassageID else { return true }
        return draft.passages.first(where: { $0.id == id })?
            .text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Barra superior ────────────────────────────────────
                HStack {
                    // Cámara — solo cuando hay un pasaje enfocado y está vacío
                    if selectedPassageIDs.isEmpty && DataScannerViewController.isSupported
                        && focusedPassageID != nil && focusedPassageIsEmpty {
                        Button { showScanner = true } label: {
                            Image(systemName: "camera")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(titleColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(titleColor.opacity(0.10)))
                        }
                        .padding(.leading, 34)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Spacer().frame(width: 34)
                    }

                    Spacer()

                    if !selectedPassageIDs.isEmpty {
                        // Modo selección → ok
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedPassageIDs.removeAll()
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
                    } else if keyboardVisible {
                        // Teclado visible → bajar teclado
                        Button {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(bgColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(titleColor))
                        }
                        .padding(.trailing, 34)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        // Reposo → listo
                        Button {
                            removeEmptyPassages()
                            onSave(draft)
                            dismiss()
                        } label: {
                            Text("listo")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(titleColor)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                        }
                        .padding(.trailing, 18)
                        .transition(.opacity)
                    }
                }
                .frame(height: 36)
                .padding(.top, 58)
                .animation(.spring(duration: 0.3), value: selectedPassageIDs.isEmpty)
                .animation(.spring(duration: 0.3), value: keyboardVisible)

                // ── Campo: título del libro ───────────────────────────
                TextField("título del libro", text: $draft.bookTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(titleColor)
                    .tint(titleColor)
                    .focused($titleFocused)
                    .disabled(!selectedPassageIDs.isEmpty)
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

            // ── Barra de pegar (clipboard) ────────────────────────────
            if let clip = clipboardText, keyboardVisible, focusedPassageIsEmpty {
                VStack {
                    Spacer()
                    pasteBar(clip)
                }
                .padding(.bottom, keyboardHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.35), value: clipboardText != nil)
            }

            // ── Botón añadir pasaje ───────────────────────────────────
            if selectedPassageIDs.isEmpty && reorderingID == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            let newPassage = Passage()
                            draft.passages.append(newPassage)
                            draft.updatedAt = Date()
                            let newID = newPassage.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                focusedPassageID = newID
                            }
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
            if !selectedPassageIDs.isEmpty {
                VStack {
                    Spacer()
                    deleteNotch
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: selectedPassageIDs.isEmpty)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        .fullScreenCover(isPresented: $showScanner) {
            DataScannerView { scanned in
                showScanner = false
                handleScannedText(scanned)
            }
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
            if let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
            keyboardVisible = true
            if isNewQuote { checkClipboard() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            keyboardVisible = false
            withAnimation(.spring(duration: 0.3)) { clipboardText = nil }
        }
        .onAppear {
            if focusOnAppear {
                if draft.passages.isEmpty { draft.passages.append(Passage()) }
                let firstID = draft.passages.first?.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focusedPassageID = firstID
                }
            }
            // Sin UITextView en el árbol al abrir (swap Text/TextEditor) → sin auto-focus.
        }
    }

    // MARK: - Passage Row

    @ViewBuilder
    private func passageRow(passage: Passage, index: Int) -> some View {
        let isSelected   = selectedPassageIDs.contains(passage.id)
        let isReordering = reorderingID == passage.id
        let xOffset      = dragOffset[passage.id] ?? 0
        let isDragging   = xOffset != 0
        let threshold    = screenWidth * 0.20

        // ── Exterior fijo: sombra color titleColor (nunca se mueve) ──────
        // ── Interior deslizante: bgColor cubre la sombra en reposo ───────
        ZStack(alignment: .leading) {
            // Sombra fija — mismo color que el botón ok
            titleColor

            // Interior deslizante
            ZStack(alignment: .leading) {
                // Mismo color que pantalla → invisible en reposo
                bgColor

                // Tinte sutil de selección
                if isSelected {
                    accentColor.opacity(0.07)
                }

                // Tinte reordenación — color del botón ok
                if isReordering {
                    titleColor.opacity(0.12)
                }

                // Radio button + texto en HStack
                // El radio button siempre ocupa su espacio (no hay reflow al seleccionar)
                HStack(alignment: .center, spacing: 20) {
                    let isFocused = focusedPassageID == passage.id

                    ZStack(alignment: .leading) {
                        // TextEditor siempre en el árbol para que el focus funcione.
                        TextEditor(text: $draft.passages[index].text)
                            .scrollDisabled(true)
                            .font(.system(size: 19, weight: .light, design: .serif))
                            .foregroundStyle(quoteColor)
                            .tint(titleColor)
                            .lineSpacing(7)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focused($focusedPassageID, equals: passage.id)
                            .opacity(isFocused && !isDragging && !isReordering ? 1 : 0.01)
                            .allowsHitTesting(isFocused && !isDragging && !isReordering)

                        if !isFocused || isDragging || isReordering {
                            // Modo lectura / drag / reorder: Text visible encima
                            Text(passage.text.isEmpty ? " " : passage.text)
                                .font(.system(size: 19, weight: .light, design: .serif))
                                .foregroundStyle(quoteColor)
                                .lineSpacing(7)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Radio button: visible solo cuando seleccionado
                    ZStack {
                        Circle()
                            .stroke(accentColor, lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(accentColor)
                            .frame(width: 9, height: 9)
                    }
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.1, anchor: .center)
                    .animation(.spring(duration: 0.35, bounce: 0.3), value: isSelected)
                    .frame(width: 18)
                }
                .padding(.leading, 34)
                .padding(.trailing, 24)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .offset(x: xOffset)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // Reorder
        .scaleEffect(isReordering ? 1.02 : 1.0)
        .offset(y: isReordering ? reorderDragY : 0)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: PassageFrameKey.self,
                    value: [passage.id: geo.frame(in: .global)]
                )
            }
        )
        // ── Gestos ───────────────────────────────────────────────────
        .onTapGesture {
            guard focusedPassageID != passage.id else { return }
            guard selectedPassageIDs.isEmpty && reorderingID == nil else { return }
            guard !isDragging && !isReordering else { return }
            focusedPassageID = passage.id
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard focusedPassageID == nil else { return }
                    guard reorderingID == nil else { return }
                    if value.translation.width < 0 {
                        dragOffset[passage.id] = value.translation.width
                    }
                }
                .onEnded { _ in
                    guard focusedPassageID == nil else { return }
                    guard reorderingID == nil else { return }
                    let offset = dragOffset[passage.id] ?? 0
                    if isSelected {
                        // Ya seleccionado → deseleccionar
                        haptic(.soft)
                        withAnimation(.spring(duration: 0.3)) {
                            selectedPassageIDs.remove(passage.id)
                            if selectedPassageIDs.isEmpty { showDeleteConfirm = false }
                        }
                    } else if offset < -threshold {
                        // Swipe suficiente → añadir a selección
                        haptic(.soft)
                        removeEmptyPassages(except: passage.id)
                        withAnimation(.spring(duration: 0.3)) {
                            selectedPassageIDs.insert(passage.id)
                            showDeleteConfirm = false
                        }
                    }
                    withAnimation(.spring(duration: 0.3, bounce: 0)) {
                        dragOffset[passage.id] = 0
                    }
                }
        )
        .simultaneousGesture(
            reorderingID == nil && selectedPassageIDs.isEmpty && focusedPassageID == nil
            ? LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    removeEmptyPassages(except: passage.id)
                    withAnimation(.spring(duration: 0.3)) {
                        reorderingID = passage.id
                        reorderDragY = 0
                    }
                }
            : nil
        )
        .simultaneousGesture(
            reorderingID == passage.id
            ? DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard reorderingID == passage.id else { return }
                    reorderDragY = value.translation.height
                    checkReorderCrossing(for: passage)
                }
                .onEnded { _ in
                    guard reorderingID == passage.id else { return }
                    haptic(.medium)
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
                        deleteSelectedPassages()
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

            // El notch en sí — píldora con uno o dos botones
            HStack(spacing: 0) {
                // Marcar como portada — solo visible con exactamente 1 seleccionado
                if selectedPassageIDs.count == 1 {
                    let featuredID  = selectedPassageIDs.first!
                    // Refleja la misma lógica que CardView:
                    // si no hay featured explícito, el último pasaje es el que se muestra
                    let isFeatured  = draft.featuredPassageID == featuredID
                                   || (draft.featuredPassageID == nil && draft.passages.last?.id == featuredID)
                    Button {
                        haptic(.soft)
                        withAnimation(.spring(duration: 0.25)) {
                            draft.featuredPassageID = isFeatured ? nil : featuredID
                        }
                    } label: {
                        Image(systemName: isFeatured ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(isFeatured ? titleColor : titleColor.opacity(0.55))
                            .frame(width: 64, height: 46)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))

                    Rectangle()
                        .fill(titleColor.opacity(0.15))
                        .frame(width: 0.5, height: 26)
                        .transition(.opacity)
                }

                // Eliminar
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
            }
            .animation(.spring(duration: 0.3), value: selectedPassageIDs.count == 1)
            .background(
                RoundedRectangle(cornerRadius: 23)
                    .fill(cardBg)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
            )
        }
        .padding(.bottom, 44)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func pasteBar(_ text: String) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.system(size: 12, weight: .light, design: .serif))
                .foregroundStyle(quoteColor.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.paste(_:)),
                    to: nil, from: nil, for: nil
                )
                withAnimation(.spring(duration: 0.25)) { clipboardText = nil }
            } label: {
                Text("pegar")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(bgColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(titleColor))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBg)
                .shadow(color: .black.opacity(0.3), radius: 10, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func handleScannedText(_ scanned: String) {
        let trimmed = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Si hay un pasaje enfocado y vacío → rellenarlo; si no → nuevo pasaje
        if let fid = focusedPassageID,
           let idx = draft.passages.firstIndex(where: { $0.id == fid }),
           draft.passages[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.passages[idx].text = trimmed
        } else {
            draft.passages.append(Passage(text: trimmed))
        }
    }

    private func checkClipboard() {
        let text = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let valid = !text.isEmpty && text.contains(where: { $0.isLetter })
        withAnimation(.spring(duration: 0.35)) {
            clipboardText = valid ? text : nil
        }
    }

    private func deleteSelectedPassages() {
        haptic(.rigid)
        withAnimation(.spring(duration: 0.3)) {
            draft.passages.removeAll { selectedPassageIDs.contains($0.id) }
            if let featured = draft.featuredPassageID, selectedPassageIDs.contains(featured) {
                draft.featuredPassageID = nil
            }
            selectedPassageIDs.removeAll()
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

    private func removeEmptyPassages(except keepID: UUID? = nil) {
        draft.passages.removeAll {
            $0.id != keepID && $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

// MARK: - DataScanner (VisionKit)

private struct DataScannerView: UIViewControllerRepresentable {
    let onRecognized: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onRecognized: onRecognized) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRecognized: (String) -> Void
        init(onRecognized: @escaping (String) -> Void) { self.onRecognized = onRecognized }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let t) = item {
                onRecognized(t.transcript)
            }
        }
    }
}
