# Análisis estético y técnico de Woodo (para el prototipo)

Hecho el 16-oct-2026 para copiar de Woodo el **aspecto** (luz, materiales, partículas, cámara,
bandeja de piezas, título) y no solo las mecánicas (esas están en `GDD-WOODO.md`).

## 0. Cómo se ha hecho y cuánto fiarse

- Fuentes: 18 reseñas, avances y guías (lista al final). **Solo se han leído los extractos que da
  el buscador**: desde la nube no se pueden abrir las páginas, ni Steam, ni vídeos. Ningún tráiler
  se ha visto.
- Cada rasgo lleva su origen: **visto** = lo dicen dos o más fuentes, o una cita textual clara;
  **una fuente** = lo dice una sola; **supuesto** = deducción o decisión nuestra, a confirmar
  mirando el juego. Lo que no sale en ninguna fuente lo dice: el fondo oscuro, por ejemplo, es
  **petición del equipo** (no hay fuente que lo describa).
- Lo que más falta: cómo son exactamente las partículas, el fondo y los movimientos de cámara al
  completar. Lista de dudas para resolver con el juego delante en el §4.

## 1. Lo que se sabe del aspecto de Woodo

### Materiales y color

| Rasgo | Origen |
|---|---|
| Todo parece tallado en madera: "cada elemento, una pequeña escultura de madera", "aspecto tallado a mano, lijado hasta quedar perfecto", bordes suaves | visto (TheGamer, Michael Cavacini, CBR) |
| Algunas piezas parecen de **arcilla**; el agua es realista | una fuente (TheGamer) |
| La escena empieza **sin pintar**: "maqueta de madera sin terminar", "acabado marrón de madera al principio", "dioramas apagados, casi fantasmales", "escena congelada" | visto (Cavacini, Xbox Hub, Nintendo Life, Daedalic) |
| Al colocar una pieza, **la pintura se extiende por la madera de alrededor** ("baña la madera de pintura cálida") y arrancan microanimaciones | visto (Cavacini, Bonus Action, LadiesGamers) |
| Las piezas que faltan se ven como **versiones blancas** en su sitio | visto (Indie Games Plus, GDD) |

### Luz

| Rasgo | Origen |
|---|---|
| Luz **suave** y cálida; "la luz hace que cada diorama parezca un objeto físico" | visto (Noisy Pixel, TheGamer, Indie Games Plus) |
| **Colocar piezas enciende animaciones y luces al instante**, sin pulsar nada más | una fuente, textual (Indie Games Plus) |
| Colores vivos una vez pintado; paleta cálida | visto |
| Fondo oscuro | **petición del equipo** (ninguna fuente lo describe) |

### Partículas

| Rasgo | Origen |
|---|---|
| Hay partículas y forman parte de la dirección de arte (junto a la música, los "chasquidos de madera" y la luz suave) | una fuente (Noisy Pixel) |
| Qué partículas exactamente | **ninguna fuente**: supuesto (ver §3) |

### Cámara

| Rasgo | Origen |
|---|---|
| Se gira el diorama entero y se acerca/aleja; no se giran las piezas | visto (CBR, Xbox Tavern, guías) |
| Hay desplazamiento (pan) y a una reseña le molesta que "el pan también acerca" | una fuente (Missi) |
| La cámara es **lo que más se critica**: "quisquillosa", "a veces peleas con ella" para el ángulo y el zoom | visto (Xbox Tavern, PressPlay, Nintendo Life) |
| Ratón: botón derecho y central; al principio sin atajos de teclado | una fuente (Missi) |
| La **pista gira y acerca la cámara** hasta el sitio correcto | una fuente, textual (Xbox Tavern) |
| Rincones con zoom (escena dentro de escena) | visto (GDD) |
| Movimiento al completar un diorama | **ninguna fuente**: supuesto |

### Bandeja de piezas (panel de la derecha)

| Rasgo | Origen |
|---|---|
| **Barra a la derecha, con scroll**, con la lista de objetos que faltan | visto (Xbox Hub, GDD) |
| Las piezas **giran con el diorama**: cuando el frente de la pieza te mira, su sitio está en el lado que estás viendo | visto (LadiesGamers, Xbox Tavern, guía) |
| No se pueden girar las piezas de la barra | visto (guías) |
| La escena se acaba cuando **la bandeja queda vacía**; las piezas grandes primero "para despejar la barra" | una fuente (guía, 9Puz) |
| La pieza en mano **cambia de tamaño y gira según dónde está el cursor**, y eso da pistas de dónde va | una fuente, textual (Noisy Pixel) |
| Imán que acerca la pieza a su sitio, regulable o desactivable | una fuente (Noisy Pixel) |

### Título y menú

