# Lanzadera: plan de desarrollo

Referencia funcional: [`../IDEA.md`](../IDEA.md). Análisis previo: [`VIABILIDAD.md`](VIABILIDAD.md). Este documento define **cómo** se construye. Las fases están en [`FASES.md`](FASES.md).

> **Estado (29-oct-2026):** fases 1–6 implementadas y con pruebas; pendiente la verificación a mano (ver `HALLAZGOS.md`). Diferencias con este plan anotadas en `HALLAZGOS.md` → "Decisiones que cambiaron".

## Decisiones

| Tema | Decisión | Por qué |
|---|---|---|
| Plataforma | macOS 27+, Swift 6 (concurrencia estricta), SwiftUI + AppKit donde haga falta | Igual que Baúl y Destello |
| Distribución | Sin App Sandbox, Hardened Runtime con `com.apple.security.automation.apple-events`, firmado con Apple Development (equipo RS79YL6DLM) | La firma estable mantiene el permiso de Automatización al recompilar. El sandbox exigiría excepciones temporales para enviar Apple Events |
| Bundle ID | `dev.tonis.lanzadera` | Mismo prefijo que las otras apps |
| Control de Ghostty | **AppleScript oficial de Ghostty 1.4**, ejecutado con `NSAppleScript`. Un script por acción (abrir un proyecto = un script) que devuelve los `id` de las ventanas creadas | API documentada, ya probada en la PoC. Un solo script por proyecto evita decenas de viajes de Apple Events. Generar texto es fácil de probar |
| Permiso | `NSAppleEventsUsageDescription` en `Info.plist`; estado con `AEDeterminePermissionToAutomateTarget` | Mostrar el estado en la bienvenida y en Configuración sin disparar la alerta antes de tiempo |
| Configuración | **YAML** con [Yams](https://github.com/jpsim/Yams) en `~/.config/lanzadera/proyectos.yaml` | Las configuraciones de Warp ya son YAML (hay que leerlas igual), es el formato "parecido a Warp" que pide la idea, admite comentarios y Yams da **línea y columna** en los errores |
| Vigilar el archivo | `DispatchSource` sobre la **carpeta** (resolviendo el enlace simbólico) + espera de ~200 ms | Zed guarda reemplazando el archivo: vigilar el archivo perdería los cambios tras el primer guardado |
| Atajo global | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), ⌥Espacio por defecto | Ya usado en Baúl y Destello |
| Panel | `NSPanel` no activante que recibe teclado (receta de Baúl), pegado a un costado de la pantalla del cursor | Ya resuelto en Baúl, incluidas sus trampas |
| Abrir en Zed | `NSWorkspace.open(_:withApplicationAt:)` con `dev.zed.Zed`; si no está, el editor por defecto | Sin depender del comando `zed` en el `PATH` |
| "Ya abierto" | Registro propio proyecto → `id` de ventanas de Ghostty (JSON en Application Support) + reconocimiento por los nombres de pestaña si los `id` ya no existen | Ver [Detección de "ya abierto"](#detección-de-ya-abierto) |
| Ajustes simples | `@AppStorage` / `UserDefaults` (atajo, costado del panel, ya se ofreció importar) | No justifica más |
| Iniciar al encender | `SMAppService.mainApp` | API nativa |
| Pruebas | Swift Testing | Igual que las otras apps |
| Estilo | `swift-format` + SwiftLint | Igual que las otras apps |
| Proyecto | XcodeGen (`project.yml`) + `Makefile` | El `.xcodeproj` no se edita a mano ni se versiona |

**Dependencias externas:** KeyboardShortcuts y Yams. Sin base de datos.

## Arquitectura

```
Lanzadera.xcodeproj (generado)
└─ Lanzadera (target)          → composición: crea servicios, conecta dependencias, MenuBarExtra
Packages/LanzaderaKit (paquete Swift local)
├─ LanzaderaCore               → dominio puro: modelo, validación, resumen, búsqueda, plan de apertura,
│                                generador de AppleScript, conversión Warp → Lanzadera, huella de ventanas
├─ LanzaderaConfig             → YAML (Yams): leer/escribir proyectos.yaml con errores por línea, leer Warp
├─ LanzaderaSystem             → Ghostty (NSAppleScript), permisos, vigilancia de archivos, carpetas,
│                                atajo global, abrir en Zed, inicio de sesión, registro de ventanas
└─ LanzaderaUI                 → panel lateral, menú, Configuración, bienvenida, revisión de la importación
```

- Dependencias en una sola dirección: `LanzaderaUI → LanzaderaSystem → LanzaderaConfig → LanzaderaCore`. `LanzaderaCore` no importa AppKit ni Yams.
- Todo lo que toca el sistema va detrás de un protocolo, para probar con versiones falsas:
  - `GhosttyControlling`: ¿está abierto?, foto de ventanas/pestañas/terminales, abrir un plan, activar ventanas.
  - `ScriptRunning`: ejecutar un AppleScript y devolver el resultado (la única pieza que llama a `NSAppleScript`).
  - `FolderChecking`: ¿existe esta carpeta?
  - `FileWatching`: avisar cuando cambia `proyectos.yaml`.
  - `AutomationPermissionChecking`: estado del permiso para controlar Ghostty.
- UI y sistema en el main actor por defecto (`defaultIsolation(MainActor.self)`); Core y Config `nonisolated`. `NSAppleScript` no es seguro entre hilos: se ejecuta en el main actor y se mide en la fase 0 (si bloquea más de ~100 ms, se mueve a un hilo propio dedicado).
- Modelos de dominio: `struct` / `enum` `Sendable`.

### Flujo

```
⌥Espacio / ícono ─► PanelController (NSPanel en la pantalla del cursor)
                      │ ProjectStore: proyectos válidos + errores (se recarga solo al guardar en Zed)
                      │ OpenStateMonitor: ¿qué proyectos están abiertos? (solo si Ghostty corre)
                      │ escribir → filtra · ↑↓ → mover · Enter/clic → abrir · ⌥ → forzar nueva · Esc → cerrar
                      ▼
                   ProjectLauncher
                      1. comprobar carpetas      → si falta alguna: aviso con la ruta, no abre nada
                      2. ¿ya abierto? (registro + huella) → activar sus ventanas, seleccionar pestaña principal
                      3. si no: LaunchPlan → GhosttyScriptBuilder → ScriptRunner
                      4. guardar los id de ventanas devueltos en WindowRegistry
                      5. cerrar el panel
```

### Piezas

| Pieza | Módulo | Responsabilidad |
|---|---|---|
| `Project` / `ProjectWindow` / `ProjectTab` / `Pane` | Core | Modelo ya resuelto (rutas absolutas, `~` expandido, una sola pestaña principal) |
| `ProjectValidator` | Core | Reglas: nombre único, al menos una pestaña, una sola principal, carpetas absolutas. Devuelve errores por proyecto |
| `ProjectSummary` | Core | "3 pestañas · 6 paneles" |
| `ProjectFilter` | Core | Búsqueda escribiendo (sin tildes ni mayúsculas: "clini" encuentra Clinicsay) |
| `LaunchPlan` | Core | Pasos en orden: ventana → pestañas → divisiones → nombres → foco |
| `GhosttyScriptBuilder` | Core | `LaunchPlan` → texto AppleScript, con el escapado de comillas y barras en un solo lugar |
| `WindowFingerprint` | Core | Huella de una ventana (nombres de pestaña en orden) para reconocer un proyecto abierto |
| `WarpImporter` | Core | Launch Configuration de Warp → `Project`, con avisos (carpeta inexistente, ventana fuera del proyecto, ventana repetida de otro proyecto) |
| `ConfigLoader` / `ConfigWriter` | Config | YAML ↔ modelo, errores con línea y columna, copia `.bak` antes de escribir |
| `WarpConfigReader` | Config | Lee `~/.warp/launch_configurations/*.yaml` (esquema de Warp, recursivo) |
| `GhosttyController` | System | Implementa `GhosttyControlling` con `ScriptRunner` |
| `WindowRegistry` | System | Proyecto → `id` de ventanas, persistido en `~/Library/Application Support/Lanzadera/ventanas.json` |
| `ConfigFileWatcher` | System | Vigila `~/.config/lanzadera/` |
| `ProjectStore` | UI | `@Observable`: proyectos, errores, última versión válida |
| `ProjectLauncher` | UI | Orquesta el flujo de apertura; probado con dobles |
| `PanelController` + `PanelView` | UI | Panel lateral, búsqueda, teclado, indicador de abierto, botón ⚙️ |
| `ImportReviewView` | UI | Lista de lo que se importará con sus avisos; casillas para descartar ventanas |

## El archivo de configuración

Ubicación: `~/.config/lanzadera/proyectos.yaml`. Si no existe, se crea con un ejemplo comentado. Claves en inglés como en Warp, simplificadas:

```yaml
# Lanzadera: mis proyectos. Se recarga solo al guardar.
projects:
  - name: Nexus
    emoji: 🔴
    root: ~/nexus                 # carpeta base: las rutas relativas parten de aquí
    windows:
      - tabs:
          - title: 🔴 BACKEND
            cwd: nexus-backend
            panes: 3              # 3 paneles en la misma carpeta
            split: right          # right (de lado a lado, por defecto) | down (hacia abajo)
            focus: true           # pestaña principal
          - title: 🔴 FRONTEND
            cwd: nexus-frontend
            panes: 2
          - title: 🔴 GLOBAL      # sin cwd: usa root; sin panes: 1

  - name: Clinicsay
    emoji: 🟣
    root: ~/clinicsay
    windows:
      - tabs:
          - title: 🟣 MIGRATION APP
            cwd: migration-app
          - title: 🔴 BACKEND
            cwd: clinicsay-backend
            focus: true
          - title: 🔵 FRONTEND
            cwd: clinicsay-frontend
            panes:                # carpeta distinta por panel
              - cwd: clinicsay-frontend
              - cwd: migration-app
```

Reglas:

- `panes` acepta un **número** (todos en el `cwd` de la pestaña) o una **lista** de paneles con su propio `cwd`. La lista deja sitio para la etapa 2 sin romper nada: `command`, `env`.
- Si un proyecto tiene una sola ventana, se permite `tabs:` directamente bajo el proyecto (sin `windows:`).
- Si ninguna pestaña tiene `focus: true`, la principal es la primera. Si hay dos, es un error de ese proyecto.
- `emoji` o `color` (`red`, `green`, `blue`, `magenta`, `yellow`, `cyan`) para la lista; el color se dibuja como un punto.
- `icon`: sin la clave, se busca el favicon en las carpetas del proyecto y un nivel más abajo (`ProjectIconFinder`); una ruta (relativa a `root`) elige una imagen; `none` lo desactiva. Orden: ícono → emoji/color → inicial del nombre.
- **Errores de sintaxis** (YAML ilegible): se conserva la última versión válida y el panel muestra "Error en la línea 12: …" con un botón para abrirlo en Zed.
- **Errores de contenido** (pestaña sin título, dos principales…): ese proyecto aparece en gris con su error; los demás funcionan.
- **Carpetas inexistentes**: no es un error del archivo (la carpeta puede volver). El proyecto muestra un aviso y, al abrirlo, se dice qué carpeta falta.

## Control de Ghostty

Script que se genera para abrir un proyecto (simplificado):

```applescript
tell application "Ghostty"
    set cfg to new surface configuration
    set initial working directory of cfg to "/Users/tonis/nexus/nexus-backend"
    set w to new window with configuration cfg
    set t1 to selected tab of w
    set name override of t1 to "🔴 BACKEND"
    set p1 to focused terminal of t1
    split p1 direction right with configuration cfg
    split p1 direction right with configuration cfg
    perform action "equalize_splits" on p1
    -- FRONTEND, GLOBAL: new tab in w with configuration …
    select tab t1
    activate window w
    return id of w
end tell
```

- Lanzadera nunca abre Ghostty solo para consultar el estado: primero mira `NSRunningApplication` (`com.mitchellh.ghostty`).
- Las cadenas (rutas, títulos con emoji) pasan por una única función de escapado probada con comillas, barras invertidas y emojis.
- Si una ventana se crea a medias (error a mitad del script), se informa del error y no se registra el proyecto como abierto.

### Detección de "ya abierto"

1. **Registro:** al abrir un proyecto se guardan los `id` de sus ventanas.
2. **Comprobación:** al elegir el proyecto (y al mostrar el panel, para el indicador) se pide a Ghostty la lista de ventanas con `id` y nombres de pestaña. Si algún `id` registrado sigue existiendo → está abierto.
3. **Respaldo por huella:** si los `id` ya no existen (Ghostty se reinició y restauró sus ventanas), se busca una ventana cuyos nombres de pestaña coincidan con los del proyecto, en orden. Si la hay, se adopta y se actualiza el registro.
4. Si no hay nada → se abre desde cero.
5. **⌥ + Enter / ⌥ + clic** salta todo esto y abre una ventana nueva.

Qué conserva Ghostty al reiniciar (`id`, `name override`) se confirma en la fase 0; si no conserva los nombres, la huella pasa a usar las carpetas de los terminales.

## Importar desde Warp

- Lee los YAML de `~/.warp/launch_configurations/`. El esquema de Warp es recursivo: un `layout` es una hoja (`cwd`, `is_focused`, `commands`) o una división (`split_direction` + `panes`).
- Conversión: `title` → `title` con el emoji de su `color`; `split_direction: horizontal` → `split: right` (a confirmar en la fase 0 comparando con Warp), `vertical` → `down`; `active_tab_index` → `focus`; la carpeta común pasa a `root` y las demás quedan relativas. Las divisiones anidadas se aplanan con un aviso.
- Colores: `red` 🔴, `green` 🟢, `blue` 🔵, `magenta` 🟣, `yellow` 🟡, `cyan` 🩵, `black` ⚫, `white` ⚪.
- **Avisos** que se muestran antes de escribir, con casillas para descartar ventanas:
  - carpeta inexistente (Nexus: `~/Desktop/data/fotos`);
  - ventana fuera de la carpeta del proyecto;
  - ventana igual a la de otro proyecto (Smart repite la de Nexus; Chaskybet repite la de Smart).
- Se agrega al archivo existente; si un proyecto con ese nombre ya existe, se pregunta. Siempre se escribe antes `proyectos.yaml.bak`.
- Los `commands` de Warp se guardan como comentario hasta la etapa 2.

## Convenciones

Las mismas que Baúl y Destello:

- Textos de la interfaz y comentarios en español. Nombres de código en inglés.
- Pruebas con Swift Testing (`@Test`, `#expect`) y nombres en lenguaje natural entre backticks.
- `Logger` (subsystem `dev.tonis.lanzadera`), nunca `print`.
- Rutas de archivo: `url.path(percentEncoded: false)`.
- Nada de `force unwrap` fuera de constantes evidentes (SwiftLint `force_unwrapping`).

## Riesgos principales

Detalle en [`VIABILIDAD.md`](VIABILIDAD.md#riesgos). Resumen de dónde se resuelve cada uno:

| Riesgo | Se resuelve en |
|---|---|
| "Ya abierto" tras reiniciar Ghostty | Fase 0 (medir) + fase 5 (huella) |
| Ghostty cerrado al abrir | Fase 0 |
| Permiso de Automatización y firma | Fase 0 + fase 6 (bienvenida) |
| Paneles de distinto tamaño | Fase 0 |
| Vigilancia con el guardado de Zed y enlaces simbólicos | Fase 0 + fase 2 |
| Conflicto de ⌥Espacio | Fase 0 |
