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
signal piece_rejected(piece_id: StringName, reason: String)
signal piece_collected(piece_id: StringName, node: Node3D)   # una pieza escondida (H_) encontrada

signal world_clicked(screen_pos: Vector2)     # clic sin arrastre sobre el 3D
signal hint_shown(target: Node3D)
