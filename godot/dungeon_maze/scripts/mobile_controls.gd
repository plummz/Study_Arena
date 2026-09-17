class_name MobileControls
extends Control

const BUTTON_RADIUS := 42.0
const BUTTON_COLOR := Color(0.07, 0.06, 0.12, 0.66)
const BUTTON_ACTIVE := Color(0.93, 0.62, 0.22, 0.88)
const BUTTON_BORDER := Color(1.0, 0.86, 0.55, 0.86)

var finger_actions: Dictionary = {}
var controls: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	visible = OS.has_feature("web") or DisplayServer.is_touchscreen_available()
	resized.connect(_layout_controls)
	_layout_controls()

func _exit_tree() -> void:
	_release_all()

func _layout_controls() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var left := Vector2(120.0, viewport_size.y - 122.0)
	var right := Vector2(viewport_size.x - 125.0, viewport_size.y - 122.0)
	controls = [
		{"action": "move_forward", "label": "▲", "center": left + Vector2(0, -58)},
		{"action": "move_back", "label": "▼", "center": left + Vector2(0, 58)},
		{"action": "move_left", "label": "◀", "center": left + Vector2(-58, 0)},
		{"action": "move_right", "label": "▶", "center": left + Vector2(58, 0)},
		{"action": "camera_up", "label": "▲", "center": right + Vector2(0, -58)},
		{"action": "camera_down", "label": "▼", "center": right + Vector2(0, 58)},
		{"action": "camera_left", "label": "◀", "center": right + Vector2(-58, 0)},
		{"action": "camera_right", "label": "▶", "center": right + Vector2(58, 0)},
		{"action": "run", "label": "RUN", "center": Vector2(260, viewport_size.y - 72), "radius": 38.0},
		{"action": "jump", "label": "JUMP", "center": Vector2(viewport_size.x - 255, viewport_size.y - 72), "radius": 38.0},
		{"action": "map", "label": "MAP", "center": Vector2(viewport_size.x - 72, 62), "radius": 34.0},
		{"action": "pause", "label": "Ⅱ", "center": Vector2(viewport_size.x - 150, 62), "radius": 34.0},
	]
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var action := _action_at(event.position)
			if not action.is_empty():
				_set_finger_action(event.index, action)
				get_viewport().set_input_as_handled()
		else:
			_release_finger(event.index)
	elif event is InputEventScreenDrag and finger_actions.has(event.index):
		var action := _action_at(event.position)
		if action.is_empty():
			_release_finger(event.index)
		else:
			_set_finger_action(event.index, action)
		get_viewport().set_input_as_handled()

func _action_at(point: Vector2) -> String:
	for control: Dictionary in controls:
		var radius := float(control.get("radius", BUTTON_RADIUS))
		if point.distance_to(control.center) <= radius:
			return String(control.action)
	return ""

func _set_finger_action(finger: int, action: String) -> void:
	var previous := String(finger_actions.get(finger, ""))
	if previous == action:
		return
	if not previous.is_empty():
		Input.action_release(previous)
	finger_actions[finger] = action
	Input.action_press(action)
	queue_redraw()

func _release_finger(finger: int) -> void:
	if not finger_actions.has(finger):
		return
	Input.action_release(String(finger_actions[finger]))
	finger_actions.erase(finger)
	queue_redraw()

func _release_all() -> void:
	for action: Variant in finger_actions.values():
		Input.action_release(String(action))
	finger_actions.clear()

func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	for control: Dictionary in controls:
		var center: Vector2 = control.center
		var radius := float(control.get("radius", BUTTON_RADIUS))
		var pressed := Input.is_action_pressed(String(control.action))
		draw_circle(center, radius, BUTTON_ACTIVE if pressed else BUTTON_COLOR)
		draw_arc(center, radius, 0.0, TAU, 40, BUTTON_BORDER, 2.0, true)
		var label := String(control.label)
		var font_size := 17 if label.length() > 1 else 24
		draw_string(font, center + Vector2(-radius, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)
