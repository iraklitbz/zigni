# Zigni — Plan de desarrollo

## El concepto
App minimalista y artística para anotar citas de libros.
- **Cada nota**: título del libro + cita
- **Navegación**: carrusel vertical tipo archivador de tarjetas
- **Estética**: oscuro y cálido, tipografía cuidada, animaciones tipo "flubber"

---

## Estructura de archivos
```
zigni/
  zigniApp.swift        ← punto de entrada (no tocar)
  ContentView.swift     ← carrusel principal + orquestador
  Quote.swift           ← modelo de datos
  QuotesStore.swift     ← gestión de estado + persistencia JSON
  CardView.swift        ← tarjeta individual
  EditView.swift        ← editor a pantalla completa
```

---

## Fases

### Fase 1 — Estructura base ✅
- [x] Modelo `Quote` (id, título del libro, texto de la cita, fecha)
- [x] `QuotesStore` con persistencia JSON en Documents (sin CoreData)
- [x] Datos de ejemplo para desarrollo

### Fase 2 — Diseño de tarjeta ✅
- [x] `CardView`: título arriba (monospaced, mayúsculas, dorado apagado)
- [x] Cita en zona inferior (serif, crema cálida)
- [x] Esquinas redondeadas, padding generoso, fondo oscuro cálido

### Fase 3 — Carrusel con snap ✅
- [x] `ScrollView` vertical + `.scrollTargetBehavior(.viewAligned)`
- [x] Tarjeta central: ~84% de la altura de pantalla
- [x] Peek (asomo) de tarjetas adyacentes arriba y abajo (~8%)
- [x] Degradado en bordes superior/inferior para sensación de profundidad

### Fase 4 — Animación flubber ✅
- [x] `.scrollTransition(.animated(.spring(bounce: 0.4)))`
- [x] Al entrar al centro: escala 0.85 → 1.0 con rebote elástico
- [x] Opacidad: 0.4 → 1.0 al centrarse
- [x] Al hacer scroll rápido: colapsa rápido y se aleja

### Fase 5 — Modo edición ✅
- [x] `EditView`: sheet a pantalla completa, mismo fondo oscuro
- [x] Título del libro en la parte superior (pequeño, monospaced)
- [x] TextEditor grande para la cita (serif, ocupa el espacio)
- [x] Botón "+" para crear nueva nota (flota abajo a la derecha)
- [x] Guardar al cerrar con "listo"

---

## Pendiente / Ideas futuras
- [ ] Haptic feedback al hacer snap en el carrusel
- [x] Swipe izquierda → flip de tarjeta (animación interactiva + spring flubber)
- [x] Swipe derecha → flip de vuelta al frente
- [ ] Borrado de tarjeta: pendiente de definir cómo
- [x] Dorso: portada + sinopsis via Google Books API (gratuita, sin API key)
- [ ] Borrado de tarjeta: pendiente de definir cómo
- [ ] Animación de transición más elaborada al abrir EditView (expand from card)
- [ ] Búsqueda por título o texto
- [ ] Exportar cita como imagen (compartir)
- [ ] Temas de color (claro / oscuro)
- [ ] Fuentes personalizadas opcionales
- [ ] Base de datos (SwiftData cuando lo necesitemos)

---

## Diseño — Paleta de colores

| Elemento          | Hex       | Descripción         |
|-------------------|-----------|---------------------|
| Fondo             | `#120F0D` | Negro cálido        |
| Tarjeta           | `#1C1815` | Marrón muy oscuro   |
| Título del libro  | `#947855` | Dorado apagado      |
| Texto de la cita  | `#EAE3D8` | Crema cálida        |
| Placeholder       | `#4A4035` | Gris cálido oscuro  |
| Acento / botones  | `#7A6248` | Cobre suave         |

---

## Notas técnicas
- **iOS 26+**, SwiftUI, Swift 6
- `@Observable` (más moderno que ObservableObject)
- `.scrollTransition` para animaciones de carrusel (iOS 17+)
- `.viewAligned` para snap suave (iOS 17+)
- Persistencia simple: JSON en Documents (sin CoreData por ahora)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` → todo implícitamente en el hilo principal

---

## Por dónde vamos ahora
> Actualiza esta sección cuando retomes el trabajo.

**Última sesión**: Swipe izquierda cambiado de borrar a flip de tarjeta. El flip es interactivo (la tarjeta gira mientras arrastras). Dorso vacío de momento. Swipe derecha vuelve al frente.

**Archivos clave**:
- `SwipeableCard.swift` → flip interactivo + spring flubber. `CardBack` privado (vacío por ahora)
- `EditableCardView.swift` → tarjeta editable inline + `DraftQuote`
- `ContentView.swift` → sin lógica de borrado por ahora
- `QuotesStore.swift` → `defaultQuotes` (10 citas de ejemplo)

**Parámetros ajustables del flip** (en `SwipeableCard.swift`):
- Umbral de completar flip: `progress > 0.35` (línea ~68)
- Velocidad de fling: `velocity < -500` (línea ~69)
- Spring al completar: `.spring(duration: 0.55, bounce: 0.38)` (línea ~72)
- Spring al cancelar: `.spring(duration: 0.44, bounce: 0.48)` (línea ~76)
- Perspectiva 3D: `perspective: 0.45` (más bajo = más dramático)

**Próximo paso**: Decidir qué va en el dorso de la tarjeta.
