# Lanzadera 🚀

> Un clic y tu proyecto está listo en la terminal.

Lanzadera es una app para macOS que muestra un **panel lateral con mis proyectos**. Al elegir uno, abre **Ghostty** con sus ventanas, pestañas y paneles tal como los configuré. Reemplaza las *Launch Configurations* de Warp, que es lo único que usaba de Warp.

---

## Cómo funciona

```
⌥ Espacio  (o clic en el ícono de la barra de menú)
        ↓
Se abre el panel lateral con mis proyectos
  🔴 Nexus
  🟢 Smart
  🟣 Clinicsay
  🟣 Chaskybet
        ↓
Elijo "Nexus"
        ↓
Ghostty abre una ventana con:
  BACKEND  → 3 paneles en ~/nexus/nexus-backend
  FRONTEND → 2 paneles en ~/nexus/nexus-frontend
  GLOBAL   → 1 panel en ~/nexus
```

## 1. Abrir el panel

Dos formas:

- **Atajo de teclado global**, configurable. Por defecto **⌥ Espacio**.
- **Ícono en la barra de menú**: al hacer clic se abre el mismo panel.

Se cierra con **Esc**, con el mismo atajo, o al hacer clic fuera.

## 2. El panel lateral

- Aparece desde un **costado de la pantalla**, encima de todas las ventanas, en la pantalla donde está el cursor.
- Muestra la **lista de proyectos** con su nombre y, opcionalmente, un emoji o color.
- Debajo de cada nombre, un resumen corto: por ejemplo "3 pestañas · 6 paneles".
- Un indicador muestra si el proyecto **ya está abierto** en Ghostty.
- **Buscar escribiendo:** al abrir el panel puedo escribir "nex" y queda solo Nexus.
- **Navegación con teclado:** ↑ ↓ para moverme, **Enter** para abrir.
- **Clic** sobre un proyecto también lo abre.
- Abajo, un botón **⚙️ Configurar**.

## 3. Abrir un proyecto

- Abre Ghostty con **todas las ventanas, pestañas y paneles** definidos para ese proyecto.
- Cada **pestaña** tiene su **nombre** (BACKEND, FRONTEND, GLOBAL…).
- Cada **panel** se abre en **su carpeta**.
- Los paneles se dividen **de lado a lado** o **hacia abajo**, según lo configure.
- Queda seleccionada la pestaña que yo marque como principal.
- Al abrir, el panel de Lanzadera se cierra solo.

### Si el proyecto ya está abierto

- Si el proyecto ya está abierto en Ghostty, Lanzadera **me lleva a esa ventana** en lugar de abrir otra.
- Si cerré esas ventanas, vuelve a abrir el proyecto desde cero.
- Opción para **forzar una ventana nueva** (por ejemplo, manteniendo ⌥ al hacer clic).

### Si algo falla

- Si una carpeta configurada **ya no existe**, Lanzadera avisa cuál es en vez de abrir una terminal en otro lugar.
- Si el archivo de configuración tiene un **error**, el panel muestra un mensaje claro indicando la línea, y los demás proyectos siguen funcionando.

## 4. Configuración: un archivo de texto

- Los proyectos se definen en **un archivo de texto** fácil de leer, parecido al formato de Warp.
- Se edita en **Zed**.
- El botón **⚙️ Configurar** del panel abre ese archivo en Zed.
- Al guardar el archivo, **el panel se actualiza solo**, sin reiniciar la app.
- El archivo vive en una ubicación fija (por ejemplo `~/.config/lanzadera/`), para poder guardarlo en un repo como `zed-config` si quiero.

### Qué se puede configurar por proyecto

- **Nombre** del proyecto y **emoji o color** para la lista.
- **Ícono:** se usa solo el favicon del proyecto (`apple-touch-icon`, `favicon.svg`, `favicon.ico`…) si lo tiene. Se puede elegir otra imagen o desactivarlo; sin ícono se ve el emoji o el color.
- Una o varias **ventanas**.
- En cada ventana, sus **pestañas**, con:
  - **Nombre** de la pestaña.
  - **Carpeta**.
  - **Cantidad de paneles** y si se dividen de lado a lado o hacia abajo.
  - Carpeta distinta por panel, si hace falta.
- Cuál es la **pestaña principal** que queda seleccionada.

### Colores de pestaña

Ghostty no permite colorear pestañas como Warp. Para distinguirlas se puede poner un **emoji en el nombre**, por ejemplo `🔴 BACKEND`.

## 5. Importar desde Warp

- En el primer uso, Lanzadera ofrece **importar mis configuraciones de Warp** (`~/.warp/launch_configurations/`).
- Tengo 4: **Chaskybet**, **Clinicsay**, **Nexus** y **Smart**.
- Convierte ventanas, pestañas, nombres, carpetas y divisiones. Los colores de Warp se convierten en un emoji del mismo color.
- Después de importar, puedo revisar y ajustar el archivo en Zed.

> Revisar al importar: la configuración de **Nexus** en Warp tiene una primera ventana en `~/Desktop/data/fotos` que probablemente no sea parte del proyecto.

## 6. Barra de menú

El ícono de la barra de menú, además de abrir el panel, tiene:

- Abrir el panel.
- Configurar (abre el archivo en Zed).
- Importar desde Warp.
- Iniciar al encender la Mac.
- Salir.

## 7. Primer uso

1. Abrir Lanzadera: aparece el ícono en la barra de menú.
2. macOS pide permiso para que Lanzadera **controle Ghostty**. Hay que aceptarlo.
3. Lanzadera ofrece importar las configuraciones de Warp.
4. Listo: ⌥ Espacio y elegir un proyecto.

---

## Prueba de concepto (ya hecha)

El 28/10/2026 se comprobó en **Ghostty 1.4** y **macOS 27** que se puede, desde fuera de Ghostty:

- Crear una ventana nueva.
- Crear pestañas y ponerles nombre.
- Dividir paneles.
- Abrir cada panel en una carpeta.

Se replicó la configuración de Nexus de Warp, con 3 pestañas y 6 paneles, y todas las carpetas quedaron correctas. Ghostty lo permite con su soporte oficial de AppleScript.

---

## Segunda etapa

- **Comandos automáticos al abrir** cada panel. Por ejemplo, FRONTEND ejecuta `npm run dev` y BACKEND `npm run start:dev`.
- **Variables de entorno** por panel.
- **Cerrar un proyecto** completo desde el panel (todas sus ventanas).
- Abrir también el proyecto en **Zed** junto con la terminal.

## Ideas para el futuro

- Agrupar proyectos por cliente o categoría.
- Proyectos recientes primero.
- Acceso desde el bot de **Vigilia**: abrir un proyecto en la Mac desde Telegram.
