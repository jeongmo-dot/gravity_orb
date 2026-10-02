extends SceneTree

const OUTPUT_PATH: String = "res://artifacts/jolt3d_second_settings.json"
const EXTRA_SETTINGS: Array[String] = [
	"physics/3d/run_on_separate_thread",
	"threading/worker_pool/max_threads",
	"rendering/driver/threads/thread_model",
]


func _initialize() -> void:
	var settings: Dictionary = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property.get("name", ""))
		if setting_name.begins_with("physics/jolt_physics_3d/"):
			settings[setting_name] = ProjectSettings.get_setting(setting_name)
	for setting_name: String in EXTRA_SETTINGS:
		settings[setting_name] = ProjectSettings.get_setting(setting_name, null)
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", ""),
		"settings": settings,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Jolt settings report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("JOLT3D_SETTINGS %s" % JSON.stringify(report))
	quit(0)
