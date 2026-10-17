# Guía para las artistas: del Blender al juego

Lo jugable se define **por los nombres de los objetos** en Blender. No hace falta abrir Godot ni
tocar código: modeláis la escena **completa y pintada**, nombráis bien, exportáis `.glb` y lo
subís. El juego la cubre de **madera sin pintar**, quita las piezas (las deja como siluetas
blancas) y monta el puzle solo; al colocar cada pieza, la pintura se extiende a su alrededor.

**Todo lo que hay ahora es provisional** (figuras simples y un pack de props): está montado para
que vuestro arte entre **dejando el fichero en su sitio**, sin tocar escenas ni código.

## 1. Cómo se modela un diorama

- Modelad la escena **terminada**, con todas las piezas en su sitio y con su color/textura final.
  No hagáis versiones blancas: el juego las genera.
- Escala real: **1 unidad = 1 metro**. Un diorama de muestra mide unos 3-4 m de ancho.
- Todo el diorama dentro de **un solo `.glb` por nivel** (un nivel = un diorama).
- La peana/base de madera también va en el `.glb`.

## 2. Los nombres (lo único obligatorio)

El **nombre del objeto** en Blender (no el de la malla) empieza por un prefijo:

| Prefijo | Qué es | Ejemplo |
|---|---|---|
| `P_` | Pieza que falta. Su hueco blanco sale en la escena y la pieza en el panel | `P_taza`, `P_silla` |
| `H_` | Pieza escondida: el jugador la encuentra y la pulsa. **Tiene que existir también su `P_`** (donde va) | `H_cuchara` dentro de un cajón + `P_cuchara` en la mesa |
| `OD_` | Cajón: se desliza hacia fuera al pulsarlo | `OD_cajon_arriba` |
| `OR_` | Puerta o tapa: gira 90º sobre su **origen** (poned el origen en la bisagra) | `OR_armario` |
| `Z_` | Rincón con zoom (una escena dentro de la escena). Sus `P_` se hacen dentro | `Z_ratonera` |
| `S_` | **Sección**: una zona que se monta entera antes de pasar a la siguiente. `S_<orden>_<nombre>`. Todo lo de la zona (piezas, muebles, su bombilla) cuelga de ella. Mientras está cerrada no se ve nada suyo; al abrirse sale el rótulo de capítulo y aparece | `S_2_infancia` |
| (otro) | Decorado: se queda en la escena, empieza en madera sin pintar y se pinta al completar piezas cerca | `Arbol`, `Pared` |

Detrás del nombre, opciones con **doble guion bajo**:

| Opción | Dónde | Qué hace |
|---|---|---|
| `__after-mesa` | en un `P_` | no se puede poner hasta que todas las `P_mesa` están puestas (así se cuenta la historia de uno en uno; mientras, su ficha lleva candado) |
| `__clave` | en un `P_` | va **la última** de su sección y la cierra (la nutria, el espejo...) |
| `__flash` | en un `P_` | destello blanco al colocarla (la cámara de fotos) |
| `__reflejo` | en un `P_` | su momento es de frente y con todo lo demás a negro, con una silueta en la luna (el espejo). **La cara del espejo mira hacia su +Z local** (hacia delante en Blender, -Y; el exportador lo convierte) y la malla del cristal se llama `Luna`, `Cristal` o `Espejo` |
| `__ofrecida` | en un `P_` | no va a la bandeja: cuando toca, aparece flotando junto a su hueco y el jugador la arrastra hasta él (la moneda en la hucha). La sección que la tiene se abre con un corte a lo que la sostiene, solo y visto un poco desde arriba |
| `__reward-cuadro` | en un `Z_` | al completar el rincón, el jugador recibe la pieza `cuadro` (hace falta un `P_cuadro`) |
| `__x` `__nx` `__z` `__nz` `__y` `__ny` | en un `OD_` | eje por el que sale el cajón si no sale bien por defecto |
| `__n` | en un `OR_` | la puerta abre hacia el otro lado |
| `__x` | en un `OR_` | bisagra horizontal: es una **tapa** que se levanta (un baúl) |

Reglas de los nombres:
- Ids en minúscula, sin espacios ni acentos, empezando por letra: `P_taza_roja` sí, `P_Taza Roja` no.
- **Piezas iguales = mismo nombre.** Blender pondrá `P_silla.001`, `P_silla.002`: está bien, el
  juego lo entiende como "tres sillas iguales".
