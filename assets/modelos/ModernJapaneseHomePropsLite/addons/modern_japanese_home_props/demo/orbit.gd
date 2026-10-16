# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the creator of Modern Japanese Home Props
extends Node3D

@onready var camera: Camera3D = $Camera3D
var dragging := false
var yaw := 0.55
var pitch := 0.45
var distance := 4.4
var reset_distance := 4.4
var focus := Vector3(0, 0.55, 0)

func _ready() -> void:
    focus = get_meta("camera_focus", Vector3(0, 0.65, 0))
    distance = get_meta("camera_distance", 3.7)
    reset_distance = distance
    if name == "Showcase":
        yaw = 0.0
        pitch = 0.85
    update_camera()

func update_camera() -> void:
    camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
    camera.look_at(focus)
    camera.size = distance * 0.82

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = maxf(0.8, distance * 0.9)
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = minf(22.0, distance * 1.1)
    elif event is InputEventMouseMotion and dragging:
        yaw -= event.relative.x * 0.008
        pitch = clampf(pitch + event.relative.y * 0.006, 0.08, 1.3)
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_R:
            yaw = 0.0 if name == "Showcase" else 0.55
            pitch = 0.85 if name == "Showcase" else 0.45
            distance = reset_distance
        elif event.keycode == KEY_TAB:
            var scenes: Array[String] = ["DemoRoom"]
            if ResourceLoader.exists("res://assets/modern-japanese-props/demo/MessyRoom.tscn"):
                scenes.append("MessyRoom")
            scenes.append("Showcase")
            var current_index := scenes.find(str(name))
            get_tree().change_scene_to_file("res://assets/modern-japanese-props/demo/" + scenes[(current_index + 1) % scenes.size()] + ".tscn")
    update_camera()
