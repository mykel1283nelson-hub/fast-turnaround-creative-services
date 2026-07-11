extends Node3D

const PLAYER_SPEED := 8.0
const GROUND_Y := 0.0

var player: CharacterBody3D
var camera: Camera3D
var ui_root: Control
var objective_label: Label
var resource_label: Label
var hint_label: Label
var resource_nodes: Array[Node3D] = []
var resource_count := 0
var rescued_villager := false
var boss_cleared := false
var run_complete := false
var cage_root: Node3D
var villager: MeshInstance3D
var boss_root: Node3D
var portal_core: MeshInstance3D

var camp_position := Vector3(12.0, GROUND_Y, 4.0)
var boss_position := Vector3(22.0, GROUND_Y, -14.0)
var portal_position := Vector3(31.0, GROUND_Y, -14.0)


func _ready() -> void:
	_build_world()
	_build_ui()
	_update_ui()
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_gallery")
	elif "--smoke-test" in OS.get_cmdline_user_args():
		_run_smoke_test()


func _physics_process(_delta: float) -> void:
	if player == null or run_complete or "--capture" in OS.get_cmdline_user_args():
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	player.velocity = direction * PLAYER_SPEED
	player.move_and_slide()
	player.position.y = 0.9

	if direction.length_squared() > 0.01:
		var target_rotation := atan2(direction.x, direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_rotation, 0.18)

	_collect_nearby_resources()
	_handle_progression()


func _build_world() -> void:
	_build_environment()
	_add_box(Vector3(0.0, -0.45, 0.0), Vector3(72.0, 0.8, 54.0), Color("#355d46"), "Ground", true)

	# Main readable route: village -> resource loop -> camp -> boss arena -> portal.
	_add_path(Vector3(-18.0, 0.03, 10.0), Vector3(-2.0, 0.03, 2.0), 3.1)
	_add_path(Vector3(-2.0, 0.03, 2.0), camp_position, 3.1)
	_add_path(camp_position, Vector3(16.0, 0.03, -5.0), 2.6)
	_add_path(Vector3(16.0, 0.03, -5.0), boss_position, 3.0)
	_add_path(boss_position, portal_position, 2.8)
	_add_path(Vector3(-2.0, 0.03, 2.0), Vector3(-3.0, 0.03, -13.0), 2.2)
	_add_path(Vector3(-3.0, 0.03, -13.0), Vector3(8.0, 0.03, -9.0), 2.2)
	_add_path(Vector3(8.0, 0.03, -9.0), camp_position, 2.2)

	_build_village()
	_build_resource_grove()
	_build_enemy_camp()
	_build_boss_arena()
	_build_portal()
	_build_boundary()
	_build_player()


