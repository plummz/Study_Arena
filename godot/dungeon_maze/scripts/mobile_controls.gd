class_name MobileControls
extends Control
## Touch controls for the first-person dungeon: a floating left joystick for movement,
## drag anywhere on the right half to look, and RUN / JUMP / MAP / PAUSE buttons.

const STICK_RADIUS := 70.0
const BUTTON_RADIUS := 38.0
const BUTTON_COLOR := Color(0.13, 0.2, 0.16, 0.62)
const BUTTON_ACTIVE := Color(0.72, 0.84, 0.68, 0.9)
const BUTTON_BORDER := Color(0.72, 0.84, 0.68, 0.8)

var game: Node
var controls: Array[Dictionary] = []
var finger_actions: Dictionary = {}
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick_vector := Vector2.ZERO
var look_finger := -1
var look_last := Vector2.ZERO
var run_latched := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	resized.connect(_layout_controls)
	_layout_controls()

func _exit_tree() -> void:
	_release_all()

func _layout_controls() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	controls = [
		{"action": "jump", "label": "JUMP", "center": Vector2(s.x - 92, s.y - 96), "radius": 46.0},
		{"action": "run", "label": "RUN", "center": Vector2(s.x - 196, s.y - 70), "radius": BUTTON_RADIUS, "toggle": true},
		{"action": "map", "label": "MAP", "center": Vector2(s.x - 64, 150), "radius": 32.0},
		{"action": "pause", "label": "II", "center": Vector2(s.x - 140, 150), "radius": 32.0},
	]
	queue_redraw()

func _blocked() -> bool:
	return game != null and game.has_method("_ui_blocking") and game._ui_blocking()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _blocked():
				return
			var action := _action_at(event.position)
			if not action.is_empty():
				_press_button(event.index, action)
				get_viewport().set_input_as_handled()
			elif event.position.x < size.x * 0.45 and stick_finger < 0:
				stick_finger = event.index
				stick_origin = event.position
				stick_vector = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif event.position.x >= size.x * 0.45 and look_finger < 0:
				look_finger = event.index
				look_last = event.position
				get_viewport().set_input_as_handled()
		else:
			if event.index == stick_finger:
				stick_finger = -1
				stick_vector = Vector2.ZERO
				_apply_stick()
			elif event.index == look_finger:
				look_finger = -1
			_release_finger(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == stick_finger:
			var offset: Vector2 = event.position - stick_origin
			if offset.length() > STICK_RADIUS:
				stick_origin = event.position - offset.normalized() * STICK_RADIUS
				offset = offset.normalized() * STICK_RADIUS
			stick_vector = offset / STICK_RADIUS
			_apply_stick()
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif event.index == look_finger:
			var delta: Vector2 = event.position - look_last
			look_last = event.position
			if game != null and is_instance_valid(game.player) and not _blocked():
				game.player.add_touch_look(delta)
			get_viewport().set_input_as_handled()

func _apply_stick() -> void:
	var v := stick_vector if stick_vector.length() > 0.18 else Vector2.ZERO
	_set_axis("move_left", maxf(0.0, -v.x))
	_set_axis("move_right", maxf(0.0, v.x))
	_set_axis("move_forward", maxf(0.0, -v.y))
	_set_axis("move_back", maxf(0.0, v.y))
	if not run_latched:
		if v.length() > 0.95: Input.action_press("run")
		else: Input.action_release("run")

func _set_axis(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, clampf(strength * 1.15, 0.0, 1.0))
	else:
		Input.action_release(action)

func _action_at(point: Vector2) -> String:
	for control: Dictionary in controls:
		if point.distance_to(control.center) <= float(control.get("radius", BUTTON_RADIUS)):
			return String(control.action)
	return ""

func _press_button(finger: int, action: String) -> void:
	if action == "run":
		run_latched = not run_latched
		if run_latched: Input.action_press("run")
		else: Input.action_release("run")
		return
	finger_actions[finger] = action
	Input.action_press(action)

func _release_finger(finger: int) -> void:
	if not finger_actions.has(finger):
		return
	Input.action_release(String(finger_actions[finger]))
	finger_actions.erase(finger)

func _release_all() -> void:
	for action: Variant in finger_actions.values():
		Input.action_release(String(action))
	finger_actions.clear()
	for action in ["move_left", "move_right", "move_forward", "move_back", "run"]:
		Input.action_release(action)

func _draw() -> void:
	if not visible or _blocked():
		return
	var font := ThemeDB.fallback_font
	var base := stick_origin if stick_finger >= 0 else Vector2(150, size.y - 150)
	draw_circle(base, STICK_RADIUS, Color(0.05, 0.08, 0.06, 0.35))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, BUTTON_BORDER, 2.0, true)
	draw_circle(base + stick_vector * STICK_RADIUS, 30.0, BUTTON_ACTIVE if stick_finger >= 0 else BUTTON_COLOR)
	if stick_finger < 0:
		draw_string(font, base + Vector2(-STICK_RADIUS, STICK_RADIUS + 24), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, STICK_RADIUS * 2.0, 15, Color(1, 1, 1, 0.7))
		draw_string(font, Vector2(size.x * 0.62, size.y - 40), "Drag here to look", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.45))
	for control: Dictionary in controls:
		var center: Vector2 = control.center
		var radius := float(control.get("radius", BUTTON_RADIUS))
		var pressed := run_latched if control.action == "run" else Input.is_action_pressed(String(control.action))
		draw_circle(center, radius, BUTTON_ACTIVE if pressed else BUTTON_COLOR)
		draw_arc(center, radius, 0.0, TAU, 40, BUTTON_BORDER, 2.0, true)
		draw_string(font, center + Vector2(-radius, 6), String(control.label), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 16, Color(0.1, 0.2, 0.13) if pressed else Color.WHITE)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()
