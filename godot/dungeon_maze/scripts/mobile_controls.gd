class_name MobileControls
extends Control
## Landscape touch controls in a shooter-style layout: a floating movement joystick on the
## left, a large ENGAGE button bottom-right with JUMP, CROUCH and RUN arcing around it, active
## buff badges above that cluster, PAUSE and MAP upper-left, and drag-anywhere-on-the-right
## to look. Sizes are fractions of the screen's short side (720 logical units at scale 1), so
## controls stay finger-sized on high-resolution phones; `scale_factor` is the player's
## "Touch control size" setting.

const BUTTON_COLOR := Color(0.12, 0.14, 0.13, 0.5)
const BUTTON_ACTIVE := Color(0.78, 0.9, 0.72, 0.92)
const BUTTON_BORDER := Color(0.92, 0.95, 0.9, 0.72)
const ENGAGE_READY := Color(0.96, 0.78, 0.3, 0.95)
const ICON := Color(1, 1, 1, 0.92)
const ICON_PRESSED := Color(0.1, 0.18, 0.12)

var game: Node
var controls: Array[Dictionary] = []
var finger_actions: Dictionary = {}
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick_home := Vector2.ZERO
var stick_vector := Vector2.ZERO
var look_finger := -1
var look_last := Vector2.ZERO
var run_latched := false
var scale_factor := 1.0
var stick_radius := 115.0
var unit := 1.0
var engage_center := Vector2.ZERO
var left_handed := false ## Setting: joystick on the right, action cluster on the left.
var vibration := true ## Setting: short vibration on button press.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	# "--touch-preview" shows the controls on a desktop for screenshot checks.
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch-preview" in OS.get_cmdline_user_args()
	resized.connect(_layout_controls)
	_layout_controls()

func _exit_tree() -> void:
	_release_all()

func set_scale_factor(value: float) -> void:
	scale_factor = clampf(value, 0.6, 1.8)
	_layout_controls()

