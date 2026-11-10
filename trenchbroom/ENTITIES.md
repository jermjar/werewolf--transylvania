# TrenchBroom Entities: How They Work and How to Make New Ones

This explains how the `info_player_spawn` and `info_item_spawn` entities were
made, so you can follow the same steps for any new entity (props, triggers,
doors, ...).

---

## 1. The big picture

An **entity** is anything in a `.map` that isn't plain world geometry. In
TrenchBroom there are two kinds:

| Kind | What it is | Example |
|---|---|---|
| **Point entity** | A single point with a box drawn around it | spawn points, lights, item spawns |
| **Brush entity** | Brushes you've grouped and given a class | doors, trigger zones, non-solid detail |

The pipeline has three programs passing information along:

```
Godot (entity definition .tres files)
   │  "Export GameConfig" writes Werewolf.fgd + GameConfig.cfg
   ▼
TrenchBroom (reads the FGD: shows your entities, lets you place them)
   │  saving writes the entities into test_map.map as text
   ▼
Godot (FuncGodotMap "Build Map" reads the .map and creates a node for each entity)
```

An entity in a `.map` file is just text, a class name plus key/value properties:

```
{
"classname" "info_item_spawn"
"origin" "0 0 16"
"item" "flashlight"
}
```

The **FGD file** (`Werewolf.fgd`) tells TrenchBroom which class names exist,
what properties they have, and how to draw them. func_godot writes it for you
from the definition resources, so you never edit the FGD by hand.

---

## 2. Units and scale (read this first)

- **1 TrenchBroom unit = 1 Source unit = 1 inch = 0.0254 m.**
  Set by `inverse_scale_factor = 39.37` in `trenchbroom/werewolf_settings.tres`
  (func_godot divides map coordinates by it).
- The player's movement code uses the same units (`SOURCE_UNIT` in `player.gd`),
  and the player is a Source-sized player:

  | | Units | Metres |
  |---|---|---|
  | Standing height | 72 | 1.83 |
  | Crouched height | 36 | 0.91 |
  | Width (capsule radius 16) | 32 | 0.81 |
  | Eye height standing / crouched | 64 / 28 | 1.63 / 0.71 |
  | Normal jump (feet) | ~21 | ~0.54 |
  | Crouch jump (feet) | ~57 | ~1.45 |

  So any measurement you take from a Source map works 1:1 in TrenchBroom.
- **Axes:** TrenchBroom is Z-up, Godot is Y-up. func_godot converts a
  TrenchBroom position `(x, y, z)` to Godot `(y, z, x) / 39.37`. You never need
  to do this yourself, but it explains why coordinates look shuffled in Godot.

---

## 3. What was made, file by file

### 3a. The node scripts (what each entity becomes in Godot)

| File | Class | Notes |
|---|---|---|
| `scripts/levels/player_spawn_point.gd` | `PlayerSpawnPoint extends Marker3D` | New. No code needed, the class only exists so the level can find these nodes with `node is PlayerSpawnPoint`. |
| `scripts/items/item_spawn_point.gd` | `ItemSpawnPoint extends Marker3D` | Already existed. Gained `@tool` and `_func_godot_apply_properties()`. |

`ItemSpawnPoint` needs to know *which* item to spawn, and that comes from
TrenchBroom's `item` property. func_godot hands an entity's properties to its
node during the build by calling this function, if the node has it:

```gdscript
func _func_godot_apply_properties(properties: Dictionary) -> void:
	var item_path: String = "res://scenes/items/%s.tres" % properties["item"]
	item = load(item_path)
	if item == null:
		push_error("%s: no item at %s. Pick an item for this info_item_spawn in TrenchBroom." % [name, item_path])
```

The `item` property holds just the item's file name (`bat`, `flashlight`), and
the function turns it into the full path. If no file has that name, the build
prints an error naming the entity in Godot's **Output** panel, so a bad value
shows up when you build, not as a crash when the round starts.

Two important details:

1. **`@tool` is required.** The map is built *inside the Godot editor*, and the
   editor only runs functions from `@tool` scripts. Without `@tool`, func_godot
   can't see the function and `item` stays empty.
2. **No `Log.debug()` in that function.** It runs in the editor, where the
   `Log` autoload doesn't exist, so calling it would error. (That's the only
   exception to the "every function starts with Log.debug" rule.)

The value is saved into the built scene (`item = ExtResource(...)`), so at
runtime nothing is read from the `.map` anymore.