func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#92c9c2")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#d9eee1")
	settings.ambient_light_energy = 0.72
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("#fff2c4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


func _build_village() -> void:
	var origin := Vector3(-18.0, 0.0, 10.0)
	_add_label("VILLAGE HUB\nSTART", origin + Vector3(0.0, 4.0, 0.0), Color("#f8f0c8"))
	_add_box(origin + Vector3(0.0, 0.06, 0.0), Vector3(11.0, 0.12, 9.0), Color("#5f7f62"), "VillagePad")

	for offset in [Vector3(-3.4, 1.0, -2.5), Vector3(3.2, 1.0, -2.3), Vector3(-3.0, 1.0, 2.6)]:
		_add_box(origin + offset, Vector3(3.0, 2.0, 2.5), Color("#c79b62"), "VillageHut", true)
		_add_cone(origin + offset + Vector3(0.0, 1.8, 0.0), 2.3, 1.7, Color("#784d38"), "HutRoof")

	_add_cylinder(origin + Vector3(2.8, 0.8, 2.6), 0.75, 1.6, Color("#d8c77a"), "VillageWell", true)
	_add_cylinder(origin + Vector3(2.8, 1.5, 2.6), 0.46, 0.24, Color("#3f6b78"), "WellWater")
	_add_label("Gather supplies\nbefore the rescue", origin + Vector3(4.8, 2.5, -0.2), Color("#f6d365"), 30)


func _build_resource_grove() -> void:
	_add_label("RESOURCE LOOP", Vector3(-2.0, 4.1, -8.5), Color("#a8ffcc"))
	var tree_positions := [
		Vector3(-8.0, 0.0, -2.0), Vector3(-7.0, 0.0, -8.0), Vector3(-3.0, 0.0, -14.0),
		Vector3(3.0, 0.0, -14.0), Vector3(8.0, 0.0, -10.0), Vector3(7.0, 0.0, -5.0),
		Vector3(-11.0, 0.0, -12.0), Vector3(4.0, 0.0, -3.0)
	]
	for tree_position in tree_positions:
		_add_tree(tree_position)

	for resource_position in [Vector3(-5.5, 0.65, -4.5), Vector3(-2.0, 0.65, -12.0), Vector3(6.0, 0.65, -8.5)]:
		var crystal := _add_crystal(resource_position)
		resource_nodes.append(crystal)

	_add_box(Vector3(10.0, 0.15, -2.0), Vector3(5.0, 0.3, 2.8), Color("#916d42"), "Bridge", true)
	_add_box(Vector3(10.0, -0.08, -2.0), Vector3(14.0, 0.15, 7.0), Color("#386d7a"), "Stream")
	_add_label("BRIDGE\nchoke point", Vector3(10.0, 2.4, -2.0), Color("#d7f4ff"), 26)


func _build_enemy_camp() -> void:
	_add_label("ENEMY CAMP\nRESCUE", camp_position + Vector3(0.0, 4.5, 0.0), Color("#ffb4a2"))
	_add_box(camp_position + Vector3(0.0, 0.08, 0.0), Vector3(10.5, 0.16, 9.0), Color("#6c5b45"), "CampPad")

	for fence_offset in [-4.6, 4.6]:
		for z_value in [-3.3, -1.1, 1.1, 3.3]:
			_add_cylinder(camp_position + Vector3(fence_offset, 1.0, z_value), 0.18, 2.0, Color("#6a4931"), "Palisade", true)
	for x_value in [-3.2, -1.1, 1.1, 3.2]:
		_add_cylinder(camp_position + Vector3(x_value, 1.0, -4.0), 0.18, 2.0, Color("#6a4931"), "Palisade", true)

	for tent_offset in [Vector3(-2.7, 1.0, 1.7), Vector3(2.8, 1.0, 1.5)]:
		_add_box(camp_position + tent_offset, Vector3(2.4, 2.0, 2.4), Color("#9e3f3f"), "EnemyTent", true)
		_add_cone(camp_position + tent_offset + Vector3(0.0, 1.5, 0.0), 1.8, 1.4, Color("#5c252b"), "TentRoof")

	cage_root = Node3D.new()
	cage_root.name = "VillagerCage"
	cage_root.position = camp_position + Vector3(0.0, 0.0, -1.2)
	add_child(cage_root)
	for x_value in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		_add_cylinder(Vector3(x_value, 1.0, -0.7), 0.09, 2.0, Color("#4e5556"), "CageBar", true, cage_root)
		_add_cylinder(Vector3(x_value, 1.0, 0.7), 0.09, 2.0, Color("#4e5556"), "CageBar", true, cage_root)

	villager = _add_capsule(camp_position + Vector3(0.0, 0.95, -1.2), 0.42, 1.7, Color("#f6d365"), "CapturedVillager")


func _build_boss_arena() -> void:
	_add_label("BOSS ARENA", boss_position + Vector3(0.0, 5.0, 0.0), Color("#e7b3ff"))
	_add_cylinder(boss_position + Vector3(0.0, 0.1, 0.0), 7.2, 0.2, Color("#59606d"), "BossArena")
	for angle_index in range(10):
		var angle := TAU * float(angle_index) / 10.0
		var pillar_position := boss_position + Vector3(cos(angle) * 6.1, 1.4, sin(angle) * 6.1)
		_add_cylinder(pillar_position, 0.5, 2.8, Color("#7e7a88"), "ArenaPillar", true)

	boss_root = Node3D.new()
	boss_root.name = "BossPrototype"
	boss_root.position = boss_position
	add_child(boss_root)
	_add_sphere(Vector3(0.0, 1.45, 0.0), 1.55, Color("#6d2f71"), "BossBody", boss_root)
	for offset in [Vector3(-1.25, 1.0, 0.0), Vector3(1.25, 1.0, 0.0), Vector3(0.0, 1.0, -1.25), Vector3(0.0, 1.0, 1.25)]:
		_add_cone(offset, 0.45, 1.2, Color("#c078d0"), "BossSpike", boss_root)

	_add_label("Rescue unlocks\nthis encounter", boss_position + Vector3(-3.7, 2.5, 5.3), Color("#f6d365"), 26)


func _build_portal() -> void:
	_add_label("BIOME EXIT", portal_position + Vector3(0.0, 4.4, 0.0), Color("#90fff2"))
	_add_cylinder(portal_position + Vector3(-1.6, 1.7, 0.0), 0.36, 3.4, Color("#4a8791"), "PortalPillar", true)
	_add_cylinder(portal_position + Vector3(1.6, 1.7, 0.0), 0.36, 3.4, Color("#4a8791"), "PortalPillar", true)
	_add_box(portal_position + Vector3(0.0, 3.25, 0.0), Vector3(3.7, 0.45, 0.7), Color("#4a8791"), "PortalLintel", true)
	portal_core = _add_box(portal_position + Vector3(0.0, 1.65, 0.0), Vector3(2.6, 2.9, 0.22), Color("#273d43"), "PortalCore")


func _build_boundary() -> void:
	# High silhouettes guide the player without a hard rectangular wall.
	for ridge_position in [
		Vector3(-29.0, 2.0, -18.0), Vector3(-22.0, 2.4, -23.0), Vector3(-12.0, 1.8, -24.0),
		Vector3(2.0, 2.3, -24.0), Vector3(14.0, 2.8, -23.0), Vector3(27.0, 2.5, -22.0),
		Vector3(34.0, 2.2, -7.0), Vector3(34.0, 2.0, 8.0), Vector3(25.0, 2.3, 23.0),
		Vector3(8.0, 2.0, 24.0), Vector3(-10.0, 2.5, 24.0), Vector3(-28.0, 2.0, 20.0)
	]:
		_add_box(ridge_position, Vector3(7.0, 4.0, 3.0), Color("#6b7554"), "BoundaryRidge", true)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Explorer"
	player.position = Vector3(-19.0, 0.9, 9.5)
	add_child(player)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	collision.shape = shape
	player.add_child(collision)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = 1.8
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = _material(Color("#f0c64c"))
	player.add_child(body)

	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.22, 0.22, 0.75)
	var marker := MeshInstance3D.new()
	marker.position = Vector3(0.0, 0.25, -0.58)
	marker.mesh = marker_mesh
	marker.material_override = _material(Color("#263238"))
	player.add_child(marker)

	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.position = Vector3(0.0, 10.5, 13.5)
	camera.fov = 55.0
	camera.current = true
	player.add_child(camera)
	camera.look_at(player.global_position + Vector3(0.0, 0.4, -2.5), Vector3.UP)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui_root)

	var panel := ColorRect.new()
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(420.0, 168.0)
	panel.color = Color(0.035, 0.055, 0.06, 0.9)
	ui_root.add_child(panel)

	var title := Label.new()
	title.position = Vector2(22.0, 15.0)
	title.text = "SUNFALL HOLLOW / BIOME 01"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f4d35e"))
	panel.add_child(title)

	objective_label = Label.new()
	objective_label.position = Vector2(22.0, 51.0)
	objective_label.size = Vector2(370.0, 54.0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color("#f6f7eb"))
	panel.add_child(objective_label)

	resource_label = Label.new()
	resource_label.position = Vector2(22.0, 111.0)
	resource_label.add_theme_font_size_override("font_size", 17)
	resource_label.add_theme_color_override("font_color", Color("#a8ffcc"))
	panel.add_child(resource_label)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-270.0, -64.0)
	hint_label.size = Vector2(540.0, 38.0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.text = "WASD  MOVE    E  INTERACT"
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color("#ffffff"))
	ui_root.add_child(hint_label)


