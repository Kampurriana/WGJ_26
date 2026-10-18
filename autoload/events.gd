extends Node
## Bus de señales global. Los sistemas no se guardan referencias cruzadas:
## emiten aquí y escucha quien quiera. Añadir una señal = añadirla en este fichero.

signal level_started(diorama: Node)
signal level_completed(diorama: Node)
signal inventory_changed
signal focus_changed(anchor: Node)            # null = vista general del diorama

signal piece_drag_started(piece_id: StringName)
signal piece_drag_ended(piece_id: StringName, placed: bool)
signal piece_placed(piece_id: StringName, node: Node3D)
signal whole_placed(whole_id: StringName, node: Node3D)   # (token de-<id>) puesto el último trozo de algo: lo montado
signal piece_rejected(piece_id: StringName, reason: String)
signal piece_collected(piece_id: StringName, node: Node3D)   # una pieza escondida (H_) encontrada
signal collectible_found(item: Node, found: int, total: int)  # un dibujo escondido (C_): sale de su sitio hacia la cuerda
signal collectible_hung(item: Node)           # y ya está colgado en la cuerda (T_)

signal world_clicked(screen_pos: Vector2)     # clic sin arrastre sobre el 3D
signal hint_shown(target: Node3D)

signal section_opened(section: RefCounted)    # se abre una zona del diorama (Section)
signal section_revealed(section: RefCounted)  # y aparecen sus cosas (en un capítulo, cuando se va el rótulo)
signal section_completed(section: RefCounted)
signal attention_changed(target: Node, on: bool)   # un mueble u objeto llama la atención (Interactable)
signal tip_requested(key: String)             # consejo de juego (texto en narracion_<idioma>.json)
signal flash_requested                        # destello blanco (pieza con token flash)
signal achievement_unlocked(id: String)       # un logro conseguido (core/logros.gd)
signal act_continued                          # cambio de acto: el jugador sigue (Diorama.continue_act)
