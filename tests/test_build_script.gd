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


func test_release_build_requires_clean_worktree_before_cleanup() -> void:
	var script_text: String = _build_script_text()
	var status_index: int = script_text.find("git -C $repoPath status --porcelain")
	var cleanup_index: int = script_text.find("foreach ($stalePath")
	assert_true(status_index >= 0, "Release build inspects Git worktree status")
	assert_true(
		script_text.contains("Release build requires a clean Git worktree"),
		"dirty Release builds explain the clean-worktree requirement"
	)
	assert_true(
		script_text.contains("use -Debug for verification builds"),
		"dirty Release builds point verification builds to -Debug"
	)
	assert_true(
		status_index < cleanup_index,
		"clean-worktree guard runs before any same-version cleanup"
	)


func test_release_build_refuses_same_version_without_explicit_replace() -> void:
	var script_text: String = _build_script_text()
	var same_version_guard_index: int = script_text.find("-not $ReplaceSameVersion -and")
	var cleanup_index: int = script_text.find("foreach ($stalePath")
	assert_true(
		script_text.contains("[switch]$ReplaceSameVersion"),
		"Release build exposes an explicit same-version replacement switch"
	)
	assert_true(
		script_text.contains("Release artifact already exists"),
		"same-version Release build stops with an actionable message"
	)
	assert_true(
		script_text.contains("Use -Debug for verification builds or -ReplaceSameVersion"),
		"same-version message distinguishes verification and intentional replacement"
	)
	assert_true(
		same_version_guard_index >= 0 and same_version_guard_index < cleanup_index,
		"same-version guard runs before any same-version cleanup"
	)


func _build_script_text() -> String:
	var script_path: String = ProjectSettings.globalize_path("res://tools/build_windows.ps1")
	var script_text: String = FileAccess.get_file_as_string(script_path)
	assert_true(not script_text.is_empty(), "Windows build script is readable")
	return script_text
