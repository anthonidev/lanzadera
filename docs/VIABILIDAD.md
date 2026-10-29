# Lanzadera: análisis de viabilidad

Fecha: 28-oct-2026. Basado en [`../IDEA.md`](../IDEA.md), el diccionario AppleScript de **Ghostty 1.4.0** (`sdef /Applications/Ghostty.app`), mi configuración de Ghostty y las 4 *Launch Configurations* de `~/.warp/launch_configurations/`.

## Veredicto

**Viable, con riesgo bajo.** A diferencia de Telón, todo lo que necesita Lanzadera está en una **API oficial y documentada** (el soporte de AppleScript de Ghostty), y la parte de la app (panel, atajo, barra de menú) ya está resuelta en Baúl y Destello. Lo único que no se puede garantizar todavía es la detección de "ya está abierto" después de reiniciar Ghostty (ver riesgos).

Tamaño estimado: **mediano-chico**, menor que Baúl (no hay base de datos ni pegado) y que Destello (no hay editor). El grueso del trabajo es el archivo de configuración (leerlo, validarlo y dar buenos errores) y el importador de Warp.

## ¿Ya existe gratis o nativo?

| Alternativa | Qué cubre | Por qué no alcanza |
|---|---|---|
| Ghostty solo | Nada parecido: no tiene *launch configurations* | Es justamente el hueco |
| Un script AppleScript por proyecto + **Raycast** (ya instalado) | Abrir un proyecto con su layout desde el lanzador de Raycast | Sin detección de "ya abierto", sin validación de carpetas, un script por proyecto difícil de mantener, sin importación. Es el **plan B** si la app se abandona: se puede hacer en una tarde |
| tmuxinator / Zellij layouts / sesh | Sesiones con ventanas y paneles, gratis y maduros | Usan pestañas y paneles **del multiplexor**, no los nativos de Ghostty. Cambia la forma de trabajar (prefijos, copiar/pegar, scroll) |
| Seguir con Warp solo para esto | Todo | Es justo lo que se quiere dejar |

**Conclusión:** lo propio de Lanzadera (panel con búsqueda, "llévame a la ventana si ya está abierta", un solo archivo validado, importar Warp) no existe gratis. Además encaja con el objetivo de aprender: Apple Events/automatización es un área nueva respecto a las otras apps.

## Lo que ya está confirmado

Del diccionario de Ghostty 1.4.0 (comprobado hoy) y de la prueba de concepto del 28-oct:

| Necesidad de la idea | Cómo se hace en Ghostty | Estado |
|---|---|---|
| Ventana nueva | `new window with configuration` | ✅ PoC |
| Pestañas con nombre | `new tab in <ventana>` + `name override` de la pestaña (escritura) | ✅ PoC |
| Paneles a la derecha / abajo | `split <terminal> direction right / down` | ✅ PoC |
| Carpeta por panel | `initial working directory` de la *surface configuration* | ✅ PoC |
| Pestaña principal | `select tab` y `focus <terminal>` | 📖 en el diccionario |
| Llevarme a la ventana | `activate window`; cada ventana, pestaña y terminal tiene un `id` | 📖 en el diccionario |
| Saber qué hay abierto | Leer `windows → tabs → name` y `terminals → working directory` | 📖 en el diccionario (probado: `id` = `tab-group-…`) |
| **Etapa 2:** comandos al abrir | `initial input` (deja la shell viva) o `command` | 📖 en el diccionario |
| **Etapa 2:** variables de entorno | `environment variables` de la *surface configuration* | 📖 en el diccionario |
| **Etapa 2:** cerrar el proyecto | `close window` (y `confirm-close-surface = false` ya está en mi config) | 📖 en el diccionario |
| Paneles del mismo tamaño | `perform action "equalize_splits"` | ❓ a probar |

Toda la segunda etapa también está cubierta por la API, así que no hay que rediseñar nada después.

## Riesgos

