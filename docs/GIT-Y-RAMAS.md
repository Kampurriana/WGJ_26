# Git y ramas para la jam

Objetivo: que nadie pise el trabajo de nadie y que `main` **siempre** arranque. Con un solo
programador (Claude) y artistas que solo tocan `assets/`, los conflictos desaparecen si se cumplen
tres reglas.

## Las tres reglas

1. **Cada fichero tiene un dueño.** Artistas: `assets/`. Claude: todo lo demás. Si alguien
   necesita un cambio en algo que no es suyo, lo pide; no lo edita.
2. **Nadie empuja a `main` directamente.** Todo entra por Pull Request y lo fusiona Claude después
   de pasar `bash tools/check.sh`.
3. **Ramas cortas.** Una rama = una cosa (un modelo, un nivel, un juego de sonidos). Se fusiona el
   mismo día. Una rama de 20 horas es un conflicto esperando.

## Nombres de rama

| Rama | Quién | Ejemplo |
|---|---|---|
| `main` | nadie directamente | siempre jugable |
| `arte/<nombre>-<cosa>` | cada artista | `arte/lucia-nivel01`, `arte/marta-sonidos` |
| `codigo/<tema>` | Claude | `codigo/pista-adaptativa` |
| `fix/<tema>` | Claude | `fix/cajon-no-abre` |

Para la entrega se etiqueta: `git tag entrega-jam` sobre el commit exacto que se sube a itch.io.

## Para las artistas, con GitHub Desktop (sin consola)

Primera vez (5 minutos):
1. Instalad **GitHub Desktop** (desktop.github.com) e iniciad sesión con vuestra cuenta de GitHub.
2. Aceptad la invitación al repositorio (llega por correo).
3. `File → Clone repository` → elegid el repo → carpeta local.

Cada vez que vais a subir arte:
1. Arriba, **Current branch → `main` → Fetch origin → Pull**. (Siempre empezar desde lo último.)
2. **Current branch → New branch**: `arte/<vuestro-nombre>-<cosa>`.
3. Copiad vuestros ficheros exportados a su carpeta de `assets/` (ver `ARTE-PIPELINE.md`).
4. En GitHub Desktop aparecen los cambios a la izquierda. **Revisad que solo hay ficheros de
   `assets/`.** Si sale cualquier otra cosa, desmarcadla y avisad.
5. Escribid un resumen corto ("Nivel 1: cocina con 14 piezas") → **Commit**.
6. **Publish branch** → **Create Pull Request** (se abre en el navegador) → **Create pull request**.
7. Avisad en el chat del equipo. Claude lo integra y lo fusiona.

Si GitHub Desktop habla de "conflict": no toquéis nada y avisad. Con la regla de dueños no
debería pasar nunca.

## Para Claude (consola)

```bash
git switch main && git pull --ff-only
git switch -c codigo/<tema>
# ... cambios ...
bash tools/check.sh                       # tiene que decir CHECK OK
git add <ficheros por nombre>             # nunca -A ni .
git commit -F build/msg.txt               # mensaje escrito con la herramienta de ficheros
git switch main && git merge --ff-only codigo/<tema> && git push
```

Integrar el PR de una artista:

```bash
gh pr list
gh pr checkout <n>
git diff --stat main...HEAD               # ¿solo assets/? si no, parar y preguntar
# crear o actualizar la escena del nivel / data/levels.json en una rama codigo/ aparte
bash tools/check.sh && bash tools/capture.sh build/pr<n>.png 3 <nivel>
gh pr merge <n> --merge                   # solo tras CHECK OK y mirar la captura
```

Proteger `main` en GitHub (una vez, lo hace quien sea admin del repo): Settings → Branches → Add
rule → `main` → *Require a pull request before merging*. Para la jam, sin revisiones obligatorias:
el filtro es el check de Claude. Ojo: en un repo **privado** de una cuenta **gratuita**, GitHub no
deja proteger ramas; entonces la regla 2 se cumple por acuerdo (o se hace público el repo).

## Ficheros grandes

GitHub rechaza ficheros de más de 100 MB y avisa a partir de 50 MB. Un `.glb` de un diorama de jam
no debería acercarse. Si alguno pasa de 50 MB: reducir texturas antes que meter Git LFS (LFS añade
una instalación y una cuota más a cada artista, y en 48 h no compensa).

## `.gitignore` y fin de línea

- Fuera del repo: `.godot/` (caché de Godot), `build/` (logs, capturas, exportaciones), `*.blend*`.
- Dentro: los `.import` y `.uid` que genera Godot (si faltan, cada máquina los regenera distinto).
- `.gitattributes` fuerza fin de línea LF en texto y marca binarios los modelos, imágenes y audio,
  para que Windows no convierta nada y los ficheros no salgan "cambiados" sin haberlos tocado.
