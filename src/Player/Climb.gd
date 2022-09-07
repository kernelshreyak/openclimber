extends PlayerState
# Basic state when the player is moving around until jumping or lack of input.


func unhandled_input(event: InputEvent) -> void:
	_parent.unhandled_input(event)


func physics_process(delta: float) -> void:
	_parent.physics_process(delta)
	if !player.climbing:
		_state_machine.transition_to("Move/Air")
	elif player.is_on_floor():
		_state_machine.transition_to("Move/Idle")


func enter(msg: = {}) -> void:
	print("entered climb state")
	skin.transition_to(skin.States.CLIMB)
	skin.is_moving = false
	_parent.enter()


func exit() -> void:
	skin.is_moving = false
	_parent.exit()
