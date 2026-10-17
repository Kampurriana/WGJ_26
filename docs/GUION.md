# Guion del desván (tal como está montado en el juego)

Base: *Guion narrativo* de Manu (16-oct-2026). Aquí está lo que el juego hace de verdad, con los
cambios pedidos después. Las frases viven en `data/narracion_es.json` (clave `pieza_<id>`): para
cambiar una frase se cambia ahí, sin tocar código.

**Premisa.** La protagonista ordena el desván y, objeto a objeto, descubre que casi todas sus
decisiones las tomó por los demás porque nunca aprendió a decir que no. Sin narrador: cada objeto
suelta una frase corta en primera persona al colocarlo.

## Cómo se juega la historia

El diorama principal (`levels/level_01_desvan.tscn`) es **un desván con tres zonas integradas**:
infancia a la izquierda, adolescencia en el centro y adultez a la derecha. Comparten suelo, paredes
y tejado, pero **se montan por secciones, en orden**:

| Sección | Qué se monta | Cómo se abre | Al completarla |
|---|---|---|---|
| 1 · El desván | **El suelo, a tablones** (18, de tres largos parecidos: 2,0 / 1,8 / 1,6 m; un tablón vale en cualquier hueco de su largo, no en los otros, y al cogerlo no late ninguna silueta: hay que encontrarle el sitio), las paredes, la cumbrera, el tejado, las vigas y la ventana. Al final, **la hucha** (clave) | Abierta desde el principio | La hucha habla; se abre la infancia |
| 2 · Infancia | Dressing (alfombra, cama, cómoda, caballito, pelota, tren, estante de cuentos, cubos) y la historia: **caja de música → dibujo → nutria** (clave) | Rótulo «I · Infancia», se enciende su bombilla, aparecen sus muebles | Se pintan sus muebles; luces cálidas |
| 3 · Adolescencia | Dressing (alfombra, escritorio, silla, lámpara, altavoz, libros, pósters, corcho, puf, guitarra, fotos) y la historia: **MP3 → cámara → inscripción a Bellas Artes** (clave) | Rótulo «II · Adolescencia», bombilla, muebles | Ídem |
| 4 · Adultez | Dressing (alfombra, cajas de la tienda, taza, reloj, planta, perchero, abrigo, lienzo, pinceles) y la historia: **llaves → caballete → espejo** (clave) | Rótulo «III · Adultez», bombilla, muebles | Ídem |
| 5 · El final | **La moneda**, en la hucha | Sin rótulo: **transición** desde el espejo (se queda vacío, en silencio, y fundido lento a negro) y corte a la hucha; primero sus frases, luego la moneda | Fundido a negro (segunda transición) y **créditos**; después, el menú |

Reglas (las hace el código, no hay que pensarlas al montar el arte):
- **Un acto cerrado no se ve** (ni sus siluetas ni sus muebles; tercera nota: los colores por acto
  no gustaron). Al abrirse sale el rótulo de **nuevo capítulo** a toda pantalla ("CAPÍTULO II /
  Adolescencia", con una línea que crece, y se va despacio) y sus siluetas se materializan.
- En el acto abierto se ven **todas** sus siluetas, como la **versión blanca** de cada pieza (opaca,
  como en Woodo): blancas las que ya se pueden poner, grises las que esperan a otra.
- **La bandeja enseña todas las piezas**, agrupadas por acto. Las que aún no van llevan candado y
  dicen por qué al pasar el ratón o tocarlas ("Es de «II · Adolescencia». Se abre al terminar
  «I · Infancia».", "Antes tiene que estar la cómoda.", "Va la última de «I · Infancia»...").
  Así el jugador sabe siempre hacia dónde va: el juego orienta sin prisas.
- Las piezas de la historia se pueden poner **de una en una** (cada frase continúa la anterior); el
  dressing de la zona, en cualquier orden.
- **La clave va la última** de su sección y la cierra.
- **Las frases nunca se pisan**: si se coloca otro objeto mientras uno habla, su frase espera.

## El orden del juego (cuarta nota)

1. **Al arrancar:** el puzle del cerdito (la hucha) y sus frases.
2. **El menú**, con el cerdito montado detrás y **sin frases**: sale cuando el cerdito ha acabado de
   hablar (y al volver al menú, el cerdito ya está montado y no dice nada).
3. **Jugar:** el desván. Se monta la estructura (paredes, tejado, la hucha) y luego los tres actos,
   cada uno con todas sus frases: I · Infancia, II · Adolescencia, III · Adultez.
4. **El espejo** (la clave de la adultez) y sus tres frases.
5. — Transición — el espejo vacío se queda un momento en silencio y todo se funde a negro despacio.
6. **La hucha**, en primer plano, con la reflexión final y la moneda (ver «Momentos»).
7. — Transición — fundido a negro.
8. **Créditos** (con los dibujos encontrados); al acabar, o con un clic, el menú.

## Momentos (las secuencias)

Cada objeto con frase tiene su **momento** al colocarlo: la cámara avanza despacio hacia él desde
donde miraba el jugador (sin dar vueltas; un dibujo o un tablero de pared, de frente), **lo que se
cruce por delante se desvanece** mientras dura el plano, entran dos bandas negras de cine y un
foco que oscurece alrededor, el enfoque se va al objeto (lo demás, más borroso), la bandeja y los
botones se apartan y suena su frase. **El objeto se queda quieto** y la cámara deja de "respirar"
(cuarta nota: nada de gestos en los primeros planos). Un clic pasa a la siguiente frase; al
callarse, todo vuelve a como estaba. Los consejos y los avisos de logro esperan a que acabe.

Dos momentos especiales:
- **El espejo**: la cámara se pone **delante**, a su altura; **todo lo demás se va a negro**; en la
  luna aparece un vaho y, con la primera frase, **la silueta de ella**. Las tres frases salen de una
  en una, y con la última ("¿Y yo? ¿Dónde estoy yo?") la silueta se desvanece: el espejo se queda
  vacío.
  Al callarse no se vuelve al desván: **transición** (el espejo vacío unos segundos, en silencio, y
  fundido lento a negro).
- **La hucha (el final)**: desde el negro, **corte** a la **hucha sola** sobre su baúl (no se ve
  nada más), quieta, vista un poco desde arriba y de tres cuartos, en una escena **acogedora**: luz
  cálida de lámpara que parpadea un pelín, un contraluz naranja que le dibuja el borde, motas de polvo
  flotando en la luz y, detrás, un fondo cálido con **luces desenfocadas** (como una guirnalda).
  En orden (sexta nota: "más inmediato"): 1) **sus frases**, seguidas (un clic pasa a la siguiente);
  2) en cuanto se callan aparece **la moneda** a su lado, quieta y con un destello, y una **moneda
  fantasma** (blanca y translúcida) enseña en bucle el gesto de meterla en la ranura; 3) el jugador
  **coge la moneda** (la fantasma se va) **y la arrastra hasta la ranura** (cerca, la ranura la atrae;
  si la suelta lejos, vuelve a su sitio y la fantasma vuelve a enseñarlo); se endereza, entra con **un golpe de
  luz dorada, chispas y luces que suben**, el fondo se aviva, suena "Para unas pinturas de verdad." y
  **fundido a negro** hacia los créditos.

