# Documentación de Lanzadera

| Documento | Para qué sirve |
|---|---|
| [`../IDEA.md`](../IDEA.md) | **Qué** hace la app, contado desde el uso. Es la referencia funcional. |
| [`VIABILIDAD.md`](VIABILIDAD.md) | Análisis de la idea: si se puede, qué ya existe gratis, riesgos y qué conviene recortar o ajustar. |
| [`PLAN.md`](PLAN.md) | **Cómo** se construye: decisiones, dependencias, arquitectura, formato del archivo de configuración y control de Ghostty. |
| [`FASES.md`](FASES.md) | El desarrollo dividido en fases, cada una con su objetivo, tareas, pruebas y criterio de "listo". |
| [`HALLAZGOS.md`](HALLAZGOS.md) | Bitácora: lo que se descubre en cada fase (trampas, mediciones, decisiones que cambiaron). |

Orden de lectura para retomar el trabajo: `IDEA.md` → `PLAN.md` → la fase en curso de `FASES.md` → `HALLAZGOS.md`.

## Relación con las otras apps

- **Baúl** (`../baul`): de aquí se copia la estructura del proyecto (XcodeGen + paquete Swift local por capas, `make`, SwiftLint, Swift Testing), la receta del `NSPanel` flotante que recibe teclado sin quitar el foco, la búsqueda con flechas/Enter/Esc (monitor local de teclado) y la firma estable.
- **Destello** (`../destello`): organización de `docs/`, menú de barra, Configuración con `KeyboardShortcuts.Recorder`, bienvenida e inicio al encender (`SMAppService`).
- **zed-config** (`../zed-config`): el archivo de Lanzadera vive en `~/.config/lanzadera/` y puede guardarse en ese repo con un enlace simbólico, igual que la configuración de Zed.
- **Vigilia** (`../vigilia`): a futuro, abrir un proyecto desde el bot de Telegram.
