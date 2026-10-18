# Entrega: Women Game Jam 2026 (itch.io)

Preparado el 18-oct-2026 a partir de `Manual_Women_Game_Jam_2026_ES.pdf`.
**Plazo: hasta el 20 de octubre de 2026 a las 20:55** (envíos abiertos desde el 16 a las 17:00).
Página de la jam: https://itch.io/jam/women-game-jam-2026

## Qué pide el manual y cómo queda

| Requisito del manual | Estado |
|---|---|
| Subir el juego a itch.io con instrucciones para jugarlo | Builds listas (Web y Windows); el texto de la página, más abajo, con las instrucciones |
| Todo el proyecto bajo **CC BY-SA 3.0** | `LICENSE` en el repo, línea en los créditos del juego y en la página |
| Idealmente, compartir el código y los recursos | El repo es público: https://github.com/Kampurriana/WGJ_26 |
| Solo recursos con derecho de uso | Arte, voces, música y efectos: del equipo. De terceros: Modern Japanese Home Props Lite (MIT), fuente Fredoka (OFL), Godot (MIT). Todo citado en los créditos y en `LICENSE` |
| Declarar el uso de IA en la página (qué herramienta, cómo y por qué) | Texto propuesto abajo: **revisarlo entre todas antes de publicar** |
| Todo el equipo recibe crédito | Créditos del juego + añadir a cada una como admin en itch (paso 5) |
| Portada mínimo 315×250 (recomendado 630×500) y capturas | `entrega/portada_630x500.png` y `entrega/capturas/` (6, subid 3–5) |
| Pricing: «No payments» · Comments activados · Visibilidad «Public» | Al rellenar la página (pasos de abajo) |

En la build exportada **ya no hay atajos de prueba** (F9) y **el progreso se guarda** (en el editor
sigue el modo prototipo: se nota solo, `OS.has_feature("template")`).

## Los ficheros a subir

- **Web (para jugar en el navegador):** `what-i-never-said-web.zip` (con `index.html` dentro, en la
  raíz). Probado en Chromium: carga, se juega y detecta el idioma del navegador.
- **Windows (descargable):** `what-i-never-said-windows.zip` (`WhatINeverSaid.exe`, todo en uno).

Se pueden regenerar desde el editor de Godot 4.7.2: *Proyecto > Exportar*, presets «Web» y
«Windows» (en `export_presets.cfg`; hacen falta las plantillas de exportación 4.7.2: *Editor >
Gestionar plantillas de exportación > Descargar*). O por consola:
`"$GODOT" --headless --path . --export-release "Web" build/export/web/index.html` y
`"$GODOT" --headless --path . --export-release "Windows" build/export/windows/WhatINeverSaid.exe`.
Fuera de la build: pruebas, herramientas, la preview, los niveles que ya no se juegan y los 10
modelos del pack que el desván no usa (la Web pesa ~56 MB de datos + 40 MB del motor).

## Paso a paso en itch.io (manual, págs. 7–13)

1. **Una sola** de vosotras registra el juego: itch.io → *Register* (marcad «I'm interested in
   distributing content on itch.io» y aceptad los términos).
2. En la página de la jam, **Join jam**.
3. *Dashboard → Create new project*:
   - **Title:** What I Never Said
   - **Short description:** el «tagline» de abajo.
   - **Classification:** Games · **Kind of project:** HTML · **Release status:** Prototype (o
     Released, como decidáis).
   - **Pricing:** No payments.
   - **Uploads:** `what-i-never-said-web.zip` → marcar «This file will be played in the browser».
     Después, `what-i-never-said-windows.zip` → marcar «Windows» (descarga).
   - **Embed options:** tamaño 1280 × 720, marcar «Fullscreen button».
   - **Details → Description:** el texto de abajo (con la declaración de IA).
   - **Genre:** Puzzle · **Tags:** los de abajo.
   - **Cover image:** `entrega/portada_630x500.png` · **Screenshots:** 3–5 de `entrega/capturas/`.
4. **Community:** Comments · **Visibility & access:** Public → **Save**.
5. *Edit → More → Admins*: añadir el usuario de itch de cada integrante, una por una («Add admin»).
6. En la página de la jam: **Submit your project** → *Existing game* → What I Never Said → **Submit**.

## Textos para la página

### Tagline

ES: Un puzle de dioramas sobre todo lo que nunca dijiste.
EN: A cozy diorama puzzle about everything you never said.

### Tags

`womengamejam2026`, `wgj2026`, `puzzle`, `diorama`, `cozy`, `narrative`, `3d`, `godot`, `short`

### Descripción (pegar en *Details*)

