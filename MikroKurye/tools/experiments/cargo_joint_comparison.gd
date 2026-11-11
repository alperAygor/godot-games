class_name CargoJointComparison
extends "res://tools/game_probe.gd"

## Execute every protected probe phase unchanged against an isolated runtime fixture.
const TRIAL_SCRIPT: Script = preload("res://tools/experiments/cargo_joint_trial.gd")


func _step_load() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		_setup_fail("Joint comparison could not load production scene")
		return
	_scene = packed.instantiate()
	var basket: RigidBody3D = _scene.get_node("Robot/CargoBasket") as RigidBody3D
	# Replace before entering the tree, so the production integrator never runs.
	basket.set_script(null)
	basket.set_script(TRIAL_SCRIPT)
	root.add_child(_scene)
	_go(Phase.READY)