- No terminéis un nombre en `-col`, `-colonly`, `-rigid`, `-noimp`, `-navmesh`, `-occ` o `-loop`:
  Godot los lee como órdenes de importación y cambia el objeto.
- Una pieza `P_` puede tener hijos (patas, tablero…): todo lo que cuelga de ella es la pieza.
- Lo que va **dentro de un cajón** (un `H_`) tiene que ser **hijo del cajón**, para que se mueva con él.
- Lo que va **dentro de un armario o un baúl** (con puerta o tapa `OR_`) NO es hijo de la puerta
  (giraría con ella): es **hermano** de la puerta, dentro del mismo grupo del mueble
  (`Armario` → `OR_puerta`, `Balda`, `H_camara`).
- Mientras no toca encontrarlo, un `H_` no se ve (su silueta, donde va, sí); cuando toca, su mueble
  brilla con un contorno dorado y se mueve un poco.
- Las piezas de un `Z_` son hijas del `Z_`.
- **Objetos planos de pared con frase** (un dibujo, un tablero de llaves): su cara mira hacia su +Z
  local (hacia delante en Blender, -Y); su momento los enseña de frente.
- **Cajones:** con el diorama visto en vista frontal de Blender (tecla 1 del teclado numérico), el
  frente del cajón mira hacia vosotras. Si al probar sale hacia otro lado, añadid `__x`, `__nx`…
  o decídselo a Claude.

### El diorama principal: el desván

Es el de la historia (`docs/GUION.md`). Ahora es provisional (figuras simples y props del pack);
el vuestro va en **`assets/modelos/desvan/desvan.glb`** y el juego lo usa solo en cuanto existe.
Estructura que espera (los nombres de las piezas, en `levels/provisional/desvan_provisional.tscn`;
si queréis una plantilla `.glb` para abrir en Blender, pedídsela a Claude):
```
Desvan
├─ suelo, peana y trastos (decorado, siempre a la vista)
├─ S_1_desvan        P_pared_fondo, P_pared_izquierda, P_pared_derecha, P_cumbrera__after-..., P_tejado__after-cumbrera (x3),
│                    P_viga__after-cumbrera (x2), P_ventana__after-pared_derecha, P_hucha__clave
├─ S_2_infancia      Bombilla (con su luz), BaulJuguetes (OR_tapa_baul__x + H_cubos), P_cama_infantil, ...,
│                    P_caja_musica__after-comoda_infantil, P_dibujo__after-caja_musica, P_peluche__clave
├─ S_3_adolescencia  Bombilla, Armario (OR_puerta_armario__n + H_camara), Cajonera (OD_cajon_cajonera > H_solicitud), ...,
│                    P_mp3__after-escritorio, P_camara__after-mp3__flash, P_solicitud__clave
├─ S_4_adultez       Bombilla, Mesita (OD_cajon_mesita__nx > H_pinceles), ..., P_llaves, P_caballete__after-llaves,
│                    P_espejo__clave__reflejo (con su malla Luna)
└─ S_5_epilogo       P_moneda__ofrecida (encima de la hucha)
```

### El título: la hucha de cerdito

Va en **`assets/modelos/menu/menu.glb`** (provisional: `levels/provisional/menu_provisional.glb`).
Sin secciones; el orden lo dan los `__after`:
```
Cerdito
├─ Peana, Cojin, monedas sueltas (decorado)
├─ Hucha (grupo)   P_cuerpo; P_pata__after-cuerpo (x4), P_hocico__after-cuerpo, P_oreja__after-cuerpo (x2),
│                  P_cola__after-cuerpo, P_ranura__after-cuerpo, P_ojo__after-hocico (x2), P_mejillas__after-ojo,
│                  P_lazo__after-oreja, P_pegatina_estrella__after-cuerpo (con una luz: brilla en la oscuridad),
│                  P_pegatina_corazon / _flor / _luna / _rayo / _arcoiris (__after-cuerpo)
└─ Cartel          P_pegatina_nombre__after-cuerpo (el texto del nombre del juego, en una malla "Nombre-WOODO_JAM")
```
Las pegatinas son formas planas con un poco de grosor, pegadas al cuerpo. Se pueden cambiar,
quitar o añadir más (`P_pegatina_<lo que sea>__after-cuerpo`); la del nombre tiene que seguir
llamándose así (el test comprueba que lleva el nombre del juego).
Podéis cambiar formas, tamaños, posiciones y añadir o quitar dressing: el puzle se monta con lo
que haya. Lo único que no se puede tocar sin avisar son los nombres de las piezas de la historia
(sus frases van por nombre).

