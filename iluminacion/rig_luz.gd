class_name RigLuz
extends Node3D
## Raíz de cada escena de luz (iluminacion/*.tscn). Hace que la luz sea "en tiempo real":
##  - Gira con la cámara (seguir_camara): al girar el diorama, las sombras se mueven sobre él,
##    como una maqueta en un plato giratorio bajo un flexo. El lado que miras siempre está bien
##    iluminado y el contraluz siempre lo recorta contra el fondo oscuro.
##  - Despierta con el diorama: la luz principal va de color_inicio/energia_inicio (escena sin
##    montar: fría y tenue) a color_final/energia_final (completa: cálida y plena) según las
##    piezas puestas.
##  - Sombras nítidas: el mapa de sombras del sol cubre solo lo que se ve (distancia de la cámara
##    + tamaño del diorama), así su resolución no se gasta en metros vacíos. Al acercarte, más nítidas.
## Todo se ajusta en el Inspector seleccionando el nodo raíz (docs/ILUMINACION.md).

@export_range(0.0, 1.0) var seguir_camara := 1.0       ## 1 = gira entera con la cámara; 0 = fija
@export var luz_principal: NodePath = ^"Sol"
@export var color_inicio := Color(0.9, 0.92, 1.0)       ## con el diorama sin montar
@export var color_final := Color(1.0, 0.86, 0.68)       ## con el diorama completo
@export_range(0.0, 3.0) var energia_inicio := 0.5
@export_range(0.0, 3.0) var energia_final := 0.8
@export_range(0.1, 10.0) var segundos_cambio := 1.5     ## lo que tarda en ponerse al día al colocar
@export var ajustar_sombra := true                      ## alcance de la sombra = lo que se ve (más nítida)
@export_range(1.0, 3.0) var margen_sombra := 1.4        ## cuántos radios del diorama cubre más allá del centro

var progreso := 0.0                                     ## 0..1: lo que se ve ahora

var _sol: Light3D
var _diorama: Node
var _radius := 3.0                                      ## radio del diorama actual (m)
var _center := Vector3.ZERO


func _ready() -> void:
	_sol = get_node_or_null(luz_principal) as Light3D
	if _sol == null:
		push_warning("RigLuz '%s': no encuentro la luz principal '%s'" % [scene_file_path, luz_principal])
	_apply()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		rotation.y = cam.global_rotation.y * seguir_camara
	var d := GameState.diorama
	var goal := 0.0
	if is_instance_valid(d):
		goal = d.progress()
		if d != _diorama:                    # nivel nuevo: sin transición desde el anterior
			_diorama = d
			progreso = goal
			var box := Visuals.global_aabb(d)
			_radius = box.size.length() * 0.5
			_center = box.get_center()
		if ajustar_sombra and cam != null and _sol is DirectionalLight3D:
			var reach := cam.global_position.distance_to(_center) + _radius * margen_sombra
			(_sol as DirectionalLight3D).directional_shadow_max_distance = clampf(reach, 4.0, 40.0)
	progreso = move_toward(progreso, goal, delta / segundos_cambio)
	_apply()


func _apply() -> void:
	if _sol == null:
		return
	_sol.light_color = color_inicio.lerp(color_final, progreso)
	_sol.light_energy = lerpf(energia_inicio, energia_final, progreso)
