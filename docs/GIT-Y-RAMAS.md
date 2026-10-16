# Git y ramas para la jam

Objetivo: que nadie pise el trabajo de nadie y que `main` **siempre** arranque. Cada área del
equipo tiene **su rama fija**; Claude prueba lo que llega a cada una y lo junta en `main`.

## Las ramas

| Rama | Para qué | Quién sube ahí |
|---|---|---|
| `main` | Lo que funciona: siempre arranca y pasa el check. Es lo que se juega, se exporta y se entrega | **Solo Claude**, juntando las otras tres |
| `arte` | Modelos, texturas, sonidos, música, voz, iconos y fuentes (todo dentro de `assets/`) | Artistas |
| `iluminacion` | Luz y ambiente de los dioramas (todo dentro de `iluminacion/`) | Quien lleve la luz |
| `programacion` | Código, escenas, datos (`data/`) y documentación | Claude |

## Las reglas

1. **Cada fichero tiene un dueño.** Artistas: `assets/`. Quien lleva la luz: `iluminacion/`.
   Claude: todo lo demás. Si alguien necesita un cambio en algo que no es suyo, lo pide; no lo edita.
2. **Cada uno trabaja en la rama de su área, nunca en `main`.** Claude junta cada rama en `main`
   después de pasar `bash tools/check.sh` y mirar una captura, cada 1-2 horas como mucho.
3. **Después de cada junta, Claude pone al día las tres ramas con `main`**, para que cada área
   tenga lo último de las demás. Por eso, **antes de empezar a trabajar: Pull**.

La luz está en escenas de `iluminacion/` que se ajustan en el editor de Godot, sin código: los
pasos, en `ILUMINACION.md`.

Para la entrega se etiqueta: `git tag entrega-jam` sobre el commit exacto de `main` que se sube a
itch.io.

## Para las artistas, con GitHub Desktop (sin consola)

Primera vez (5 minutos):
1. Instalad **GitHub Desktop** (desktop.github.com) e iniciad sesión con vuestra cuenta de GitHub.
2. Aceptad la invitación al repositorio (llega por correo).
3. `File → Clone repository` → elegid el repo → carpeta local.
4. Arriba, **Current branch** → pestaña de ramas → elegid **`arte`** (si no sale en la lista,
   antes pulsad **Fetch origin**). A partir de ahí trabajáis siempre en `arte`.

Cada vez que vais a subir arte:
1. Comprobad que arriba pone **Current branch: `arte`**.
2. **Fetch origin** → **Pull origin** (si aparece). Así tenéis lo último de todos.
3. Copiad vuestros ficheros exportados a su carpeta de `assets/` (ver `ARTE-PIPELINE.md`).
4. En GitHub Desktop aparecen los cambios a la izquierda. **Revisad que solo hay ficheros de
   `assets/`.** Si sale cualquier otra cosa, desmarcadla y avisad.
5. Escribid un resumen corto ("Nivel 1: cocina con 14 piezas") → **Commit to arte**.
6. **Push origin**.
7. Avisad en el chat ("subido a arte: …"). Claude lo prueba, lo integra en el juego y lo junta en
   `main`.

Si GitHub Desktop habla de "conflict": no toquéis nada y avisad. Con la regla de dueños no
debería pasar nunca.

Si subís algo a `main` por error, no pasa nada grave: avisad y Claude lo recoloca.

## Para Claude (consola)

Trabajo diario, en mi rama:

```bash
git switch programacion && git pull --ff-only
# ... cambios ...
bash tools/check.sh                       # tiene que decir CHECK OK
git add <ficheros por nombre>             # nunca -A ni .
git commit -F build/msg.txt               # mensaje escrito con la herramienta de ficheros
git push
```

Juntar una rama en `main` (la mía, la de arte o la de luz):

```bash
git fetch origin
git diff --stat main...origin/arte        # arte: ¿solo assets/? si no, parar y preguntar
git switch main && git pull --ff-only
git merge origin/<rama>                   # sin conflictos si se respetan los dueños
bash tools/check.sh && bash tools/capture.sh build/junta.png 3 <nivel>   # en main, con todo junto
git push
```

Poner al día las tres ramas después de cada junta:

```bash
for b in arte iluminacion programacion; do
  git switch "$b" && git pull --ff-only && git merge main && git push
done
git switch main
```

Para integrar el arte en el juego (escena del nivel, `data/levels.json`): en `programacion`, después
de juntar `arte` en `main` y poner al día las ramas.

No se usan ramas `arte/<algo>`: Git no deja tener a la vez una rama `arte` y ramas que empiecen
por `arte/`. Pull Requests: no hacen falta (son opcionales para comentar algo concreto).

## Ficheros grandes

GitHub rechaza ficheros de más de 100 MB y avisa a partir de 50 MB. Un `.glb` de un diorama de jam
no debería acercarse. Si alguno pasa de 50 MB: reducir texturas antes que meter Git LFS (LFS añade
una instalación y una cuota más a cada artista, y en 48 h no compensa).

Ojo con el peso total, que es lo que se descarga la versión web: el pack de props japoneses ocupa
332 MB (ningún fichero pasa de 18 MB, pero en total es mucho). Antes de la build web, quitar del
juego lo que no se use o reducir sus texturas.

## `.gitignore` y fin de línea

- Fuera del repo: `.godot/` (caché de Godot), `build/` (logs, capturas, exportaciones), `*.blend*`.
- Dentro: los `.import` y `.uid` que genera Godot (si faltan, cada máquina los regenera distinto).
- `.gitattributes` fuerza fin de línea LF en texto y marca binarios los modelos, imágenes y audio,
  para que Windows no convierta nada y los ficheros no salgan "cambiados" sin haberlos tocado.