## 3. Luces dentro del modelo (opcional)

- Las luces de Blender (punto y foco) viajan dentro del `.glb`: al exportar, marcad
  **Include → Punctual Lights**.
- Una luz **hija de una pieza `P_`** (la bombilla de una lámpara, la vela de un farol) está
  apagada mientras la pieza es silueta y **se enciende al colocarla**.
- Una luz **del decorado de una sección** (la bombilla de la zona) se enciende cuando se abre la
  sección. Una luz del decorado fuera de secciones está siempre encendida.
- Las unidades de Blender y de Godot no coinciden: si salen muy fuertes o muy flojas, decídselo a
  Claude, que lo ajusta para todo el nivel con un número (`escala_luces`), sin reexportar.
- Para que algo brille (el cristal de un farol): material con **Emission**. El juego tiene glow.

## 4. Animaciones (opcional, pero da mucha vida)

- Acción llamada `<id>_placed` → se reproduce al colocar esa pieza (ej. `pato_placed`: el pato
  sacude las alas).
- Acción llamada `celebrar` → al completar el diorama.
- Exportad las animaciones dentro del mismo `.glb`.

## 5. Exportar

`Archivo → Exportar → glTF 2.0`:
- Formato: **glTF Binary (.glb)**
- Incluir: objetos seleccionados o todo el diorama; **+Y arriba** activado (viene por defecto)
- Malla: **aplicar modificadores**
- Materiales: exportar; texturas dentro del `.glb`
- Animación: activada si hay acciones

Presupuesto orientativo para que vaya fluido también en navegador: menos de ~150.000 triángulos por
diorama y texturas de 1024 px como mucho (2048 solo si es imprescindible).

## 6. Dónde va cada cosa

```
assets/modelos/nivel_01/nivel_01.glb     ← un .glb por nivel
assets/modelos/menu/menu.glb             ← el cerdito del título: si existe, el juego usa ESTE (ver abajo)
assets/texturas/                         ← solo si una textura va suelta
assets/texturas/particulas/<nombre>.png  ← (opcional) polvo, chispa, hoja, viruta: blanco sobre
                                            transparente, 64-128 px; si no están, se dibujan solas
assets/ui/                               ← iconos, botones, logo, fondo de menú (PNG)
assets/fuentes/                          ← tipografías (.ttf / .otf) con licencia libre
assets/audio/sfx/<nombre>.ogg            ← snap, reject, open, close, pickup, hint, complete, zoom_in, zoom_out, click
assets/audio/musica/musica.ogg           ← música en bucle
assets/audio/voz/<clave>.ogg             ← voz del narrador; <clave> = la de data/narracion_es.json
```

**El cerdito del título.** El juego arranca con un diorama que hay que montar para que salga el
menú: **la hucha de cerdito** de la protagonista sobre un cojín, con sus **pegatinas** (estructura
en §2). Ahora es provisional: `levels/provisional/menu_provisional.glb`.
- **Para hacer el vuestro:** en Blender, *File → Import → glTF 2.0* de ese fichero. Trae los nombres,
  los tamaños y las posiciones: sustituid las mallas por las vuestras manteniendo los nombres de los
  objetos, y exportad como `assets/modelos/menu/menu.glb`. El juego lo usará solo, sin tocar nada más.
- Las piezas repetidas (patas, orejas, ojos) se llaman igual (Blender pondrá `P_pata.001`): valen
  en cualquier hueco de su tipo. Podéis cambiar formas y posiciones, y añadir o quitar pegatinas:
  el puzle se monta con lo que haya.
- Sin `OD_`, `H_` ni `Z_` (es el tutorial).

Los `.blend` de trabajo **no van al repositorio** (pesan mucho y no se pueden fusionar): guardadlos
en la carpeta compartida del equipo. Al repo va solo lo exportado.

## 7. Qué NO tocar

- Nada fuera de `assets/` (scripts `.gd`, escenas `.tscn`, `project.godot`, `data/`). Si queréis
  cambiar algo de ahí, pedídselo a Claude: así nunca hay dos personas editando el mismo fichero.
- No abráis en Godot la escena de un `.glb` para "arreglarla": lo que se edite ahí se pierde al
  reimportar. Se arregla en Blender y se vuelve a exportar con el mismo nombre.

## 8. Comprobar vuestro arte sin esperar

Si tenéis Godot instalado: abrid el proyecto, y Claude os habrá dejado el nivel en
`data/levels.json`. `F5` lo juega. Si un hueco no aparece, casi siempre es el nombre.
