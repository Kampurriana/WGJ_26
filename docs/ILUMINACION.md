# Iluminación: guía para quien lleva la luz

Toda la luz del juego está en la carpeta **`iluminacion/`**. Esa carpeta es tuya: nadie más la toca.
Trabajas en la rama **`iluminacion`** (ver `GIT-Y-RAMAS.md`). No hace falta saber programar.

| Fichero | Qué es |
|---|---|
| `luz_por_defecto.tscn` | La luz de todos los niveles que no tengan una propia |
| `menu.tscn` | La luz del menú de inicio (el diorama del letrero con el título) |
| `probar_luz.tscn` | Para probar: la luz por defecto + el diorama de muestra + la cámara del juego |

## Qué hay dentro de una escena de luz

- **`Ambiente`** (WorldEnvironment). En el Inspector, despliega su `Environment`:
  - *Background → Color* (Fondo → Color): el color de detrás del diorama.
  - *Ambient Light → Color / Energy* (Luz ambiental → Color / Energía): la luz que llega a todas
    partes; aclara las sombras.
  - *Tonemap → Exposure* (Mapeo de tonos → Exposición): el brillo general.
- **`Sol`** (DirectionalLight3D):
  - *Light → Color / Energy* (Luz → Color / Energía): color y fuerza del sol.
  - *Transform → Rotation* (Rotación): desde dónde viene la luz.
  - *Shadow → Opacity* (Sombra → Opacidad): 1 = sombras negras; menos = más suaves.
- Puedes **añadir más luces** (OmniLight3D, SpotLight3D) como hijas de `Iluminacion`.

## Cómo trabajar

1. **GitHub Desktop:** rama `iluminacion` → **Fetch origin** → **Pull origin**.
2. **Godot:** abre `iluminacion/probar_luz.tscn` (doble clic en el panel *FileSystem*). Ves el
   diorama con la luz. Para verlo con la cámara del juego: selecciona `CamaraDeJuego` y marca
   **Preview** arriba en la vista 3D.
3. **Para cambiar la luz**, no la toques dentro de `probar_luz`: pulsa el **icono de claqueta** que
   hay junto a `Iluminacion` en el árbol de escena. Se abre `luz_por_defecto.tscn` en su pestaña.
   Cambia valores ahí y guarda (**Ctrl+S**); vuelve a la pestaña de `probar_luz` y ya se ve.
4. **F5** para verlo en el juego de verdad, con la arcilla blanca, las siluetas y la interfaz.
5. **Pide a Claude que lo mida** ("mide la luz"): hace capturas y comprueba que nada sale quemado.
   Lo que importa: la arcilla blanca y las siluetas de los huecos tienen que distinguirse.
   Referencia medida: `Energía del sol × 0,77 + Energía ambiental` por encima de ~0,8 quema.
6. **GitHub Desktop:** revisa que solo hay ficheros de `iluminacion/` → resumen → **Commit to
   iluminacion** → **Push origin** → avisa en el chat.

## Luz propia para un nivel

Clic derecho en `luz_por_defecto.tscn` → *Duplicate* (Duplicar) → llámala como el nivel
(`nivel_01.tscn`). Ajústala y pídele a Claude que se la asigne al nivel: es la propiedad
`Iluminacion` del nivel, y los niveles los toca Claude.

## Cuidado

- El juego usa el renderer **Compatibility** (el único que funciona en el navegador): algunas
  opciones del *Environment* (SSAO, SSR, SDFGI, niebla volumétrica...) no hacen nada. Si un cambio
  no se nota con F5, seguramente es eso: pregunta.
- **No guardes escenas de otras carpetas** (`levels/`, `scenes/`...): son de Claude, y si el editor
  las tiene abiertas puede pisar sus cambios.