| # | Riesgo | Impacto | Cómo se mitiga |
|---|---|---|---|
| 1 | **"Ya abierto" tras reiniciar Ghostty.** Tengo `window-save-state = always`: Ghostty restaura las ventanas, pero no sé si conserva el `id` y el nombre de las pestañas | Medio: podría abrir el proyecto otra vez | Recordar los `id` de ventana y, si no existen, reconocer la ventana por los **nombres de sus pestañas** (huella). Se prueba en la fase 0 |
| 2 | **Ghostty cerrado al abrir un proyecto.** Al lanzarse, Ghostty restaura ventanas o abre una vacía, y luego Lanzadera crea la suya | Bajo: una ventana de más | Medir en la fase 0; si sobra una ventana vacía recién creada, cerrarla |
| 3 | **Permiso de Automatización** ("Lanzadera quiere controlar Ghostty"). Si se rechaza, la app no sirve | Bajo | Firma estable (como Baúl/Destello) para que no se pierda al recompilar; bienvenida con botón a Ajustes → Privacidad → Automatización |
| 4 | **Tres paneles no quedan iguales**: dividir dos veces a la derecha da 50/25/25 | Bajo (estético) | `equalize_splits`; si no funciona, dividir siempre el panel más grande |
| 5 | **Zed guarda reemplazando el archivo** (escritura atómica) y el archivo puede ser un enlace simbólico a `zed-config` | Bajo: el panel no se actualizaría solo | Vigilar la **carpeta** (no el archivo) y resolver el enlace. Fase 0 |
| 6 | **Errores de sintaxis en el archivo**: si el texto no se puede leer, no hay "otros proyectos" que salvar | Bajo | Se conserva la **última versión válida** y se muestra el error con su línea. Los errores de un proyecto (carpeta inexistente, pestaña sin nombre) sí se aíslan a ese proyecto |
| 7 | ⌥Espacio choca con otra app | Bajo | Raycast usa ⌘Espacio; el atajo es configurable. Se verifica en la fase 0 |
| 8 | Cambios futuros de Ghostty en su AppleScript (es nuevo en 1.4) | Medio a largo plazo | Todo el AppleScript se genera en un solo lugar (`GhosttyScriptBuilder`) con pruebas que guardan el texto esperado |

## Observaciones sobre la idea

1. **Las configuraciones de Warp tienen ventanas cruzadas, no solo la de Nexus.** Al revisarlas aparecen tres casos, no uno:
   - **Nexus**, ventana 1: `~/Desktop/data/fotos`, una carpeta que **ya no existe** (la que menciona la idea).
   - **Smart**, ventana 2: es una copia de la ventana de **Nexus** (BACKEND / FRONTEND / GLOBAL en `~/nexus`).
   - **Chaskybet**, ventana 2: es una copia de la ventana de **Smart** (API / APP en `~/dev/smart-huertas`).

   Parece que Warp guardó todas las ventanas abiertas en cada configuración. El importador debe **avisar** de las ventanas fuera de la carpeta del proyecto y de las que repiten otro proyecto, y proponer descartarlas. Probablemente los 4 proyectos queden con **una sola ventana** cada uno.
2. **"Un error no rompe los demás proyectos"** solo es posible para errores de contenido, no de sintaxis (ver riesgo 6). Propuesta: mantener la última versión buena. La alternativa sería un archivo por proyecto (como Warp), pero va contra la idea de "un archivo".
3. **Divisiones:** la idea pide "N paneles de lado a lado o hacia abajo" en una sola dirección. Cubre mis 4 proyectos. Las cuadrículas (2×2, un panel arriba y dos abajo) quedan para después: el formato lo deja abierto sin cambiar lo existente.
4. **Varias ventanas por proyecto:** se mantiene, pero tras importar probablemente no se use. "Llevarme a la ventana" traerá todas las del proyecto y dejará al frente la de la pestaña principal.
5. **Comprobar las carpetas al abrir, no solo al cargar:** una carpeta puede desaparecer mientras la app está abierta. La lista muestra el aviso y el botón de abrir lo vuelve a comprobar.
6. **Al importar no se sobrescribe nada:** si ya existe un proyecto con ese nombre, se pregunta, y antes de escribir se guarda una copia `.bak`.

## Recomendación

Seguir adelante con el plan de [`PLAN.md`](PLAN.md) y [`FASES.md`](FASES.md). La fase 0 es corta (la base ya se probó) y se centra en los riesgos 1, 2, 4 y 5. El **MVP útil llega en la fase 3**: abrir cualquiera de mis proyectos en Ghostty desde el menú de la barra, sin panel todavía. A partir de ahí ya se puede dejar de abrir Warp.
