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
| (otro) | Decorado: se queda en la escena, empieza blanco y se colorea al completar piezas cerca | `Arbol`, `Pared` |

Detrás del nombre, opciones con **doble guion bajo**:

| Opción | Dónde | Qué hace |
|---|---|---|
| `__after-mesa` | en un `P_` | solo encaja cuando todas las `P_mesa` están puestas |
| `__reward-cuadro` | en un `Z_` | al completar el rincón, el jugador recibe la pieza `cuadro` (hace falta un `P_cuadro`) |
| `__x` `__nx` `__z` `__nz` `__y` `__ny` | en un `OD_` | eje por el que sale el cajón si no sale bien por defecto |
| `__n` | en un `OR_` | la puerta abre hacia el otro lado |

Reglas de los nombres:
- Ids en minúscula, sin espacios ni acentos, empezando por letra: `P_taza_roja` sí, `P_Taza Roja` no.
- **Piezas iguales = mismo nombre.** Blender pondrá `P_silla.001`, `P_silla.002`: está bien, el
  juego lo entiende como "tres sillas iguales".
- No terminéis un nombre en `-col`, `-colonly`, `-rigid`, `-noimp`, `-navmesh`, `-occ` o `-loop`:
  Godot los lee como órdenes de importación y cambia el objeto.
- Una pieza `P_` puede tener hijos (patas, tablero…): todo lo que cuelga de ella es la pieza.
- Lo que va **dentro de un cajón** (un `H_`) tiene que ser **hijo del cajón**, para que se mueva con él.
- Las piezas de un `Z_` son hijas del `Z_`.
- **Cajones:** con el diorama visto en vista frontal de Blender (tecla 1 del teclado numérico), el
  frente del cajón mira hacia vosotras. Si al probar sale hacia otro lado, añadid `__x`, `__nx`…
  o decídselo a Claude.

## 3. Luces dentro del modelo (opcional)

- Las luces de Blender (punto y foco) viajan dentro del `.glb`: al exportar, marcad
  **Include → Punctual Lights**.
- Una luz **hija de una pieza `P_`** (la bombilla de una lámpara, la vela de un farol) está
  apagada mientras la pieza es silueta y **se enciende al colocarla**. Una luz del decorado está
  siempre encendida.
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
assets/modelos/menu/menu.glb             ← el cofre del título: si existe, el juego usa ESTE (ver abajo)
assets/texturas/                         ← solo si una textura va suelta
assets/texturas/particulas/<nombre>.png  ← (opcional) polvo, chispa, hoja, viruta: blanco sobre
                                            transparente, 64-128 px; si no están, se dibujan solas
assets/ui/                               ← iconos, botones, logo, fondo de menú (PNG)
assets/fuentes/                          ← tipografías (.ttf / .otf) con licencia libre
assets/audio/sfx/<nombre>.ogg            ← snap, reject, open, close, pickup, hint, complete, zoom_in, zoom_out, click
assets/audio/musica/musica.ogg           ← música en bucle
assets/audio/voz/<clave>.ogg             ← voz del narrador; <clave> = la de data/narracion_es.json
```

**El cofre del título.** El juego arranca con un diorama que hay que montar para que salga el
menú, como en Woodo: un cofre de madera; delante, **las letras del nombre del juego, una pieza por
letra**; encima, un paisaje pequeño (casita, dos árboles, dos faroles que se encienden, un banco).
Ahora es provisional: `levels/provisional/menu_provisional.glb`.
- **Para hacer el vuestro:** en Blender, *File → Import → glTF 2.0* de ese fichero. Trae los nombres,
  los tamaños y las posiciones: sustituid las mallas por las vuestras manteniendo los nombres de los
  objetos, y exportad como `assets/modelos/menu/menu.glb`. El juego lo usará solo, sin tocar nada más.
- Las letras se llaman `P_letra_w`, `P_letra_o`, `P_letra_d`... Las repetidas, igual (Blender pondrá
  `P_letra_o.001`): valen en cualquier hueco de esa letra. Podéis cambiar la disposición, añadir o
  quitar piezas del paisaje: el puzle se monta con lo que haya.
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
