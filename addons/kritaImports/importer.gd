@tool
extends EditorImportPlugin

# Set to false for faster imports (no console output)
const DEBUG_PRINTS = false

func _get_importer_name() -> String:
	return "kra_importer"

func _get_visible_name() -> String:
	return "Krita Image"

func _get_recognized_extensions() -> PackedStringArray:
	return ["kra"]

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "Image"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(path: String, preset_index: int) -> Array:
	return []

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array) -> int:
	if DEBUG_PRINTS:
		print("========================================")
		print("Krita Import: ", source_file)
	
	# Parse the .kra file (which is a ZIP archive)
	var img = _parse_kra(source_file)
	if img == null:
		push_error("Failed to parse Krita file: " + source_file)
		return FAILED
	
	# Set metadata on the image to help track changes
	img.set_meta("kra_source", source_file)
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file:
		var content_hash = hash(file.get_buffer(file.get_length()))
		file.close()
		img.set_meta("kra_hash", content_hash)
	img.set_meta("import_time", Time.get_unix_time_from_system())
	
	# Save the Image resource
	var full_save_path = "%s.%s" % [save_path, _get_save_extension()]
	var err = ResourceSaver.save(img, full_save_path)
	
	if err != OK:
		push_error("Failed to save image resource: " + str(err))
		return FAILED
	
	if DEBUG_PRINTS:
		print("✓ Successfully imported to: ", full_save_path)
		print("========================================")
	
	return OK

func _parse_kra(kra_path: String) -> Image:
	# .kra files are ZIP archives containing:
	# - mergedimage.png (the flattened image)
	# - maindoc.xml (document metadata)
	# - layers (individual layer data)
	
	# First, verify the file exists and is readable
	if not FileAccess.file_exists(kra_path):
		push_error("Krita file does not exist: " + kra_path)
		return null
	
	# Check if file is actually a ZIP by reading magic bytes
	var file = FileAccess.open(kra_path, FileAccess.READ)
	if not file:
		push_error("Cannot open Krita file: " + kra_path)
		return null
	
	var magic = file.get_buffer(4)
	file.close()
	
	# ZIP files start with "PK" (0x50 0x4B)
	if magic.size() < 2 or magic[0] != 0x50 or magic[1] != 0x4B:
		push_error("File is not a valid ZIP/KRA archive (invalid magic bytes)")
		return null
	
	# We'll extract the mergedimage.png
	var reader = ZIPReader.new()
	var err = reader.open(kra_path)
	
	if err != OK:
		push_error("Failed to open .kra file as ZIP: " + str(err) + " (file may be open in Krita or corrupted)")
		return null
	
	if DEBUG_PRINTS:
		print("Opened .kra file, extracting merged image...")
	
	# Look for mergedimage.png
	var files = reader.get_files()
	var merged_image_path = ""
	
	if DEBUG_PRINTS:
		print("Files in archive: ", files)
	
	for file_path in files:
		if file_path.ends_with("mergedimage.png") or file_path == "mergedimage.png":
			merged_image_path = file_path
			break
	
	if merged_image_path == "":
		push_error("Could not find mergedimage.png in .kra archive. Available files: " + str(files))
		reader.close()
		return null
	
	if DEBUG_PRINTS:
		print("Found merged image at: ", merged_image_path)
	
	# Read the PNG data
	var png_data = reader.read_file(merged_image_path)
	reader.close()
	
	if png_data.size() == 0:
		push_error("Failed to read merged image data (0 bytes)")
		return null
	
	# Load the PNG as an Image
	var img = Image.new()
	err = img.load_png_from_buffer(png_data)
	
	if err != OK:
		push_error("Failed to load PNG from buffer: " + str(err))
		return null
	
	if DEBUG_PRINTS:
		print("✓ Successfully loaded image: %dx%d" % [img.get_width(), img.get_height()])
	
	return img
