class_name DibujoIcono
extends Control
## Un dibujo en pequeño (el álbum de la pausa y los créditos): el folio con la imagen del dibujo
## encontrado (texture) o, si no tiene, del color del dibujo; con su trozo de celo. faded = uno que
## falta (solo el contorno).

var color := Color(0.35, 0.72, 0.32):
	set(v):
		color = v
		queue_redraw()
var faded := false:
	set(v):
		faded = v
		queue_redraw()
var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()


func _init(size_px := Vector2(46, 58)) -> void:
	custom_minimum_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-2.0)
	if faded:
		draw_rect(r, Color(0.6, 0.55, 0.5, 0.8), false, 1.5)      # se ve igual sobre papel que sobre madera oscura
		return
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0.1, 0.06, 0.03, 0.35))      # sombra
	if texture != null:                          # el folio blanco y el dibujo encajado sin deformar
		draw_rect(r, Color(0.97, 0.96, 0.92))
		var room := r.grow(-maxf(2.0, r.size.x * 0.06))
		var ts := texture.get_size()
		var k := minf(room.size.x / ts.x, room.size.y / ts.y)
		var fit := Rect2(Vector2.ZERO, ts * k)
		fit.position = room.position + (room.size - fit.size) * 0.5
		draw_texture_rect(texture, fit, false)
		draw_rect(r, color.darkened(0.2), false, 1.5)
	else:
		draw_rect(r, color)
		draw_rect(r, color.darkened(0.25), false, 1.5)
	draw_rect(Rect2(r.position.x + r.size.x * 0.32, r.position.y - 2.0, r.size.x * 0.36, r.size.y * 0.12), Color(0.95, 0.93, 0.85, 0.9))