| Rasgo | Origen |
|---|---|
| La pantalla de título **es un puzle**: se encajan las **letras de madera** del logo en su sitio | visto (Game Asylum, guías) |
| Después se monta un **cofre pequeño decorado** que resulta ser el menú principal; se gira el cofre y se vacía su bandeja | visto (GameGrin, 9Puz, guía) |
| Sirve de tutorial antes de conocer a Foxy | una fuente (Game Asylum) |

## 2. Qué deja hacer nuestro motor (medido, no supuesto)

Godot 4.7.2 con el renderer **Compatibility** (el único que exporta a navegador). Probado el
16-oct-2026 con una escena de prueba renderizada en la nube (llvmpipe):

| Función | ¿Funciona? | Uso |
|---|---|---|
| Luces en tiempo real con sombras: direccional, foco (SpotLight3D) y puntual (OmniLight3D) | sí | sol, contraluz, faroles y lámparas de las piezas |
| Glow (resplandor) | sí | brillo de las luces y de las chispas |
| Fondo hecho con una capa 2D detrás del 3D (degradado radial) | sí | fondo oscuro con halo cálido |
| CPUParticles3D | sí | todas las partículas (las de GPU no se usan: en navegador fallan más) |
| Shader con un array de esferas (pintura que se extiende por píxel) | sí | la onda de pintura |
| Exportar a `.glb` desde Godot y volver a importarlo con nombres, letras 3D y luces | sí | el diorama del título como asset |
| SSAO, SSR, SDFGI, niebla volumétrica, profundidad de campo | **no** en Compatibility | sin oclusión ambiental ni desenfoque real |

## 3. Traducción al prototipo (qué se ha hecho y dónde)

| Rasgo de Woodo | En nuestro juego | Origen | Dónde |
|---|---|---|---|
| Escena sin pintar | Todo lo que no es pieza empieza en **madera cruda con veta** (no blanco): color de pino claro con vetas, iluminado | visto | `shaders/madera_cruda.gdshader`, `Visuals.make_clay_overlay` |
| La pintura se extiende | Al encajar, una **onda de pintura** crece desde la pieza por cada píxel, con el borde irregular como pintura que empapa | visto | `Diorama._reveal_around` → esferas del shader |
| Huecos en blanco | Siluetas blancas translúcidas (se leen aún mejor sobre fondo oscuro) | visto | `shaders/ghost.gdshader` |
| Luz suave que hace "objeto físico" | Sol cálido con sombras suaves + **contraluz** frío que recorta el diorama contra el fondo + ambiente bajo | visto | `iluminacion/*.tscn` |
| Luz en tiempo real | La luz **gira con la cámara**: al girar el diorama las sombras se mueven sobre él (como una maqueta en un plato giratorio bajo un flexo). La pieza en mano proyecta sombra | petición + supuesto | `iluminacion/rig_luz.gd` (`seguir_camara`) |
| La luz despierta con el diorama | La luz va de **fría y tenue** (escena congelada) a **cálida y plena** según el porcentaje de piezas puestas | supuesto (a partir de "escena congelada" que "se calienta") | `rig_luz.gd` (`color_inicio`, `color_final`) |
| Colocar enciende luces | Toda luz que cuelga de una pieza `P_` está apagada hasta colocarla y entonces **se enciende con un fundido** | una fuente, textual | `PieceSlot.fill` |
| Fondo oscuro | Degradado radial casi negro con un halo cálido detrás del diorama + viñeta suave | petición | `iluminacion/fondo.gdshader` |
| Partículas | **Polvo en suspensión** que brilla en la luz; al encajar, **serrín** que salta y **chispas** que suben + un **anillo** en el suelo; al recoger algo escondido, un soplo; en la pista, chispas que giran; al completar una sección o el diorama, **luces cálidas que suben despacio** (luciérnagas; las hojas se quitaron: el equipo las quería más cozy) | supuesto (Noisy Pixel solo dice que hay partículas) | `core/efectos.gd` |
| Cámara suave | Todo con **muelles amortiguados** (nada arranca ni frena de golpe); giro con **inercia**, zoom hacia el cursor, límites por nivel | visto + decisión del equipo | `camera/diorama_camera.gd` (`_spring`) |
| La pista mueve la cámara | La pista **gira y acerca** la cámara hasta el hueco | una fuente, textual | `DioramaCamera.look_at_point` |
| Entrada al nivel | La cámara **entra desde lejos** y se posa en el encuadre, tras un fundido desde negro | supuesto | `DioramaCamera.intro`, `main.gd` |
| Al encajar | La cámara **se acerca despacio** a la pieza (4 %), se queda un momento y vuelve sola; el giro del jugador no se nota afectado (el empujón brusco anterior se quitó por petición del equipo) | supuesto | `DioramaCamera.nudge` |
| Al abrir una zona | La cámara **se gira y se acerca** a la zona nueva, despacio | supuesto | `DioramaCamera.frame_box` |
| Al completar | La cámara se aleja un poco y **se mece de lado a lado** enseñando el diorama acabado | supuesto | `DioramaCamera.showcase` |
| Bandeja a la derecha | Bandeja oscura y estrecha en **dos columnas de fichas pequeñas**, scroll con la rueda, la pieza crece al pasar el ratón y gira con el diorama | visto (barra, scroll, giro) + supuesto (dos columnas) | `ui/hud.gd`, `ui/inventory_item.gd` |
| Título con letras de madera | El diorama del título es **un cofre de madera**: se encajan las **letras del nombre del juego** (las tres O valen en cualquier hueco de O) y piezas pequeñas encima del cofre (casita, árboles, faroles que se encienden, banco). Al acabar, sale el menú | visto | `levels/menu_titulo.tscn`, `tools/build_title_level.gd` |
| Que el arte se pueda cambiar | El título es **un solo `.glb`** con piezas `P_`. Si existe `assets/modelos/menu/menu.glb` (el de las artistas) se usa ese; si no, el provisional. Cualquier nivel puede cargar así su modelo | petición del equipo | `Diorama.modelo`, `docs/ARTE-PIPELINE.md` |