## El título: la hucha de cerdito

El puzle que desbloquea el menú es **la hucha de ella**, sobre un cojín (la misma que luego cierra
la historia): 21 piezas. Primero el cuerpo; luego patas, hocico, orejas, cola, ranura, ojos,
coloretes y lazo; y sobre todo **pegatinas**: una estrella, corazón,
flor, luna, rayo, arcoíris y la del nombre del juego, en el cartel de delante.

## Los dibujos escondidos (cuarta nota)

Por el desván hay **7 dibujos de cuando ella era pequeña**, escondidos. No hacen falta para acabar:
son coleccionables. De momento cada uno es **un folio de un color** (verde, naranja, morado, azul,
rosa, rojo, amarillo); las artistas pondrán el dibujo de verdad (`C_` en `docs/ARTE-PIPELINE.md`).

| Dibujo | Dónde | Cuándo está |
|---|---|---|
| Verde | Dentro del baúl de juguetes, apoyado en el fondo | Infancia (se ve al abrir el baúl) |
| Naranja | Asomando por debajo de la cama | En cuanto la cama está puesta |
| Rosa | Debajo de la cámara, entre las fotos | **Viene con la cámara**: al ponerla en la mesa aparece y, al acabar su momento, se encuentra solo (el primer logro) |
| Morado | Encima del armario, asomando por el borde | Adolescencia |
| Azul | En el cajón de la cajonera (con la inscripción) | Adolescencia (se ve al abrir el cajón) |
| Rojo | En el cajón de la mesita (con los pinceles) | Adultez |
| Amarillo | Encima de las cajas de la tienda | En cuanto las cajas están puestas |

Nadie dice nada de ellos (quinta nota: "que los encuentre el jugador"): ni frase ni consejo.
Al tocar uno, se levanta, **vuela en arco hasta su cuerda** (la de la infancia, **distinta de la de
las fotos de encima del escritorio**), se engancha en la siguiente pinza y se balancea hasta quedarse
quieto; baja **un aviso de logro** ("DIBUJO ENCONTRADO · 3 DE 7", su nombre y una fila de puntos) y
bajo el título queda el contador. Los que esperan echan un
**destello pequeño** de vez en cuando; los de dentro de un mueble cerrado no se pueden coger hasta
abrirlo. Con los 7: *«¡Todos mis dibujos! La cuerda está completa.»* Los créditos dicen cuántos se
encontraron.

## Objetos escondidos en muebles

Para que el jugador descubra que **los muebles se abren**, el mueble que guarda lo que toca
encontrar **brilla con un contorno dorado, se mueve un poco cada pocos segundos y echa motas
doradas**; la primera vez sale
el consejo *«Algo está guardado. Toca el mueble que brilla para abrirlo.»*. Al abrirlo, brilla lo de
dentro (*«¡Ahí está! Tócalo para llevártelo a la bandeja.»*). La pista también señala el mueble.

