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
| 1 · El desván | Las paredes, la cumbrera, el tejado, las vigas y la ventana. Al final, **la hucha** (clave) | Abierta desde el principio | La hucha habla; se abre la infancia |
| 2 · Infancia | Dressing (alfombra, cama, cómoda, caballito, pelota, tren, estante de cuentos, cubos) y la historia: **caja de música → dibujo → nutria** (clave) | Rótulo «I · Infancia», se enciende su bombilla, aparecen sus muebles | Se pintan sus muebles; luces cálidas |
| 3 · Adolescencia | Dressing (alfombra, escritorio, silla, lámpara, altavoz, libros, pósters, corcho, puf, guitarra, fotos) y la historia: **MP3 → cámara → inscripción a Bellas Artes** (clave) | Rótulo «II · Adolescencia», bombilla, muebles | Ídem |
| 4 · Adultez | Dressing (alfombra, cajas de la tienda, taza, reloj, planta, perchero, abrigo, lienzo, pinceles) y la historia: **llaves → caballete → espejo** (clave) | Rótulo «III · Adultez», bombilla, muebles | Ídem |
| 5 · Epílogo | **La moneda**, en la hucha | Rótulo «Epílogo»; primero se dicen sus frases, luego aparece la moneda | Fundido a negro y créditos |

Reglas (las hace el código, no hay que pensarlas al montar el arte):
- **Todo se ve desde el principio en modo fantasma**: las siluetas de todas las piezas y los
  muebles de las zonas cerradas, cada acto de su color (infancia rosa, adolescencia azul, adultez
  verde) y con un letrero flotante con su nombre. Lo que ya se puede poner se ve más claro.
- **La bandeja enseña todas las piezas**, agrupadas por acto. Las que aún no van llevan candado y
  dicen por qué al pasar el ratón o tocarlas ("Es de «II · Adolescencia». Se abre al terminar
  «I · Infancia».", "Antes tiene que estar la cómoda.", "Va la última de «I · Infancia»...").
  Así el jugador sabe siempre hacia dónde va: el juego orienta sin prisas.
- Las piezas de la historia se pueden poner **de una en una** (cada frase continúa la anterior); el
  dressing de la zona, en cualquier orden.
- **La clave va la última** de su sección y la cierra.
- **Las frases nunca se pisan**: si se coloca otro objeto mientras uno habla, su frase espera.

## Momentos (las secuencias)

Cada objeto con frase tiene su **momento** al colocarlo: la cámara se le acerca despacio, entran
dos bandas negras de cine y un foco que oscurece alrededor, la bandeja y los botones se apartan,
el objeto hace **su gesto** y suena su frase. Un clic pasa a la siguiente frase; al callarse, todo
vuelve a como estaba. Los gestos (personalidad de cada objeto, `core/momentos.gd`):

| Objeto | Gesto |
|---|---|
| Hucha, llaves | Tintinea (se sacude a golpecitos) |
| Caja de música | La bailarina gira |
| Dibujo, inscripción | El papel aletea |
| Nutria | Se achucha (se aplasta y se estira) |
| MP3 | Late al ritmo |
| Cámara | Dispara: retrocede un poco (y el flash) |
| Caballete | Se balancea |
| El resto | Flota un poco |

Dos momentos especiales:
- **El espejo**: la cámara se pone **delante**, a su altura; **todo lo demás se va a negro**; en la
  luna aparece un vaho y, con la primera frase, **la silueta de ella**. Las tres frases salen de una
  en una, y con la última ("¿Y yo? ¿Dónde estoy yo?") la silueta se desvanece: el espejo se queda
  vacío.
- **El epílogo**: **primer plano de la hucha** mientras se dicen sus frases; a la vez aparece **la
  moneda flotando** a su lado, brillando. Cuando acaban las frases, un clic en la moneda la hace
  volar hasta la ranura y entrar; suena "Para unas pinturas de verdad." y **fundido a negro**.

## El título: la hucha de cerdito

El puzle que desbloquea el menú es **la hucha de ella**, sobre un cojín (la misma que luego cierra
la historia): 21 piezas. Primero el cuerpo; luego patas, hocico, orejas, cola, ranura, ojos,
coloretes y lazo; y sobre todo **pegatinas**: una estrella que brilla en la oscuridad, corazón,
flor, luna, rayo, arcoíris y la del nombre del juego, en el cartel de delante.

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
| (al empezar) | «El desván, a oscuras. Antes de ordenarlo hay que ponerlo en pie: primero las paredes y el tejado.» |
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
| Epílogo | «Nadie me enseñó a decir que no.» (silencio) «No.» «…Qué fácil suena cuando lo dices en voz alta.» |
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
5. Rótulos de capítulo (I · Infancia, II · Adolescencia, III · Adultez, Epílogo) para que se note
   que se va por secciones.
6. **La moneda no se arrastra desde la bandeja**: aparece flotando junto a la hucha y se toca
   (segunda nota: "close up de ese asset y que se vea la secuencia de diálogos y la moneda").
7. La frase del espejo se parte en tres, para que el momento respire.

Pendiente de decidir (no bloquea): el oficio familiar sigue siendo «la tienda»; la música de la
caja (sonido `caja_musica` y que se apague al cerrar la infancia) está por hacer cuando haya audio.
