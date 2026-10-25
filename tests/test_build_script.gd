extends TestCase


func test_windows_build_preserves_other_version_artifacts() -> void:
	var script_path: String = ProjectSettings.globalize_path("res://tools/build_windows.ps1")
	var script_text: String = FileAccess.get_file_as_string(script_path)
	assert_true(not script_text.is_empty(), "Windows build script is readable")
	assert_true(
		script_text.contains("$sameVersionPaths"),
		"cleanup is limited to explicitly enumerated same-version artifacts"
	)
	assert_true(
		script_text.contains("$preservedArtifacts"),
		"different-version artifacts are snapshotted before the build"
	)
	assert_true(
		script_text.contains("Build removed a different-version artifact"),
		"build fails if a preserved artifact disappears"
	)
	assert_true(
		script_text.contains("Build changed a different-version artifact"),
		"build fails if a preserved artifact changes size"
	)
	assert_true(
		not script_text.contains("Remove-Item -LiteralPath $outputDirectory -Recurse"),
		"build never recursively removes its output directory"
	)
