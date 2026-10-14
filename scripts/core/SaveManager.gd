class_name SaveManager
extends RefCounted
## Local persistence manager with versioned JSON schema and automatic corruption recovery.

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://blokora_save.json"

var save_path: String = DEFAULT_SAVE_PATH
var data: Dictionary = {}
var was_corrupted: bool = false


func _init(custom_path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = custom_path if custom_path != "" else DEFAULT_SAVE_PATH
	load_from_disk()


static func create_default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"best_score": 0,
		"settings": {
			"sound_enabled": true,
			"haptics_enabled": true,
			"high_contrast": false
		},
		"progression": {
			"player_level": 1,
			"player_xp": 0,
			"coins": 0,
			"powerup_inventory": {
				"mega_bomb": 0,
				"mighty_hand": 0,
				"hammer": 0,
				"row_blaster": 0,
				"tray_shuffle": 0
			}
		}
	}


## Loads save data from `save_path`. Recovers gracefully to defaults if missing or corrupted.
func load_from_disk() -> bool:
	was_corrupted = false
	data = create_default_data()

	if not FileAccess.file_exists(save_path):
		return true

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		was_corrupted = true
		return false

	var raw_text := file.get_as_text()
	file.close()

	if raw_text.strip_edges() == "":
		was_corrupted = true
		save_to_disk()
		return false

	var json := JSON.new()
	var err := json.parse(raw_text)
	if err != OK or not (json.data is Dictionary):
		was_corrupted = true
		save_to_disk()
		return false

	var parsed: Dictionary = json.data
	if not _validate_and_migrate(parsed):
		was_corrupted = true
		data = create_default_data()
		save_to_disk()
		return false

	return true


func _validate_and_migrate(parsed: Dictionary) -> bool:
	if not parsed.has("version"):
		return false
	var ver_raw = parsed["version"]
	if typeof(ver_raw) != TYPE_INT and typeof(ver_raw) != TYPE_FLOAT:
		return false
	var ver := int(ver_raw)
	if ver < 1 or ver > SAVE_VERSION:
		return false

	if not parsed.has("best_score"):
		return false
	var best_raw = parsed["best_score"]
	if typeof(best_raw) != TYPE_INT and typeof(best_raw) != TYPE_FLOAT:
		return false
	var best_val := int(best_raw)
	if best_val < 0:
		return false

	data = create_default_data()
	data["version"] = SAVE_VERSION
	data["best_score"] = best_val

	if parsed.has("settings") and parsed["settings"] is Dictionary:
		var src_settings: Dictionary = parsed["settings"]
		for k in ["sound_enabled", "haptics_enabled", "high_contrast"]:
			if src_settings.has(k) and typeof(src_settings[k]) == TYPE_BOOL:
				data["settings"][k] = src_settings[k]

	if parsed.has("progression") and parsed["progression"] is Dictionary:
		var src_prog: Dictionary = parsed["progression"]
		if src_prog.has("player_level") and (typeof(src_prog["player_level"]) == TYPE_INT or typeof(src_prog["player_level"]) == TYPE_FLOAT):
			data["progression"]["player_level"] = maxi(1, int(src_prog["player_level"]))
		if src_prog.has("coins") and (typeof(src_prog["coins"]) == TYPE_INT or typeof(src_prog["coins"]) == TYPE_FLOAT):
			data["progression"]["coins"] = maxi(0, int(src_prog["coins"]))

	return true


## Writes current `data` dictionary atomically to `save_path`.
func save_to_disk() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	var json_string := JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true


func get_best_score() -> int:
	return int(data.get("best_score", 0))


func set_best_score(new_best: int) -> bool:
	var clamped := maxi(0, new_best)
	if clamped > get_best_score():
		data["best_score"] = clamped
		return save_to_disk()
	return true


func get_setting(key: String, default_val: Variant = null) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, default_val)


func set_setting(key: String, value: Variant) -> bool:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	data["settings"][key] = value
	return save_to_disk()