func _collect_nearby_resources() -> void:
	for index in range(resource_nodes.size() - 1, -1, -1):
		var crystal := resource_nodes[index]
		if is_instance_valid(crystal) and player.global_position.distance_to(crystal.global_position) < 1.35:
			resource_nodes.remove_at(index)
			crystal.queue_free()
			resource_count += 1
			_update_ui()


func _handle_progression() -> void:
	var near_camp := player.global_position.distance_to(camp_position) < 3.2
	var near_boss := player.global_position.distance_to(boss_position) < 4.0
	var near_portal := player.global_position.distance_to(portal_position) < 2.5

	if near_camp and not rescued_villager:
		hint_label.text = "E  RESCUE VILLAGER" if resource_count >= 3 else "GATHER 3 SUPPLIES BEFORE THE RESCUE"
		if resource_count >= 3 and Input.is_action_just_pressed("interact"):
			_rescue_villager()
	elif near_boss and rescued_villager and not boss_cleared:
		hint_label.text = "E  START BOSS PROTOTYPE"
		if Input.is_action_just_pressed("interact"):
			_clear_boss()
	elif near_portal and boss_cleared:
		_complete_run()
	else:
		hint_label.text = "WASD  MOVE    E  INTERACT"


func _update_ui() -> void:
	resource_label.text = "SUPPLIES  %d / 3" % resource_count
	if resource_count < 3:
		objective_label.text = "Explore the lower loop and gather three supplies."
	elif not rescued_villager:
		objective_label.text = "Return to the enemy camp and rescue the villager."
	elif not boss_cleared:
		objective_label.text = "The rescued villager unlocks the boss route."
	else:
		objective_label.text = "Cross the arena and enter the biome exit."


func _rescue_villager() -> void:
	rescued_villager = true
	cage_root.visible = false
	villager.material_override = _material(Color("#85f2c4"))
	_update_ui()


