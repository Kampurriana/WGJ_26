# Lecciones de método (heredadas, para el Claude que programa el juego)

Destiladas de meses de trabajo real de otro Claude en esta misma máquina (webs, backend, scripts).
Cada una costó al menos una vez más de diez minutos. Están escritas en genérico y, donde aplica,
traducidas a Godot. **Regla de mantenimiento:** cuando un error de este proyecto cueste más de diez
minutos y pueda repetirse, se apunta en `CLAUDE.md` (sección Trampas) en el momento, no "luego".

## A. Verificar: el error caro es el que no da error

1. **Evidencia antes que afirmación.** Nada está "hecho" sin haberlo ejecutado. Nada "existe" sin
   haberlo mirado.
2. **El código de salida no es el veredicto.** Godot sale con 0 aunque un script reviente. El
   veredicto es una marca positiva en el log (`SMOKE OK`) y cero errores. Un control que solo mira
   `$?` aprueba lo que no ha corrido.
3. **El silencio de un instrumento no es "todo bien".** Un sonido que falta, una frase que falta, un
   test que no llegó a ejecutarse: tienen que AVISAR (`push_warning`). "No he podido medir" y "he
   medido y está bien" no pueden verse igual.
4. **Un control hay que verlo en ROJO antes de fiarse de su verde.** Meter el defecto a propósito
   (en una copia) y exigir que falle, y leer QUÉ línea falló: un rojo por el motivo equivocado es un
   verde disfrazado.
5. **Mirar, no solo consultar.** Un test puede pasar con la pantalla rota (un elemento "oculto" que
   se ve, una silueta que no se distingue). Para todo cambio visible: captura y mírala. Y comprueba
   que la captura tiene el tamaño pedido: una imagen recortada se inventa defectos.
6. **Si un barrido dice que muchas cosas se rompieron a la vez, el roto es el barrido.** Un juego
   que funcionaba no se rompe en bloque; un instrumento nuevo sí falla en bloque.
7. **Un log viejo se lee igual que uno nuevo.** Borrar el log antes de lanzar y mirar su fecha antes
   de creérselo.
8. **Una sustitución tiene que afirmar cuántas HIZO.** Al editar con scripts: contar antes y
   después; si no cuadra, abortar sin escribir. "1 de 1" no prueba que cayera en el sitio correcto:
   mirar el resultado.
9. **Un arreglo que no puedo ver actuar no se queda.** Si el test pasa también sin el arreglo, el
   test no lo vigila.
10. **Si un arreglo falla dos o tres veces, parar y rediagnosticar** con trazas, no iterar a ciegas.
    En este mismo kit: el arrastre "fallaba" y la causa era que el panel aún no estaba maquetado.
11. **Un informe de otro agente (o mío de ayer) es una afirmación, no una prueba.** Verificar lo que
    sostiene la conclusión antes de construir encima. Y apuntar quién midió cada cosa.
12. **Una causa apuntada sin medir envejece como un hecho.** Si es una sospecha, se escribe como
    sospecha.

## B. Shell, ficheros y Windows

13. **El texto que viaja por la línea de comandos lo lee la shell antes que el programa.** Acentos
    graves (backticks) en `git commit -m "…"` se EJECUTAN. Mensajes de commit por fichero:
    `git commit -F msg.txt`.
14. **Los ficheros se escriben con la herramienta de ficheros, no con heredocs ni `echo`.** El
    transporte de comandos se come barras invertidas (`\n`, `\b`, `\\`) y los heredocs largos fallan
    enteros. Después de escribir, `file x.gd` tiene que decir *UTF-8* o *ASCII*.
15. **Perl con `\x{…}` escribe Latin-1**, no UTF-8 (pasó en este kit: `file` lo cazó). Para cambiar
    texto con acentos, la herramienta de edición.
16. **PowerShell 5.1 no tiene `&&` ni `||`.** Git Bash sí. No mezclar sintaxis.
17. **Un `cd` suelto persiste** entre llamadas y desplaza todas las rutas relativas: usar
    `( cd X && … )` o rutas absolutas.
18. **`$?` después de una tubería es del último comando**, no del que importa.
19. **Nunca matar procesos por patrón** (`pkill -f`, `Stop-Process` por línea de comandos): se lleva
    por delante tu propia shell. Por PID, y excluyendo el propio.
20. **El scratchpad (carpeta temporal) no es un almacén:** algo lo barrió una vez entero. Lo que
    vale, commiteado y empujado.

## C. Git en equipo

21. **Nunca `git add -A` / `git add .`**: una vez se llevó seis ficheros de otra sesión dentro de un
    commit que no los mencionaba. Por nombre.
22. **Una rama por tarea, corta.** Y si hay dos sesiones de Claude a la vez, cada una en su propio
    directorio (`git worktree`), no solo en su rama: compartir directorio es compartir árbol.
23. **Antes de borrar o sobrescribir, mirar el objetivo.** Dos cosas con el mismo nombre no son la
    misma cosa: identificar por ruta completa.
24. **Un fichero que solo existe en un disco no existe.** Remoto desde el minuto uno.

## D. Diseño de sistemas (aplicado al juego)

25. **Una sola fuente de verdad.** Las piezas del nivel salen del modelo (nombres), no de una lista
    escrita aparte que envejece. Si un dato está escrito en dos sitios, ya divergieron.
26. **Para reconocer "lo mío", enumera lo ajeno.** Las listas de lo propio siempre tienen una forma
    más; lo de fuera suele ser una sola cosa medible.
27. **Una salvaguarda aplicada a un sitio de N.** Cuando añadas una protección, cuenta cuántos sitios
    debería cubrir y cuántos cubre.
28. **Al añadir una clase nueva a un vocabulario** (un prefijo nuevo, un tipo de interactivo),
    buscar todos los `match`/`if` que conocen la lista vieja.
29. **Cero es una medida, no una ausencia.** "No hay piezas" y "no he podido leer las piezas" deben
    verse distintos.
30. **Lo barato va primero.** El check de 30 s antes que la partida de 10 min.

## E. Cómo trabajar con el equipo

31. **Autonomía por defecto.** Si está claro y dentro del encargo, se hace y se cuenta en pasado
    ("arreglado X, medido Y"), no "¿quieres que…?". Solo llegan al equipo: dudas reales, decisiones
    de diseño, y lo que solo pueden hacer ellas (arte, voz, cuentas).
32. **Lo que se pide a una persona cabe en un móvil:** un gesto por línea, el valor a copiar en un
    bloque de código, sin contexto que ya tienen.
33. **Medir nunca se pregunta.** Leer, probar, capturar no cambia nada: se hace.
34. **Lo irreversible o lo que sale fuera** (publicar en itch.io, invitar gente, borrar ramas
    ajenas, forzar un push) se confirma antes, aunque haya autonomía.