### 3b. The entity definitions (what TrenchBroom shows)

Folder: `trenchbroom/entities/`. Each file is a `FuncGodotFGDPointClass`
resource. You can open and edit them in Godot's Inspector.

**`info_player_spawn.tres`**

| Field | Value | Why |
|---|---|---|
| `classname` | `info_player_spawn` | The name written in the `.map`. The `info_` prefix is the Quake/Source convention for invisible marker entities. |
| `description` | text | Shown in TrenchBroom's entity browser and inspector. |
| `meta_properties` → `size` | `AABB(-16, -16, -36, 16, 16, 36)` | The box TrenchBroom draws. func_godot writes **position as the box's min corner and size as its max corner**, so this means "from -16,-16,-36 to 16,16,36": exactly a 32×32×72 player, with the entity's origin in the middle. |
| `meta_properties` → `color` | green | Box colour in TrenchBroom. |
| `node_class` | `Marker3D` | The Godot node type to create. |
| `script_class` | `player_spawn_point.gd` | Attached to that node. Its base type must match `node_class`. |

Because the origin is the middle of a player-sized box, and the player's origin
is also the middle of its capsule, **rest the box on the floor in TrenchBroom
and the player stands on the floor.** No height offset code is needed.

**`info_item_spawn.tres`** has the same fields plus a property:

```
class_properties = {
    "item": {                      # A Dictionary = a dropdown ("choices")
        "Bat": "bat",              # label shown : value saved in the .map
        "Flashlight": "flashlight"
    }
}
class_property_descriptions = {
    "item": ["Item", "bat"]        # [label, default value]
}
```

- The **type of the value** in `class_properties` decides the property type in
  TrenchBroom: `int` → integer, `float` → float, `String` → text, `bool` →
  Yes/No, `Color` → colour picker, `Dictionary` → dropdown, `Vector3` →
  "x y z" text.
- For a dropdown, the description can be `[label, default]`. The default is
  what TrenchBroom shows when you haven't picked anything.
- If an entity in the `.map` has **no** value for a property, func_godot uses
  the first dropdown option (here: Bat). Tested: it works.
- **Each value must be an item's file name in `scenes/items/` without `.tres`.**
  To add a knife, you'd add `"Knife": "knife"` for `scenes/items/knife.tres`.
  If you rename or move an item's file, update the dropdown and re-pick the
  item on entities you've already placed.
- **Keep dropdown values simple: letters, numbers and underscores.** The first
  version used full paths (`res://scenes/items/bat.tres`) as values, and
  TrenchBroom saved them in the `.map` as just `"re"`. Every item spawn came
  out empty and the game crashed when the round started.

### 3c. Registering them

`trenchbroom/werewolf_fgd.tres` (the FGD file resource) lists them under
**Entity Definitions**:

```
entity_definitions = [info_player_spawn.tres, info_item_spawn.tres]
```

Only entities in this list get exported to TrenchBroom and recognised when building.

### 3d. Exporting to TrenchBroom

`trenchbroom/trenchbroom_config.tres` → Inspector → **Export GameConfig**.
This writes three files to the folder set in func_godot's local config
(`D:/TrenchBroom/games/Werewolf`):

- `GameConfig.cfg`: game settings (`entity_scale` is now `39.37` to match)
- `Werewolf.fgd`: all entity definitions
- `icon.png`

**Restart TrenchBroom after exporting** so it reads the new definitions.

The export has already been run for these two entities. This is what it wrote:

```
@PointClass color(51 204 51) size(-16 -16 -36, 16 16 36) = info_player_spawn : "Where a player can start the round. ..." []
@PointClass color(255 153 26) size(-8 -8 -8, 8 8 8) = info_item_spawn : "Where an item starts the round. ..."
[
	item(choices) : "Item" : "bat" =
	[
		"bat" : "Bat"
		"flashlight" : "Flashlight"
	]
]
```

### 3e. Using them in the game

The hand-placed `SpawnPoints` and `ItemSpawnPoints` marker nodes were removed
from `test_level.tscn`. Instead, both scripts search the map for the generated nodes:

- `test_level.gd`: new `@export var map` (set to `Geometry/TrenchBroomTestMap`)
  and `_get_player_spawn_points()`, which collects every `PlayerSpawnPoint` in it.
  If there are none, it logs an error telling you to place some.
- `item_spawner.gd`: `@export var spawn_points` became `@export var map`, and
  `spawn_level_items()` spawns an item at every `ItemSpawnPoint` in it.

