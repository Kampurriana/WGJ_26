# GDD — clon mecánico de Woodo

**Woodo** (Tiny Monks Tales / Daedalic, 16-sep-2026; PC, PS5, Xbox, Switch 1 y 2). Puzle "cozy" de
dioramas de madera: cada escena está a medio hacer, faltan piezas, y al colocarlas la escena se llena
de color y se anima. Sin tiempo, sin fallar, sin enemigos. Un narrador acompaña. Unas 3-4 h,
"cientos de piezas".

Cada fila dice **de dónde sale**: *visto* = lo dicen la ficha de Steam o varias reseñas;
*supuesto* = deducción nuestra que hay que confirmar jugando. No mezclar las dos al decidir.
El **aspecto** (luz, fondo, materiales, partículas, cámara, bandeja) está en `ANALISIS-WOODO.md`.

## Mecánicas y dónde están en el código

| # | Mecánica | Fuente | Implementación |
|---|---|---|---|
| 1 | Diorama sobre una peana; se gira y se acerca/aleja para buscar huecos | visto (los límites: decisión del equipo) | `camera/diorama_camera.gd`: sin desplazamiento, giro dentro de límites por nivel, zoom con tope hacia el cursor, suavizado |
| 2 | Las piezas que faltan se ven como **versiones blancas** en su sitio | visto | `core/piece_slot.gd` + `shaders/ghost.gdshader` (silueta translúcida con borde) |
| 3 | La escena empieza **sin pintar (madera cruda)**; al colocar, **la pintura se extiende** por la madera de alrededor y se anima | visto | `shaders/madera_cruda.gdshader` + `Diorama._reveal_around` (mancha que crece por píxel, radio `color_radius`) + `AnimationPlayer` `<id>_placed` |
| 4 | Bandeja de piezas **a la derecha, estrecha y con scroll**; se recoge cuando queda vacía | visto (dos columnas: supuesto) | `ui/hud.gd` |
| 5 | Se **arrastra** cada pieza del panel a su hueco; encaja con un "clic" táctil. La pieza en mano no atraviesa paredes, suelo ni muebles (decisión del equipo) | visto | `ui/drag_controller.gd` (choque por el rayo del cursor, imán al acercarse) + `Diorama.try_place` + sonido `snap` |
| 6 | **Al girar el diorama, las piezas del panel giran también**: se ven con la orientación que tendrán en su hueco | visto | `ui/inventory_item.gd` (`_process` copia la rotación relativa a la cámara) |
| 7 | El jugador **no rota las piezas** a mano | supuesto | se colocan ya orientadas como su hueco |
| 8 | Soltar en mal sitio no penaliza: la pieza vuelve al panel | supuesto | rechazo con temblor de la ficha + sonido `reject` |
| 9 | Piezas iguales (dos sillas) valen en cualquiera de sus huecos | supuesto | mismo id; Blender `.001` se ignora |
| 10 | **Pista recargable**: **gira y acerca** la cámara y enseña dónde va una pieza | visto (recarga: una reseña) | `Hud.request_hint` (recarga `hint_cooldown`=25 s) + `look_at_point` + el hueco late + chispas |
| 11 | El juego **se adapta al ritmo** y ofrece ayuda cuando hace falta | visto (Steam) | si no hay progreso en `assist_after`=45 s, la pista se recarga sola y brilla |
| 12 | Cajones y armarios que **se abren** para encontrar piezas escondidas | visto | `OD_` (cajón), `OR_` (puerta), `H_` (escondido) en `core/interactable.gd` |
| 13 | Más adelante, piezas que hay que **encontrar primero en el propio nivel** | visto | `H_`: al pulsarla pasa al inventario |
| 14 | Más adelante, piezas que van **en un orden concreto** | visto | token `__after-<id>` u `order_rules` del Diorama; si no toca, el narrador lo dice |
| 15 | **Escenas dentro de escenas**: se hace zoom a un rincón (la casa del ratón), se completa, y devuelve una pieza a la escena grande | visto | `Z_<nombre>__reward-<id>` (`Diorama.enter_focus/exit_focus`); el panel solo enseña las piezas de ese rincón |
| 16 | Narrador con voz y subtítulos; cuenta la historia entre escenas | visto | `autoload/narrator.gd` + `data/narracion_es.json` + `assets/audio/voz/<clave>.ogg` |
| 17 | Animales y personajes reaccionan al pasar cerca / al completar | visto | hook: animación `celebrar` al completar; reacciones al girar = **pendiente** |
| 18 | Ratón, mando (joystick como puntero) y táctil | visto | `input/gamepad_cursor.gd`, pellizco en la cámara, táctil emula ratón |
| 19 | Escenas de historia animadas entre niveles | visto | **pendiente** (para la jam: una viñeta + narración entre niveles) |
| 20 | **El menú de inicio se desbloquea con un puzle**: un **cofre de madera** con las **letras del nombre del juego** (una pieza por letra) y un paisaje pequeño encima; al montarlo aparece el menú. En las siguientes partidas sale ya montado | visto (letras del logo y cofre que es el menú: Game Asylum, GameGrin) | `levels/menu_titulo.tscn` (carga `levels/provisional/menu_provisional.glb` o el de las artistas) + `scenes/main.gd` (`show_title`) + `ui/main_menu.gd` |
| 22 | **Colocar enciende las luces** de la pieza (farol, lámpara) | visto (una fuente, textual) | `PieceSlot.fill` (fundido) |
| 21 | Menú completo: Jugar/Continuar, Elegir diorama, Opciones (volúmenes, subtítulos, pantalla completa, cámara, pista automática, borrar progreso), Créditos, Salir; pausa con Esc | pedido del equipo | `ui/main_menu.gd`, `ui/pause_menu.gd`, `ui/options_panel.gd`, `autoload/settings.gd` |

