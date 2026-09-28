extends SceneTree

const TEST_DIRECTORIES: Array[String] = ["res://tests", "res://tests/scenarios"]
const TEST_FILE_PREFIX: String = "test_"
const TEST_FILE_SUFFIX: String = ".gd"
const TEST_METHOD_PREFIX: String = "test_"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	for directory: String in TEST_DIRECTORIES:
		await _run_directory(directory)

	var total: int = _passed + _failed
	print("Tests: %d passed, %d failed, %d total" % [_passed, _failed, total])
	quit(1 if _failed > 0 else 0)


func _run_directory(directory: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(directory)
	files.sort()
	for file_name: String in files:
		if not file_name.begins_with(TEST_FILE_PREFIX) or not file_name.ends_with(TEST_FILE_SUFFIX):
			continue
		await _run_test_file(directory.path_join(file_name))


func _run_test_file(path: String) -> void:
	var test_script: Script = load(path) as Script
	if test_script == null:
		_record_runner_failure(path, "could not load script")
		return

	var instance_value: Variant = test_script.new()
	if not (instance_value is TestCase):
		_record_runner_failure(path, "test script must extend TestCase")
		return

	var test_instance: TestCase = instance_value as TestCase
	test_instance.tree = self
	var method_names: Array[String] = []
	for method_info: Dictionary in test_instance.get_method_list():
		var method_name: String = str(method_info.get("name", ""))
		if method_name.begins_with(TEST_METHOD_PREFIX):
			method_names.append(method_name)
	method_names.sort()

	for method_name: String in method_names:
		var failures_before: int = test_instance.get_failure_count()
		await test_instance.call(method_name)
		var failures_after: int = test_instance.get_failure_count()
		if failures_after == failures_before:
			_passed += 1
			print("PASS %s::%s" % [path, method_name])
			continue

		_failed += 1
		print("FAIL %s::%s" % [path, method_name])
		for failure_index: int in range(failures_before, failures_after):
			print("  %s" % test_instance.failures[failure_index])


func _record_runner_failure(path: String, message: String) -> void:
	_failed += 1
	print("FAIL %s: %s" % [path, message])
