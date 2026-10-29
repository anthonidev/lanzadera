# Lanzadera 🚀

> Un atajo y tu proyecto está listo en la terminal.

App de barra de menú para macOS 27 que abre mis proyectos en [Ghostty](https://ghostty.org) con sus ventanas, pestañas con nombre y paneles, cada uno en su carpeta. Reemplaza las *Launch Configurations* de Warp.

- **⌥Espacio** abre un panel lateral con los proyectos: se busca escribiendo, ↑↓ y Enter, o ⌘1…⌘9.
- Si el proyecto **ya está abierto**, te lleva a su ventana en vez de duplicarlo (⌥Enter fuerza una nueva).
- Los proyectos se definen en `~/.config/lanzadera/proyectos.yaml`, se recarga solo al guardar y los errores dicen su línea.
- **Importa** las *Launch Configurations* de Warp y avisa de ventanas repetidas o carpetas que ya no existen.
- Muestra el **favicon** de cada proyecto (o su emoji).

```yaml
projects:
  - name: Nexus
    emoji: 🔴
    root: ~/nexus
    tabs:
      - title: 🔴 BACKEND
        cwd: nexus-backend
        panes: 3          # tres paneles lado a lado
        focus: true       # pestaña principal
      - title: 🔴 FRONTEND
        cwd: nexus-frontend
        panes: 2
      - title: 🔴 GLOBAL
```

## Cómo funciona

Usa el soporte oficial de AppleScript de **Ghostty 1.4**: un script por proyecto crea la ventana, las pestañas, las divisiones y los nombres. La consulta de "¿qué está abierto?" pide los datos en bloque (~40 ms).

Swift 6 + SwiftUI/AppKit, sin sandbox (necesita enviar Apple Events). Dependencias: [Yams](https://github.com/jpsim/Yams) y [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).

## Compilar

Requiere Xcode 27, `xcodegen` y `swiftlint` (`brew install xcodegen swiftlint`).

```sh
make run       # compila y abre la app (Debug)
make test      # pruebas (Swift Testing)
make lint      # SwiftLint
make install   # Release en /Applications
```

La firma usa mi equipo de desarrollo (`DEVELOPMENT_TEAM` en `project.yml`): cámbialo por el tuyo para compilar.

## Documentación

[`IDEA.md`](IDEA.md) (qué hace) · [`docs/PLAN.md`](docs/PLAN.md) (cómo se construye) · [`docs/FASES.md`](docs/FASES.md) · [`docs/HALLAZGOS.md`](docs/HALLAZGOS.md) (mediciones y trampas) · [`CLAUDE.md`](CLAUDE.md) (arquitectura).

Proyecto personal, hecho para aprender desarrollo en Apple.