They search the whole map recursively (`find_children`), so entities still work
if you put them inside TrenchBroom groups or layers.

---

## 4. Everyday workflow: placing entities

1. Open TrenchBroom, then open `trenchbroom/maps/test_map.map`.
2. Open the **Entity browser** (right panel, *Entity* tab) and find
   `info_player_spawn` / `info_item_spawn` (use its filter box to search).
3. **Drag** one into the 3D view. It snaps to the grid.
4. Raise or lower it so the **bottom of the box touches the floor**
   (for player spawns, a 72-unit-tall box with its bottom face on the floor).
5. For item spawns: select it, and in the **Entity inspector** (top right) set
   **item** from the dropdown.
6. Place **8 player spawns** (one per player). With fewer, players get stacked
   on the same spot.
7. Save (Ctrl+S).
8. In Godot: open `levels/trench_broom_test_map.tscn`, select the
   **FuncGodotMap** node, click **Build Map** in the Inspector, then save the scene.
9. Play. You should see green-box spawns become `entity_N_info_player_spawn`
   nodes under FuncGodotMap.

> ⚠️ **Rebuilding replaces everything under FuncGodotMap.** Never edit the
> generated nodes in Godot (moving a spawn, changing its item). Make all
> changes in TrenchBroom and rebuild, or they'll be lost on the next build.

---

## 5. Recipe: adding a new entity type

Example: a `prop_physics` entity that places a throwable prop scene.

1. **Write the node side.** Either:
   - a **script** (`node_class` = its base type, `script_class` = the script), or
   - a **scene**: set `scene_file` on the definition instead. func_godot
     instantiates the scene, and `node_class`/`script_class` are ignored.
2. **Need properties from TrenchBroom?** Add `@tool` and
   `_func_godot_apply_properties(properties)` to the root script, and don't use
   `Log` in it. (Alternative: turn on **auto_apply_to_matching_node_properties**
   on the definition, and properties whose name and type match an `@export`
   on the node are copied automatically, with no function needed.)
3. **Create the definition:** FileSystem → right-click `trenchbroom/entities/`
   → *New Resource* → `FuncGodotFGDPointClass` (or `FuncGodotFGDSolidClass` for
   brush entities). Fill in classname, description, `meta_properties`
   (size/colour), `class_properties`, and `node_class`/`script_class` or `scene_file`.
4. **Register it:** add it to `entity_definitions` in `werewolf_fgd.tres`.
5. **Export:** `trenchbroom_config.tres` → *Export GameConfig*. Restart TrenchBroom.
6. **Use it in code** the same way the spawns do: search the level's map for
   the node class.
7. **Networked props need care:** level props with a `MultiplayerSynchronizer`
   must start with `public_visibility = false` (see `test_level.gd`'s
   `game_loaded()`), so put that in the prop scene itself. Generated nodes have
   the same path on every machine because everyone loads the same saved scene.

### Useful definition fields (all in the Inspector)

| Field | Use |
|---|---|
| `base_classes` | Inherit properties from a `FuncGodotFGDBaseClass` (shared properties) |
| `node_groups` | Add generated nodes to Godot groups |
| `name_property` | Name the node from a property (e.g. `targetname`) instead of `entity_N_classname` |
| `apply_rotation_on_map_build` | Uses the `angle` / `angles` property for rotation (on by default) |
| `display_descriptors` | Show a model instead of a box in TrenchBroom |
| `func_godot_internal` | Use only in builds, hide from TrenchBroom |

---

## 6. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Entity missing from TrenchBroom's browser | Not in `entity_definitions`, not exported, or TrenchBroom not restarted |
| Entity shows as a plain grey box with a warning | Same as above: the classname in the `.map` isn't in the FGD |
| "no item at res://scenes/items/....tres" in Output when building | The entity's `item` value isn't an item file name. Re-pick it from the dropdown in TrenchBroom, save, rebuild |
| Item spawn has no item / crash on `resource_path` at round start | Same as above (check Output for the build error), or the item script lost `@tool`, or the map wasn't rebuilt after placing |
| "The map has no player spawns" error | No `info_player_spawn` in the map, or the map wasn't rebuilt |
| Everything is the wrong size | `inverse_scale_factor` isn't 39.37, or the map wasn't rebuilt after changing it |
| Player spawns inside the floor | The spawn box is sunk into the floor in TrenchBroom: lift it so its bottom touches the floor |
