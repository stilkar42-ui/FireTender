extends RefCounted
## Optional Windows numerical backend. The story and saves own all physical state.

const KERNEL := &"FiretenderKernel"
static var enabled := _available()

static func _available() -> bool:
	if "--reference-fire" in OS.get_cmdline_user_args():
		return false
	if ClassDB.class_exists(KERNEL) and ClassDB.class_has_method(KERNEL, &"candidate_pairs") \
			and ClassDB.class_has_method(KERNEL, &"support_floors"):
		return true
	if OS.get_name() == "Windows":
		push_warning("Firetender native kernel is unavailable. Using the GDScript solver. Check the native DLL and Godot 4.7 x86-64 runtime.")
	return false