> **What I Never Said** es un puzle de dioramas en 3D. Vuelves al desván de tu infancia y, pieza a
> pieza, lo vas montando de nuevo: cada objeto que colocas despierta un recuerdo. La infancia, la
> adolescencia, la vida adulta... y una hucha vacía que guarda una pregunta: ¿cuándo dejaste de
> decidir por ti?
>
> **Cómo se juega**
> - Arrastra cada pieza de la bandeja de la derecha hasta su silueta blanca.
> - Toca los muebles que brillan para abrirlos: guardan piezas y dibujos escondidos.
> - Arrastra en vacío (o WASD / flechas) para girar; rueda (o Q / E) para acercarte.
> - H = pista · Esc = pausa (el álbum de dibujos, opciones y logros).
> - Mando: stick izquierdo = puntero, A = clic, stick derecho = girar, gatillos = zoom.
> - Español (con voces) e inglés (con subtítulos). Se cambia en el menú principal.
>
> **Equipo**
> - Eva Fernandez Valero: 3D Modelling & Textures
> - Inés Jackson Martín: 3D Modelling & Textures
> - Carmen Esteban Fernandez-Vicenti: Concept Art & 2D Art
> - Sandra: Concept Art & Texture Artist
> - Ana Climent Sapena: Programming & Design
> - Anaïs Soriano Gimeno: Sound Designer & Voice Actress (voces, música y efectos)
>
> **Uso de inteligencia artificial** (reglas de la WGJ)
> - *Qué herramientas:* Claude (Claude Code, de Anthropic).
> - *Cómo:* escribió y probó el código del juego en Godot (mecánicas, interfaz, cámara, efectos y
>   pruebas automáticas) a partir del diseño, el guion, el arte y el sonido del equipo. También
>   tradujo los textos al inglés y generó por código algunas formas 3D provisionales (la hucha
>   del título y parte de la estructura del desván) donde todavía no había modelo del equipo.
>   El arte 2D y 3D, las texturas, el logo, el guion, las voces, la música y los efectos de sonido
>   son del equipo, sin IA.
> - *Por qué:* somos un equipo de artistas; usamos la IA para la programación y así poder dedicar
>   la jam al arte, la historia y el sonido.
>
> **Diversificadores:** Multilingüe (español e inglés) · Cameo de nutria (el peluche, que en
> realidad es una nutria).
>
> Inspirado en *Woodo*, de Tiny Monks Tales. Hecho con Godot Engine.
> Recursos de terceros: Modern Japanese Home Props Lite (MIT), fuente Fredoka (SIL OFL).
> Licencia: CC BY-SA 3.0. Código y recursos: https://github.com/Kampurriana/WGJ_26
>
> ---
>
> **What I Never Said** is a 3D diorama puzzle. You go back to your childhood attic and rebuild it
> piece by piece: every object you place brings back a memory. Childhood, adolescence, adult life...
> and an empty piggy bank holding a question: when did you stop deciding for yourself?
>
> **How to play**
> - Drag each piece from the tray on the right to its white outline.
> - Tap the glowing furniture to open it: it hides pieces and drawings.
> - Drag on empty space (or WASD / arrows) to rotate; mouse wheel (or Q / E) to zoom.
> - H = hint · Esc = pause (drawings album, options and achievements).
> - Gamepad: left stick = pointer, A = click, right stick = rotate, triggers = zoom.
> - Spanish (voiced) and English (subtitles only). Switch it in the main menu.
>
> **Use of AI** (WGJ rules)
> - *Tools:* Claude (Claude Code, by Anthropic).
> - *How:* it wrote and tested the game's code in Godot (mechanics, UI, camera, effects and
>   automated tests) from the team's design, script, art and sound. It also translated the texts
>   into English and generated, in code, some placeholder 3D shapes (the title piggy bank and part
>   of the attic structure) where there was no team model yet. The 2D and 3D art, textures, logo,
>   script, voices, music and sound effects are made by the team, without AI.
> - *Why:* we are a team of artists; we used AI for the programming so we could spend the jam on
>   the art, the story and the sound.
>
> Inspired by *Woodo* by Tiny Monks Tales. Made with Godot Engine. Third-party assets: Modern
> Japanese Home Props Lite (MIT), Fredoka font (SIL OFL). License: CC BY-SA 3.0.

## Lo que tenéis que decidir o confirmar vosotras

- **La declaración de IA:** que refleje exactamente lo que hicisteis (si alguien usó IA en el arte,
  los textos o el audio, añadidlo; si no, dejadla así).
- **El apellido de Sandra** (créditos del juego, `LICENSE` y la página). El de Anaïs sale de sus
  propios ficheros de audio («Anais Soriano Gimeno»): confirmadlo.
- **Diversificadores:** si queréis declarar alguno más (por ejemplo «Instantánea» o «Salud mental»,
  si la historia sale de algo vuestro).
- **Release status** (Prototype o Released) y los **tags** finales.