Lo que **no** se ha copiado y por qué:
- Desplazamiento libre de la cámara: el equipo lo quitó a propósito (es lo que más se critica de
  Woodo).
- Profundidad de campo o efecto miniatura (tilt-shift): Compatibility no tiene DOF. Un desenfoque
  hecho a mano cuesta caro en navegador. Si se quiere, se puede probar como opción.
- Oclusión ambiental: no existe en Compatibility. La compensa el contraluz.

## 4. Para confirmar con el juego delante (10 minutos)

Si alguien del equipo tiene Woodo o ve un tráiler, esto es lo que más cambia el prototipo:

1. **Fondo**: ¿negro, de color, con halo, una mesa, un cielo?
2. **Partículas**: ¿hay polvo flotando? ¿Qué sale al encajar una pieza: serrín, chispas, nada?
3. **Al completar**: ¿la cámara hace algo (se aleja, gira sola)? ¿Hay confeti o chispas?
4. **La luz**: ¿se mueve al girar el diorama (las sombras cambian) o está fija?
5. **La bandeja**: ¿una columna o varias? ¿Las piezas se ven a su tamaño relativo?
6. **El cofre del título**: ¿qué hay encima? ¿Cómo se vacía su bandeja?
7. **La escena sin pintar**: ¿madera clara, marrón, gris?
8. **La pieza en mano**: ¿cambia de tamaño al pasar por encima de su sitio?

Cada respuesta es un ajuste de valores en los ficheros de la tabla del §3, no un sistema nuevo.

## Fuentes (16-oct-2026, extractos del buscador)

Reseñas: [TheGamer](https://www.thegamer.com/woodo-review-wooden-3d-puzzle-game/) ·
[Noisy Pixel](https://noisypixel.net/woodo-review/) ·
[Nintendo Life](https://www.nintendolife.com/reviews/nintendo-switch-2/woodo-nintendo-switch-2-edition) ·
[Game Asylum](https://www.gamesasylum.com/2026/09/16/woodo-review/) ·
[Xbox Tavern](https://www.xboxtavern.com/woodo-review/) ·
[The Xbox Hub](https://www.thexboxhub.com/woodo-review/) ·
[LadiesGamers](https://ladiesgamers.com/woodo-review/) ·
[Michael Cavacini](https://michaelcavacini.com/2026/10/13/woodo-review-handcrafted-toybox-puzzles-in-stunning-4k/) ·
[PressPlay News](https://pressplaynews.net/2026/09/17/woodo-review-ps5/) ·
[CBR](https://www.cbr.com/woodo-puzzle-adventure-review/) ·
[Missi the Achievement Huntress](https://www.missitheachievementhuntress.com/woodo-review/)

Avances: [Indie Games Plus](https://indiegamesplus.com/woodo-preview/) ·
[GameGrin](https://www.gamegrin.com/previews/woodo-preview) ·
[Bonus Action](https://bonus-action.com/guides/best-10-steam-next-fest-demos-that-wouldnt-let-me-go/)

Guías: [9Puz](https://9puz.com/5785-woodo-walkthrough/) ·
[Into Indie Games](https://intoindiegames.com/walkthrough-hub/woodo-guides-tips-and-walkthrough/)

Prensa: [Daedalic](https://daedalic.prezly.com/woodo-a-small-diorama-world-makes-a-big-multiplatform-impact) ·
[foro3d](https://foro3d.com/2026/octubre/woodo-puzles-meditativos-con-arte-de-ghibli-y-logica-de-diorama.html)
