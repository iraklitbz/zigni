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
- [x] Swipe izquierda para eliminar tarjeta (sin confirmación, animación flubber)
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

**Última sesión**: Borrado por swipe izquierdo implementado. Animación en 2 fases: tarjeta vuela a la izquierda + hueco colapsa simultáneamente. Rebote flubber si cancelas a mitad. Swipe derecho reservado para compartir.

**Archivos clave**:
- `SwipeableCard.swift` → wrapper genérico de swipe (izq=borrar, der=futuro compartir)
- `EditableCardView.swift` → tarjeta editable inline + `DraftQuote`
- `ContentView.swift` → `handleDelete()` gestiona las 2 fases del borrado
- `QuotesStore.swift` → `defaultQuotes` (10 citas de ejemplo)

**Próximo paso**: Probar borrado en simulador. Posibles ajustes: velocidad del vuelo (`duration: 0.26`), umbral de activación (`cardWidth * 0.55`), bounce del snap-back (`bounce: 0.52`).