func _layout_controls() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	var u := minf(s.x, s.y) / 720.0 * scale_factor
	unit = u
	stick_radius = 115.0 * u
	# Left-handed mirrors the joystick and the action cluster across the screen.
	var side := -1.0 if left_handed else 1.0
	stick_home = Vector2(stick_radius + 70.0 * u, s.y - stick_radius - 60.0 * u)
	var engage_r := 92.0 * u
	engage_center = Vector2(s.x - 58.0 * u - engage_r, s.y - 52.0 * u - engage_r)
	if left_handed:
		stick_home.x = s.x - stick_home.x
		engage_center.x = s.x - engage_center.x
	var e := engage_center
	var small := 50.0 * u
	controls = [
		{"action": "interact", "label": "ENGAGE", "icon": "swords", "center": e, "radius": engage_r},
		{"action": "jump", "label": "JUMP", "icon": "up", "center": e + Vector2(-190.0 * side, 6.0) * u, "radius": 58.0 * u},
		{"action": "crouch", "label": "CROUCH", "icon": "down", "center": e + Vector2(-150.0 * side, -128.0) * u, "radius": small},
		{"action": "run", "label": "RUN", "icon": "run", "center": e + Vector2(-20.0 * side, -190.0) * u, "radius": small},
		# Upper-left, under the timer and buff chips, so they never cover the map (top-right).
		{"action": "pause", "label": "PAUSE", "icon": "pause", "center": Vector2(70.0, 260.0) * u, "radius": 46.0 * u},
		{"action": "map", "label": "MAP", "icon": "map", "center": Vector2(178.0, 260.0) * u, "radius": 46.0 * u},
		{"action": "settings", "label": "SETTINGS", "icon": "gear", "center": Vector2(286.0, 260.0) * u, "radius": 46.0 * u},
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
			elif _in_stick_zone(event.position) and stick_finger < 0:
				stick_finger = event.index
				stick_origin = event.position
				stick_vector = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif not _in_stick_zone(event.position) and look_finger < 0:
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
			if offset.length() > stick_radius:
				stick_origin = event.position - offset.normalized() * stick_radius
				offset = offset.normalized() * stick_radius
			stick_vector = offset / stick_radius
			_apply_stick()
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif event.index == look_finger:
			var delta: Vector2 = event.position - look_last
			look_last = event.position
			if game != null and is_instance_valid(game.player) and not _blocked():
				# Normalised by the short side so the turn per swipe is the same on any screen.
				game.player.add_touch_look(delta / maxf(1.0, minf(size.x, size.y)))
			get_viewport().set_input_as_handled()

func _in_stick_zone(point: Vector2) -> bool:
	return point.x > size.x * 0.55 if left_handed else point.x < size.x * 0.45

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
	# A little extra reach around each button makes them easier to hit without looking.
	for control: Dictionary in controls:
		if point.distance_to(control.center) <= float(control.radius) + 10.0 * unit:
			return String(control.action)
	return ""

func _press_button(finger: int, action: String) -> void:
	if vibration:
		Input.vibrate_handheld(15)
	# Pause and settings are opened directly: a simulated action press creates no InputEvent,
	# so the game's _unhandled_input never saw the touch PAUSE button.
	if action == "pause":
		if game != null and game.has_method("_toggle_pause"): game._toggle_pause()
		return
	if action == "settings":
		if game != null and game.has_method("open_settings"): game.open_settings()
		return
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
	for action in ["move_left", "move_right", "move_forward", "move_back", "run", "interact", "jump", "crouch"]:
		Input.action_release(action)

func _is_on(action: String) -> bool:
	match action:
		"run": return run_latched
		"crouch": return game != null and is_instance_valid(game.player) and bool(game.player.get("crouching"))
	return Input.is_action_pressed(action)

func _draw() -> void:
	if not visible or _blocked():
		return
	var font := ThemeDB.fallback_font
	var u := unit
	var base := stick_origin if stick_finger >= 0 else stick_home
	draw_circle(base, stick_radius, Color(0.05, 0.07, 0.06, 0.32))
	draw_arc(base, stick_radius, 0.0, TAU, 56, BUTTON_BORDER, 3.0 * u, true)
	draw_arc(base, stick_radius * 0.55, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 2.0 * u, true)
	draw_circle(base + stick_vector * stick_radius, 48.0 * u, BUTTON_ACTIVE if stick_finger >= 0 else Color(0.85, 0.9, 0.85, 0.38))
	if stick_finger < 0:
		draw_string(font, base + Vector2(-stick_radius, stick_radius + 34.0 * u), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, stick_radius * 2.0, int(20.0 * u), Color(1, 1, 1, 0.7))
		draw_string(font, Vector2(size.x * (0.3 if left_handed else 0.46), size.y - 22.0 * u), "Drag here to look", HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * u), Color(1, 1, 1, 0.45))
	var engage_ready := game != null and game.has_method("engage_target") and int(game.engage_target()) >= 0
	for control: Dictionary in controls:
		var center: Vector2 = control.center
		var radius := float(control.radius)
		var action := String(control.action)
		var on := _is_on(action)
		var fill := BUTTON_ACTIVE if on else BUTTON_COLOR
		var ring := BUTTON_BORDER
		if action == "interact":
			ring = ENGAGE_READY if engage_ready else Color(1, 1, 1, 0.35)
			if not engage_ready and not on:
				fill = Color(0.12, 0.14, 0.13, 0.3)
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 48, ring, (5.0 if action == "interact" else 3.0) * u, true)
		var ink := ICON_PRESSED if on else (ICON if action != "interact" or engage_ready else Color(1, 1, 1, 0.45))
		_draw_icon(String(control.icon), center + Vector2(0, -radius * 0.14), radius * 0.42, ink, u)
		draw_string(font, center + Vector2(-radius, radius * 0.58), String(control.label), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(clampf(radius * 0.3, 13.0 * u, 20.0 * u)), ink)
	_draw_buffs(font, u)