func _clear_boss() -> void:
	boss_cleared = true
	boss_root.visible = false
	portal_core.material_override = _material(Color("#50e3c2"), true)
	_update_ui()


func _complete_run() -> void:
	run_complete = true
	objective_label.text = "Biome loop complete. Portal reached."
	hint_label.text = "PROTOTYPE COMPLETE"


func _capture_gallery() -> void:
	var output_dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Capture the playable camera first with the objective UI visible.
	for _frame in range(10):
		await get_tree().process_frame
	_save_viewport_png(output_dir.path_join("player-view.png"))

	camera.reparent(self, true)
	player.visible = false
	ui_root.visible = false
	var shots := [
		{"name": "overview.png", "position": Vector3(42.0, 48.0, 43.0), "target": Vector3(2.0, 0.0, -2.0)},
		{"name": "resource-camp-flow.png", "position": Vector3(-2.0, 22.0, 31.0), "target": Vector3(2.0, 0.0, -4.0)},
		{"name": "boss-and-exit.png", "position": Vector3(42.0, 20.0, 9.0), "target": Vector3(23.0, 0.0, -13.0)}
	]

	for shot in shots:
		camera.global_position = shot["position"]
		camera.look_at(shot["target"], Vector3.UP)
		for _frame in range(6):
			await get_tree().process_frame
		_save_viewport_png(output_dir.path_join(shot["name"]))

	get_tree().quit()


func _run_smoke_test() -> void:
	print("SUNFALL_HOLLOW_SMOKE_TEST_START")
	if not _smoke_require(resource_nodes.size() == 3, "Expected three resources in the exploration loop."):
		return
	while not resource_nodes.is_empty():
		player.global_position = resource_nodes[0].global_position
		_collect_nearby_resources()
	if not _smoke_require(resource_count == 3, "Resource pickups did not complete."):
		return

	_rescue_villager()
	if not _smoke_require(rescued_villager and not cage_root.visible, "Camp rescue state is invalid."):
		return

	_clear_boss()
	if not _smoke_require(boss_cleared and not boss_root.visible, "Boss completion state is invalid."):
		return

	_complete_run()
	if not _smoke_require(run_complete, "Portal did not complete the biome loop."):
		return
	print("SUNFALL_HOLLOW_SMOKE_TEST_OK")
	get_tree().quit()


func _smoke_require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("SUNFALL_HOLLOW_SMOKE_TEST_FAILED: " + message)
	get_tree().quit(1)
	return false


func _save_viewport_png(path: String) -> void:
	var texture := get_viewport().get_texture()
	if texture == null:
		push_warning("Screenshot skipped because this run has no render texture.")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_warning("Screenshot skipped because the rendered image is empty.")
		return
	image.save_png(path)


func _add_path(start: Vector3, finish: Vector3, width: float) -> void:
	var delta := finish - start
	var midpoint := (start + finish) * 0.5
	var path := _add_box(midpoint, Vector3(delta.length(), 0.08, width), Color("#c2ad78"), "TraversalPath")
	path.rotation.y = -atan2(delta.z, delta.x)


func _add_tree(tree_position: Vector3) -> void:
	_add_cylinder(tree_position + Vector3(0.0, 1.0, 0.0), 0.28, 2.0, Color("#6b4934"), "TreeTrunk", true)
	_add_cone(tree_position + Vector3(0.0, 2.7, 0.0), 1.45, 2.8, Color("#2b7a58"), "TreeCanopy")


func _add_crystal(crystal_position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "ResourceCrystal"
	root.position = crystal_position
	add_child(root)
	_add_cone(Vector3.ZERO, 0.48, 1.3, Color("#72f1b8"), "Crystal", root)
	_add_cylinder(Vector3(0.0, -0.5, 0.0), 0.72, 0.12, Color("#234d45"), "CrystalBase", false, root)
	return root


func _add_label(text: String, label_position: Vector3, color: Color, font_size := 36) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = label_position
	label.font_size = font_size
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label


func _add_box(box_position: Vector3, size: Vector3, color: Color, node_name: String, collidable := false, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = box_position
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	if collidable:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _add_cylinder(cylinder_position: Vector3, radius: float, height: float, color: Color, node_name: String, collidable := false, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = cylinder_position
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	if collidable:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _add_cone(cone_position: Vector3, radius: float, height: float, color: Color, node_name: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = cone_position
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_sphere(sphere_position: Vector3, radius: float, color: Color, node_name: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = sphere_position
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_capsule(capsule_position: Vector3, radius: float, height: float, color: Color, node_name: String) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = capsule_position
	instance.mesh = mesh
	instance.material_override = _material(color)
	add_child(instance)
	return instance


func _material(color: Color, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
	return material
