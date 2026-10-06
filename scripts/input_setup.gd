extends RefCounted

# Registers the game's input actions at startup: keyboard (WASD + arrows) and
# any connected gamepad. Actions already defined in the project settings are
# kept and only gain the bindings they are missing.

const STICK_DEADZONE := 0.25

static func ensure() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_bind("move_forward", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_bind("move_back", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_bind("look_left", [], [], JOY_AXIS_RIGHT_X, -1.0)
	_bind("look_right", [], [], JOY_AXIS_RIGHT_X, 1.0)
	_bind("look_up", [], [], JOY_AXIS_RIGHT_Y, -1.0)
	_bind("look_down", [], [], JOY_AXIS_RIGHT_Y, 1.0)
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A])
	_bind("climb_drop", [KEY_X], [JOY_BUTTON_B])
	_bind("run", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind("camera_center", [KEY_C], [JOY_BUTTON_RIGHT_STICK])

static func _bind(action: StringName, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)

	for key: Key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		_add_event(action, key_event)

	for button: JoyButton in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		_add_event(action, button_event)

	if axis >= 0:
		var motion_event := InputEventJoypadMotion.new()
		motion_event.axis = axis as JoyAxis
		motion_event.axis_value = axis_value
		_add_event(action, motion_event)

static func _add_event(action: StringName, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