## Active relic buffs as round badges above the action cluster (shooter "skill" slots).
func _draw_buffs(font: Font, u: float) -> void:
	if game == null or not ("active_buffs" in game) or game.active_buffs.is_empty() or bool(game.get("map_open")):
		return
	var i := 0
	for key: String in game.active_buffs:
		var center := engage_center + Vector2(40.0 * (-1.0 if left_handed else 1.0), -300.0 - 100.0 * i) * u
		var radius := 32.0 * u
		draw_circle(center, radius, Color(0.1, 0.12, 0.2, 0.7))
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.62, 0.8, 1.0, 0.85), 3.0 * u, true)
		var short := String(game.BOOSTS[key].short) if game.BOOSTS.has(key) else key
		draw_string(font, center + Vector2(-radius * 1.6, 4.0 * u), short.substr(0, 6), HORIZONTAL_ALIGNMENT_CENTER, radius * 3.2, int(15.0 * u), Color.WHITE)
		draw_string(font, center + Vector2(-radius, radius + 18.0 * u), "%ds" % ceili(float(game.active_buffs[key])), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(14.0 * u), Color(1, 1, 1, 0.8))
		i += 1

func _draw_icon(kind: String, c: Vector2, r: float, color: Color, u: float) -> void:
	var w := maxf(2.0, 5.0 * u)
	match kind:
		"swords":
			for side in [-1.0, 1.0]:
				draw_line(c + Vector2(-r * side, -r), c + Vector2(r * side, r), color, w, true)
				var hilt := c + Vector2(r * 0.55 * side, r * 0.55)
				draw_line(hilt + Vector2(-r * 0.3, r * 0.3 * side), hilt + Vector2(r * 0.3, -r * 0.3 * side), color, w, true)
		"up":
			draw_polyline(PackedVector2Array([c + Vector2(-r, r * 0.35), c + Vector2(0, -r * 0.55), c + Vector2(r, r * 0.35)]), color, w, true)
			draw_line(c + Vector2(-r * 0.8, r), c + Vector2(r * 0.8, r), color, w, true)
		"down":
			draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.45), c + Vector2(0, r * 0.45), c + Vector2(r, -r * 0.45)]), color, w, true)
			draw_line(c + Vector2(-r * 0.8, r), c + Vector2(r * 0.8, r), color, w, true)
		"run":
			for dx in [-0.45, 0.25]:
				draw_polyline(PackedVector2Array([c + Vector2((dx - 0.3) * r, -r * 0.7), c + Vector2((dx + 0.35) * r, 0), c + Vector2((dx - 0.3) * r, r * 0.7)]), color, w, true)
		"gear":
			draw_arc(c, r * 0.5, 0.0, TAU, 24, color, w, true)
			for k in 8:
				var dir := Vector2.RIGHT.rotated(TAU * k / 8.0)
				draw_line(c + dir * r * 0.62, c + dir * r * 0.95, color, w * 1.2, true)
		"pause":
			draw_line(c + Vector2(-r * 0.35, -r * 0.7), c + Vector2(-r * 0.35, r * 0.7), color, w * 1.3, true)
			draw_line(c + Vector2(r * 0.35, -r * 0.7), c + Vector2(r * 0.35, r * 0.7), color, w * 1.3, true)
		"map":
			draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.6), c + Vector2(-r * 0.33, -r * 0.8), c + Vector2(r * 0.33, -r * 0.6), c + Vector2(r, -r * 0.8), c + Vector2(r, r * 0.6), c + Vector2(r * 0.33, r * 0.8), c + Vector2(-r * 0.33, r * 0.6), c + Vector2(-r, r * 0.8), c + Vector2(-r, -r * 0.6)]), color, w * 0.8, true)

# Redraw only when something visible changes: redrawing these vector controls every frame
# cost almost half the frame rate in the Compatibility renderer (56 → 30 fps).
var _last_state := ""
func _process(_delta: float) -> void:
	if not visible:
		return
	var state := "%s|%s|%s|%s|%s|%s|%s" % [_blocked(), game != null and game.has_method("engage_target") and int(game.engage_target()) >= 0, run_latched, _is_on("crouch"), stick_finger, stick_vector.snapped(Vector2(0.02, 0.02)), _held_actions()]
	if game != null and "active_buffs" in game:
		state += "|%s|%s" % [game.get("map_open"), ",".join(game.active_buffs.keys().map(func(k): return "%s%d" % [k, ceili(float(game.active_buffs[k]))]))]
	if state != _last_state:
		_last_state = state
		queue_redraw()

func _held_actions() -> String:
	var held := ""
	for control: Dictionary in controls:
		if Input.is_action_pressed(String(control.action)): held += String(control.action)
	return held
