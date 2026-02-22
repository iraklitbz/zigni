//
//  SwipeableCard.swift
//  zigni
//

import SwiftUI

struct SwipeableCard<Content: View>: View {
    let cardWidth: CGFloat
    let canSwipe: Bool           // false en la tarjeta de creación activa
    let onDeleteTriggered: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragX: CGFloat = 0
    @State private var direction: Bool? = nil  // true=horizontal, false=vertical, nil=sin decidir

    private var threshold: CGFloat { cardWidth * 0.55 }

    // 0 = sin deslizar  /  1 = en el umbral de borrado
    private var deleteProgress: CGFloat {
        guard canSwipe, dragX < 0 else { return 0 }
        return min(1.0, -dragX / threshold)
    }

    var body: some View {
        ZStack {
            // ── Indicador de borrado (detrás de la tarjeta) ───────────
            HStack {
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(
                        Color(red: 0.72, green: 0.28, blue: 0.22)
                            .opacity(deleteProgress * 0.9)
                    )
                    .scaleEffect(0.35 + deleteProgress * 0.65)
                    .padding(.trailing, 46)
            }
            // El padding horizontal hace que el × quede dentro del borde de la tarjeta
            .padding(.horizontal, 18)

            // ── Tarjeta ───────────────────────────────────────────────
            content()
                // Tinte rojo muy sutil que va creciendo al acercarse al umbral
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(red: 0.9, green: 0.2, blue: 0.2).opacity(deleteProgress * 0.10))
                        .padding(.horizontal, 18)
                        .allowsHitTesting(false)
                }
                .offset(x: dragX)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onChanged { v in
                    guard canSwipe else { return }

                    // Decidir dirección solo cuando el movimiento es inequívocamente horizontal:
                    // el desplazamiento horizontal tiene que ser más del doble que el vertical
                    if direction == nil {
                        let isHorizontal = abs(v.translation.width) > abs(v.translation.height) * 2.0
                        // Si es vertical claro, marcamos false para ignorar el resto del gesto
                        if abs(v.translation.height) > abs(v.translation.width) {
                            direction = false
                        } else if isHorizontal {
                            direction = true
                        }
                        // Si todavía es ambiguo, esperamos más movimiento (direction sigue nil)
                    }
                    guard direction == true else { return }

                    // Solo deslizamiento hacia la izquierda (negativo)
                    dragX = min(0, v.translation.width)
                }
                .onEnded { v in
                    guard canSwipe else { return }
                    let wasHorizontal = direction == true
                    direction = nil
                    guard wasHorizontal else { return }

                    let pastThreshold = -dragX >= threshold
                    let fastFling    = v.velocity.width < -650

                    if pastThreshold || fastFling {
                        // ── Borrar: vuela hacia la izquierda ──────
                        withAnimation(.spring(duration: 0.26, bounce: 0.0)) {
                            dragX = -(cardWidth * 2.5)
                        }
                        // Notificar al padre un tick después para que el vuelo sea visible
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            onDeleteTriggered()
                        }
                    } else {
                        // ── Cancelar: rebote flubber de vuelta ────
                        withAnimation(.spring(duration: 0.44, bounce: 0.52)) {
                            dragX = 0
                        }
                    }
                }
        )
    }
}
