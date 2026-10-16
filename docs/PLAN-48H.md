# Plan de 48 horas

El kit ya trae el bucle completo funcionando con figuras simples. Las 48 h son para **arte,
contenido y sensación**, no para inventar sistemas.

| Hora | Claude | Artistas | Hito (se comprueba) |
|---|---|---|---|
| 0-1 | Repo listo, `CHECK OK`, captura del nivel de muestra al chat | Leer `ARTE-PIPELINE.md`, clonar con GitHub Desktop | Todo el equipo ve el juego de muestra |
| 1-2 | Decidir con el equipo tema, nº de dioramas (3 es realista), paleta | Boceto del diorama 1 y lista de piezas | Lista de piezas del nivel 1 con nombres `P_…` |
| 2-8 | Pulir tacto: sonidos provisionales, imán, rebote, cámara | Modelar diorama 1 (blocking primero) | **A las 6 h**: blocking del nivel 1 jugable en `main` |
| 8-14 | Integrar nivel 1, ajustar siluetas/color con capturas, menú mínimo | Pintar nivel 1, empezar nivel 2 | Nivel 1 final jugable de principio a fin |
| 14-22 | Narración, transición entre niveles, exportación Web de prueba | Nivel 2 + sonidos + voz | **Build Web subida a itch.io en borrador** (pronto, no al final) |
| 22-30 | Integrar nivel 2, sub-diorama (`Z_`), escondidos | Nivel 3 | 2 niveles completos |
| 30-38 | Integrar nivel 3, pantalla final, créditos, rendimiento en navegador | Pulido, UI, portada de itch | **Congelación de funcionalidades a las 38 h** |
| 38-44 | Solo arreglos. Partidas de prueba de gente que no ha visto el juego | Capturas y GIF para la página | Lista de bugs vacía o aceptada |
| 44-47 | Build final Web + Windows, `git tag entrega-jam` | Texto y capturas de itch | Subido y probado DESDE itch (no desde local) |
| 47-48 | Colchón | Colchón | Entregado |

## Reglas que salvan jams

- **Algo jugable en `main` cada 1-2 horas.** Si se rompe, se arregla antes que nada.
- **Blocking antes que detalle**: un nivel con cajas grises colocado en el juego a las 6 h vale más
  que un modelo precioso a las 30 h.
- **Exportar a Web pronto** (hora ~14): sale lo que en escritorio no (rendimiento, audio que no
  arranca sin un clic, fuentes). En itch: *Kind of project* = HTML, subir el `.zip` del export,
  marcar *This file will be played in the browser*, tamaño 1280×720.
- **Congelar a las 38 h.** Después solo arreglos.
- **Dormir.** Turnos de sueño en el equipo; Claude no duerme, pero quien prueba sí.

## Exportar (Claude)

⚠️ **Esta sección NO está probada en el kit** (no se descargaron las plantillas de exportación).
Hacer una exportación Web de prueba en la primera hora de la jam, no en la última.

1. Editor → Editor → *Manage Export Templates* → descargar las de 4.7.2 (una vez).
2. Proyecto → Exportar → añadir **Web** y **Windows Desktop** (se guarda en `export_presets.cfg`, que
   va al repo).
3. Web con *Thread Support* desactivado (no exige cabeceras especiales en itch).
4. Desde consola: `"$GODOT" --headless --path . --export-release "Web" build/web/index.html`
   (el nombre es el del preset).
5. Probar la build exportada, no el editor.