| Qué | Dónde está guardado | Cuándo aparece |
|---|---|---|
| Los cubos (infancia) | El baúl de juguetes (la tapa se levanta) | Al abrirse la infancia: es el tutorial |
| **La cámara con las fotos** (adolescencia) | El armario | Después del MP3 |
| **La inscripción a Bellas Artes** (adolescencia) | El cajón de la cajonera | Después de la cámara y de todo lo demás: cierra el acto |
| Los pinceles (adultez) | El cajón de la mesita | Después del caballete |

Un objeto escondido **no existe** hasta que le toca: abrir el armario antes de tiempo no enseña la
cámara (así no se adelanta la historia).

## Las frases

| Objeto | Frase |
|---|---|
| (al empezar) | «El desván, a oscuras. Antes de ordenarlo hay que ponerlo en pie: primero el suelo, las paredes y el tejado.» |
| Hucha | «Mi hucha. Ahorraba para unas pinturas de verdad… Está vacía. ¿En qué me lo gasté?» |
| Caja de música | «La caja de la abuela. Bailaba hasta que nació mamá, y lo dejó. A mamá le pasó lo mismo con el ballet. En casa decían que por la familia una aprende a ceder. Yo aprendí rápido.» |
| Dibujo | «Para mamá pintaba bailarinas. Le gustaban más que mis monstruos… así que dejé de pintar monstruos.» |
| Nutria (clave) | «Mi nutria. Mi hermano la quería y lloró toda la tarde. Mamá me miró y yo dije “vale”. Todos sonrieron. Esa sonrisa me gustó demasiado.» |
| MP3 | «A los quince ya decía “vale” a todo. Sus canciones, sus planes, su ropa. Así cabía en el grupo.» |
| Cámara | «La cámara fue mi forma de estar sin estar. Cumpleaños, viajes, amigos… cientos de fotos. En ninguna salgo yo.» |
| Inscripción (clave) | «La inscripción a Bellas Artes. La matrícula la iba a pagar con la hucha. Pero la tienda de papá necesitaba una furgoneta. Ahí acabó mi dinero. Y yo dije “vale”.» |
| Llaves | «Ahora soy yo quien abre la tienda cada mañana. Papá dice que algún día será mía. Nunca le he dicho que no la quiero.» |
| Caballete | «Lo compré con mi primer sueldo, para pintar los domingos. Pero los domingos también abre la tienda.» |
| Espejo (clave) | «Y aquí está la que siempre dijo “vale”.» / «La bailarina de la abuela, la nutria de mi hermano, la tienda de papá…» / «¿Y yo? ¿Dónde estoy yo?» (tres frases, para el momento del espejo) |
| La hucha (final) | (silencio) «Nadie me enseñó a decir que no.» (silencio) «No.» «…Qué fácil suena cuando lo dices en voz alta.» |
| Moneda | «Para unas pinturas de verdad.» → fundido a negro |

## Cambios respecto al documento original (y por qué)

1. **El peluche es una nutria**, no un conejo (también en la frase del espejo).
2. **La caja de música es de la abuela**, y su frase dice que a mamá le pasó lo mismo con el ballet.
   El dibujo pasa a decir «Para mamá» (antes «Para ella», que ahora sería ambiguo). El espejo dice
   «la bailarina de la abuela».
3. **Adolescencia: primero la cámara y luego la inscripción.** La inscripción pasa a cerrar el acto
   (es la clave) y la cámara queda en medio. La frase de la cámara ya no empieza por «Desde
   entonces» (antes venía después de la inscripción y ya no). El **flash** que el documento ponía
   en la transición sale ahora **al colocar la cámara**.
4. **Se empieza montando las paredes y el tejado**; la hucha cierra esa fase y abre la historia.
5. Rótulos de capítulo (I · Infancia, II · Adolescencia, III · Adultez) para que se note que se va
   por secciones. El final no lleva rótulo: lleva transición (cuarta nota).
6. **La moneda no sale en la bandeja**: aparece flotando junto a la hucha y se arrastra a mano hasta
   la ranura (segunda y tercera nota: "que se vea la moneda en ese momento"; "permíteme poner la
   moneda dentro del cerdito, que no sea darle click").
7. La frase del espejo se parte en tres, para que el momento respire.
9. **Quinta nota:** el suelo, a tablones-pieza (más difícil saber dónde va cada uno); la estrella
   del cerdito ya no brilla; sin consejo sobre los dibujos; lo que se recoge vuela a la bandeja.
8. **Cuarta nota:** primeros planos quietos (sin gestos); orden título → menú sin frases → actos →
   espejo → transición → hucha → transición → créditos; la escena de la hucha, mucho más acogedora;
   7 dibujos escondidos que se cuelgan en su cuerda (el primero, con la cámara). El menú ya no dice
   «Gracias por jugar»: eso va al final de los créditos.

Pendiente de decidir (no bloquea): el oficio familiar sigue siendo «la tienda»; la música de la
caja (sonido `caja_musica` y que se apague al cerrar la infancia) está por hacer cuando haya audio.
