extends HBoxContainer

# Shows the 4 inventory slots. The equipped slot is highlighted, and when
# none is, the player is using their fists.

const EQUIPPED_COLOR: Color = Color(1.0, 0.85, 0.2)
const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)

@export var inventory: InventoryComponent

var slot_labels: Array[Label] = []

func _ready() -> void:
	for slot in InventoryComponent.SLOT_COUNT:
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 24)
		add_child(label)
		slot_labels.append(label)

	inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for slot in InventoryComponent.SLOT_COUNT:
		var item: Item = inventory.items[slot]
		var label: Label = slot_labels[slot]
		label.text = "[%d] %s" % [slot + 1, item.data.display_name if item else "-"]
		label.add_theme_color_override("font_color", EQUIPPED_COLOR if slot == inventory.equipped_slot and not inventory.override_item else NORMAL_COLOR)
