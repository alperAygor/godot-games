extends SceneTree
func _initialize() -> void:
	for name in ["ship", "chaser", "tank", "dais", "pillar"]:
		var ps: PackedScene = load("res://assets/models/%s.glb" % name)
		var inst: Node3D = ps.instantiate()
		var total := AABB()
		var first := true
		for child in inst.get_children():
			if child is MeshInstance3D:
				var aabb: AABB = (child as MeshInstance3D).get_aabb()
				if first:
					total = aabb
					first = false
				else:
					total = total.merge(aabb)
		print("%-8s size=%s children=%d" % [name, str(total.size), inst.get_child_count()])
		for child in inst.get_children():
			if child is MeshInstance3D and child.mesh.get_surface_count() > 0:
				var m = child.mesh.surface_get_material(0)
				if m is StandardMaterial3D:
					print("    emis=%s en=%.2f albedo=%s" % [str(m.emission), m.emission_energy_multiplier, str(m.albedo_color)])
				break
		inst.free()
	quit()
