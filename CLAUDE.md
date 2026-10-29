# Lanzadera

Lanzador de proyectos en Ghostty para macOS 27 (reemplazo de las *Launch Configurations* de Warp). Qué hace: `IDEA.md`. Cómo se construye: `docs/PLAN.md`. Fases: `docs/FASES.md`. Hallazgos y decisiones: `docs/HALLAZGOS.md`.

## Comandos

- `make run`: genera el proyecto, compila y abre la app.
- `make test`: pruebas (Swift Testing) del paquete `Packages/LanzaderaKit`.
- `make lint`: SwiftLint; debe quedar sin advertencias.
- `make install`: build Release en `/Applications/Lanzadera.app`.
- `Lanzadera.xcodeproj` se genera con XcodeGen desde `project.yml`: no se edita a mano ni se versiona.
- Ícono: `swift scripts/generate-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset`.
- Ver el panel sin teclado (solo Debug): `open build/Build/Products/Debug/Lanzadera.app --args --panel`.

## Arquitectura

- `App/`: target de la app. Solo composición (`AppModel`) y el menú de la barra.
- `Packages/LanzaderaKit`:
  - `LanzaderaCore`: dominio puro. `Project` (resuelto) y `ProjectSpec` (tal como está escrito), `ProjectResolver` (validación por proyecto), `ProjectSummary`, `ProjectFilter`, `GhosttyScript` (**único lugar que escribe AppleScript**), `GhosttySnapshot`, `OpenProjectMatcher` (registro + huella), `ProjectIconFinder` (favicon por calidad), `WarpImporter`. Sin AppKit ni Yams.
  - `LanzaderaConfig`: `ConfigLoader` (nodos de Yams → `ProjectSpec` con líneas), `ConfigWriter` (agrega al final sin perder comentarios), `WarpConfigReader`, `ConfigLocation` (`~/.config/lanzadera/proyectos.yaml`, copia `.bak`).
  - `LanzaderaSystem`: `AppleScriptRunner` (`NSAppleScript`), `GhosttyController`, `AutomationPermission`, `ConfigFileWatcher`, `WindowRegistry`, `ProjectIconLoader` (decodifica fuera del hilo principal), atajo, inicio de sesión, abrir en Zed, preferencias. Protocolos `ScriptRunning`, `GhosttyControlling`, `WindowRegistering`, `FolderChecking`.
  - `LanzaderaUI`: `ProjectStore`, `ProjectLauncher`, panel (`PanelController` + `PanelViewModel` + `PanelView`), importación, Preferencias y Bienvenida.
- Dependencias: `UI → System → Config → Core`. Core no depende de nadie.

## Convenciones

- Swift 6, concurrencia estricta. `LanzaderaUI`/`LanzaderaSystem`/app: main actor por defecto. Core y Config: `nonisolated`.
- Textos de la interfaz y comentarios en español. Nombres de código en inglés.
- Pruebas con Swift Testing (`@Test`, `#expect`), con nombres en lenguaje natural entre backticks.
- `Logger` (subsystem `dev.tonis.lanzadera`), nunca `print`.
- Rutas de archivo: `url.path(percentEncoded: false)`.

## Trampas conocidas (ver docs/HALLAZGOS.md)

- `NSPanel.isFloatingPanel = true` reinicia el `level`: asignarlo antes (`FloatingPanel`).
- El campo de búsqueda se come flechas/Enter/Esc: el teclado del panel se maneja con un monitor local en `PanelController`.
- Zed guarda reemplazando el archivo: `ConfigFileWatcher` vigila la carpeta y vuelve a abrir el archivo tras cada aviso.
- El indicador "abierto" no consulta a Ghostty sin permiso concedido: la alerta de Automatización sale al abrir un proyecto, no al mirar la lista.
- Si se prueba desde Ghostty, no cerrar Ghostty (mata la terminal desde la que se trabaja).
- Cada Apple Event a Ghostty cuesta ~14 ms: pedir propiedades en bloque (`… of every tab of every window`), nunca en bucles.
- Nada de AppleScript durante animaciones: `NSAppleScript` bloquea el hilo principal (ver `PanelController.show`).
- Firmar siempre con el certificado Apple Development (equipo RS79YL6DLM) para no perder el permiso de Automatización.
