extends SceneTree
## Pure page boundaries plus real UI coordinator state transitions.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	check(ResourceLoader.exists("res://scripts/field_journal.gd"), "Journal supports arbitrary catalog pages")
	if failures:
		finish()
		return
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func run_checks() -> void:
	var pages: GDScript = load("res://scripts/field_journal.gd")
	check(pages.page_count(0) == 1 and pages.ids_on_page(0, 0).is_empty(), "Empty catalogs have a safe empty page")
	check(pages.page_count(8) == 1 and pages.page_count(11) == 2 and pages.page_count(24) == 3, "Page count follows actual catalog capacity")
	check(pages.ids_on_page(0, 11) == [0, 1, 2, 3, 4, 5, 6, 7], "First page retains the original eight IDs")
	check(pages.ids_on_page(1, 11) == [8, 9, 10], "Last page has only existing new species")
	check(pages.ids_on_page(-3, 11) == pages.ids_on_page(0, 11), "Negative pages clamp safely")
	check(pages.ids_on_page(99, 11) == pages.ids_on_page(1, 11), "Excess pages clamp to the last page")
	var source: GDScript = load("res://tests/capture_game.gd")
	var game = source.new()
	root.add_child(game)
	await process_frame
	game.state = GameState.new()
	game.state.choose_starter(0)
	game.mode = "explore"
	game._open_menu("journal")
	check(game.journal_page == 0 and game.journal_visible_ids().size() == 8, "Journal opens with a valid first page")
	game.handle_action("journal_next")
	check(game.journal_page == 1 and game.journal_id == 8 and game.journal_visible_ids() == [8, 9, 10], "Next page selects its first valid species")
	game.handle_action("journal:10")
	check(game.journal_id == 10, "New species can be selected")
	check(game.selection == 7, "Selected detail and focused visible card agree")
	game.handle_action("journal_next")
	check(game.journal_page == 1 and game.journal_id == 10, "Paging past the end preserves the current entry")
	game.handle_action("journal:999")
	check(game.journal_id == 10, "Invalid species actions cannot create an empty detail panel")
	game.handle_action("journal_previous")
	check(game.journal_page == 0 and game.journal_id == 0, "Previous page returns to the original catalog")
	game.handle_action("journal_previous")
	check(game.journal_page == 0 and game.journal_id == 0, "Paging before the beginning preserves a valid selection")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_PAGEDOWN
	game._input(event)
	check(game.journal_page == 1 and game.journal_id == 8, "PageDown uses the real keyboard input path")
	event.physical_keycode = KEY_PAGEUP
	game._input(event)
	check(game.journal_page == 0 and game.journal_id == 0, "PageUp returns through the real keyboard path")
	game.handle_action("journal:9")
	check(game.journal_page == 1 and game.journal_id == 9, "Direct species selection synchronizes its page")
	game._new_game()
	check(game.journal_page == 0 and game.journal_id == 0, "New journeys reset journal navigation")
	game.handle_action("journal_next")
	check(game.journal_page == 0, "Page actions cannot change navigation outside the journal")
	game.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("JOURNAL TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