## Bucle de un nivel

1. Entra el diorama, el narrador presenta la escena (`intro_key`).
2. El jugador gira y acerca para leer qué falta (siluetas blancas).
3. Arrastra piezas del panel. Encaje → color que se expande + animación + sonido + frase opcional.
4. Lo escondido se busca abriendo cosas; los rincones `Z_` se completan con zoom.
5. Todo puesto → todo se colorea, animación `celebrar`, frase final, panel "Siguiente".

## Sensación (lo que más importa en una jam)

- **Tacto**: el "clic" del encaje (sonido corto, seco, con variación de tono), el pequeño rebote de
  escala al colocar (`_pop`), el imán que coge la pieza los últimos centímetros.
- **Calma**: sin temporizadores visibles, sin "error" rojo, música suave, colores que se despiertan.
- **Lectura**: las siluetas tienen que distinguirse de la madera cruda desde la vista general
  (ajustar `base_alpha` de `ghost.gdshader` y los colores de `madera_cruda.gdshader` con capturas,
  no a ojo).
- **Vida**: polvo flotando en la luz, serrín y chispas al encajar, la luz que se calienta al montar,
  hojas al completar (`core/efectos.gd`, `iluminacion/rig_luz.gd`).

## Fuera de alcance para 48 h (salvo que sobre tiempo)

Localización a 8 idiomas, logros, escenas de historia animadas largas, guardar a mitad de un
nivel. Ya está hecho: menú completo con opciones, créditos, pausa y progreso por niveles
(qué dioramas están completados).

## Fuentes

Leídas enteras (16-oct-2026): ficha de Steam (app 2572040), Indie Games Plus (preview), Console
Creatures, Aftermath, GameWithUni. Vistas solo en extractos de búsqueda (no leídas enteras): The Xbox
Hub, LadiesGamers, TheGamer, CBR. La recarga de la pista (#10) y el giro de las piezas con el diorama
(#6) salen de esos extractos: son de lo primero que hay que confirmar jugando.
