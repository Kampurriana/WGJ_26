# Iluminación: cómo está hecha la luz y cómo se ajusta

**De momento la luz la llevamos nosotros** (Claude y quien lleva el proyecto), en la rama
`programacion`. Si más adelante alguien del equipo se encarga de ella, vuelve a tener su rama
`iluminacion` y esta carpeta pasa a ser suya (ver `GIT-Y-RAMAS.md`).

La luz es **en tiempo real** (nada horneado) y el **fondo es oscuro**: el diorama es una maqueta
iluminada en un cuarto a oscuras. Por qué así y de dónde sale cada idea: `ANALISIS-WOODO.md`.

| Fichero | Qué es |
|---|---|
| `luz_por_defecto.tscn` | La luz de todos los niveles que no tengan una propia |
| `menu.tscn` | La luz del cofre del título (y del menú) |
| `probar_luz.tscn` | Para mirarla en el editor: la luz por defecto + la habitación + la cámara del juego |
| `rig_luz.gd` | El script de la raíz de cada escena de luz (lo que la hace "en tiempo real") |
| `fondo.gdshader` | El degradado oscuro del fondo, con un halo cálido detrás del diorama |
| `vineta.gdshader` | La viñeta: oscurece un poco las esquinas |

## Qué hay dentro de una escena de luz

- **`Iluminacion`** (la raíz, con `rig_luz.gd`). En el Inspector:
  - *Seguir Camara* (0 a 1): 1 = la luz gira con la cámara. Al girar el diorama las sombras se
    mueven sobre él y el lado que miras siempre está bien iluminado. 0 = luz fija en el mundo.
  - *Color Inicio / Energia Inicio*: la luz principal con el diorama **sin montar** (fría, tenue:
    escena "congelada").
  - *Color Final / Energia Final*: con el diorama **completo** (cálida, plena). En medio, según
    las piezas puestas.
  - *Segundos Cambio*: lo que tarda en ponerse al día después de cada pieza.
- **`Ambiente`** (WorldEnvironment) → su `Environment`:
  - *Background → Mode: Canvas*: el fondo es la capa `Fondo` (no lo cambies a Color: se perdería
    el degradado).
  - *Ambient Light → Color / Energy*: la luz que llega a todas partes (aclara las sombras).
  - *Tonemap*: AgX. *Glow*: activado, hace brillar faroles, lámparas y chispas.
- **`Sol`** (DirectionalLight3D): la luz principal, con sombras. Su color y energía los pone el
  script (los de inicio/final de arriba): cambiarlos aquí no sirve.
- **`Contraluz`** (DirectionalLight3D, sin sombras): desde detrás, fría. Recorta el diorama
  contra el fondo oscuro.
- **`Fondo` → `Degradado`**: en *Material → Shader Parameters*: *Color Centro* (el halo), *Color
  Borde* (casi negro), *Centro* y *Radio* del halo.
- **`Vineta` → `Sombra`**: *Fuerza* (0 = sin viñeta) y *Suavidad*.

## Luces dentro de los modelos

- Una luz que cuelga de una pieza `P_` (el farol del título, la lámpara del escritorio) **está
  apagada mientras la pieza es silueta y se enciende con un fundido al colocarla**.
- Las luces del decorado (fuera de una `P_`) están siempre encendidas.
- Las artistas pueden poner luces en Blender: el `.glb` las trae (ver `ARTE-PIPELINE.md`).

## Cómo trabajar

1. **Godot:** abre `iluminacion/probar_luz.tscn`. Para verlo con la cámara del juego: selecciona
   `CamaraDeJuego` y marca **Preview** arriba en la vista 3D. En el editor no gira con la cámara
   ni cambia con el progreso: eso solo pasa jugando.
2. **Para cambiar la luz**: pulsa el icono de claqueta junto a `Iluminacion` (abre
   `luz_por_defecto.tscn`), cambia valores y guarda (**Ctrl+S**).
3. **F5** para verla de verdad: con la madera cruda, la pintura, las siluetas y las partículas.
4. **Pide a Claude que la mida** ("mide la luz"): captura del juego + captura del fondo solo, y
   comprueba que nada sale quemado. Comandos:
   ```
   bash tools/capture.sh build/c.png 6 0 --capture-after=5
   bash tools/capture.sh build/fondo.png 0 0 --solo-fondo
   python3 -I tools/medir_luz.py build/c.png --fondo build/fondo.png
   ```
   `quemado` tiene que salir por debajo del 2 %. Medido el 16-oct-2026: 0,0 % en la habitación
   (sin montar, a medias y completa) y en el cofre del título.

## Luz propia para un nivel

Clic derecho en `luz_por_defecto.tscn` → *Duplicate* → llámala como el nivel. Ajústala y pide a
Claude que se la asigne (propiedad `Iluminacion` del nivel).

## Cuidado

- Renderer **Compatibility** (el único que funciona en el navegador): SSAO, SSR, SDFGI, niebla
  volumétrica y profundidad de campo no hacen nada. Sí funcionan: sombras de todas las luces,
  glow y el fondo por capa.
- **El fondo pasa por el tonemap**: un color de halo sale bastante más oscuro en el juego que en el
  selector de color (medido: 0,17 se ve como 0,07). Súbelo más de lo que parece.
- **Cada luz con sombra cuesta una pasada más** de dibujo en Compatibility. Las luces de las piezas
  van sin sombra a propósito; si se añade una con sombra, medir que el navegador lo aguanta.
- **No guardes escenas de otras carpetas** (`levels/`, `scenes/`...) con el editor abierto mientras
  Claude trabaja: el editor puede pisar sus cambios.
