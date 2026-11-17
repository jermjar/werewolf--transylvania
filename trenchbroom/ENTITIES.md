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

- **1 TrenchBroom unit = 0.025 m (40 units per metre).**
  Set by `inverse_scale_factor = 40` in `trenchbroom/werewolf_settings.tres`
  (func_godot divides map coordinates by it).
- The player's movement code uses the same units (`SOURCE_UNIT = 0.025` in
  `player.gd`), and the player has Source's proportions:

  | | Units | Metres |
  |---|---|---|
  | Standing height | 72 | 1.8 |
  | Crouched height | 36 | 0.9 |
  | Width (capsule radius 16) | 32 | 0.8 |
  | Eye height standing / crouched | 64 / 28 | 1.6 / 0.7 |
  | Run speed | 220 per second | 5.5 m/s |
  | Jump speed | 190 per second | 4.75 m/s |
  | Gravity | 600 per second² | 15 m/s² |

- **Why 40 and not 39.37?** A real Source unit is an inch (0.0254 m, 39.37 per
  metre). 40 is 1.6% off, which nobody notices, but it makes Source's numbers
  round in metres (72 units = 1.8 m instead of 1.8288 m). Units are what matter
  in TrenchBroom, and the map and the player use the same ones, so any
  measurement in Source units still works 1:1 in TrenchBroom.
  For jump heights and what the player can climb, see the next section.
- **Axes:** TrenchBroom is Z-up, Godot is Y-up. func_godot converts a
  TrenchBroom position `(x, y, z)` to Godot `(y, z, x) / 40`. You never need
  to do this yourself, but it explains why coordinates look shuffled in Godot.

### 2a. What the player can reach (measured)

Measured by running the real player scene in a test world with simulated
key presses: walking, jumping and crouch jumping at ledges of different heights.
These are for `jump_velocity = 190`. If you change it, measure again.
All heights are in TrenchBroom units above the floor the player starts on.

| What | Height (units) | Metres | Notes |
|---|---|---|---|
| Standing | **72** | 1.8 | |
| Crouching | **36** | 0.9 | |
| Eye level | **64** standing, **28** crouched | 1.6 / 0.7 | Use for sightlines and cover: a wall over 64 hides a standing player's view, over 28 a crouching one |
| Highest step you can **walk** onto | **4** | 0.1 | 6 already blocks you (5 not tested) |
| Feet at the top of a plain jump | 28.5 | 0.71 | Jumping straight up |
| Highest ledge for a **running plain jump** | **32** | 0.8 | 34 fails (33 not tested) |
| Feet at the top of a crouch jump | 64.5 | 1.61 | |
| Highest ledge for a **running crouch jump** | **68** | 1.7 | 70 fails (69 not tested) |

**Design to the safe numbers.** A running jump gets onto ledges a few units
higher than the feet ever go, because the capsule's rounded bottom scrambles
over the edge. That depends on run-up and timing. For routes every player
should manage, keep plain-jump ledges at **28 or lower** and crouch-jump ledges
at **64 or lower**. Treat 32 and 68 as the absolute limits.

**Crate sizes that work with this:**

| Box height | What players can do |
|---|---|
| ≤ 4 | Walk onto it |
| 16–28 | Plain jump onto it |
| 32 | Plain jump only with a good run-up |
| 36–64 | Crouch jump onto it. **64 is reliable** |
| 68 | Crouch jump only with a good run-up |
| 72+ | Can't be climbed alone. Needs a lower box next to it as a step |

Keep box tops at least 32 units deep so players have room to land.

For comparison, with the old TTT jump of 160: plain jump 20 (ledge 24),
crouch jump 56 (ledge 61).

**How to crouch jump:** press jump, *then* crouch. Holding crouch before
jumping gives a normal plain jump, because a crouch started on the ground
just lowers your head. Pressing both in the exact same physics tick (1/60 s)
also gives only a normal jump (`_update_crouch()` still sees the player on the
floor that tick).

#### Stairs and steps

The player **can't walk up steps taller than 4 units**, so normal Source-style
stairs (8-unit risers) block players completely. Godot's `CharacterBody3D`
has no step-up / stair-climbing property: checked in the Godot 4.7.2 source,
it only has `floor_max_angle` (steepest walkable slope), `floor_snap_length`
(stay glued to the ground going *down* slopes and steps), `floor_stop_on_slope`,
`floor_constant_speed`, `floor_block_on_wall`, `safe_margin` and the moving
platform settings. The Jolt physics module doesn't add one either. So for now:

- **Use ramps for stairs.** Build the steps for looks, then cover them with a
  sloped brush textured with **`clip`** on every face. `clip.png` is in
  `trenchbroom/textures`. func_godot leaves `clip` faces out of the visible mesh
  but keeps them in the collision (`clip_texture` in
  `werewolf_settings.tres`, applied in `geometry_generator.gd`), so players walk
  on an invisible ramp. This is the usual Source trick.
- Ramps up to `floor_max_angle` (Godot's default is 45°) are walkable. Not yet
  tested in-game with this player, so walk your first clip ramp to make sure.
- Real step-up (walking up stairs like in Source) needs movement code in
  `player.gd`. It's on the deferred list.

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
- **Dropdown values must not contain a colon (`:`).** The first version used
  full paths (`res://scenes/items/bat.tres`) as values, and TrenchBroom saved
  them in the `.map` as just `"re"`. Every item spawn came out empty and the
  game crashed when the round started. The cause is in TrenchBroom
  (`SmartChoiceEditor.cpp`, v2026.2): each dropdown entry is shown as
  `value : label`, and when you pick one, TrenchBroom keeps everything before
  the **first** `:`, minus one character. With `res://...` that's `re`.
  Plain paths like `assets/models/props/...` have no colon, so they're fine.
- **A harmless "Failed to load entity model" error when picking from a
  dropdown.** Picking an entry from the `prop_static` model dropdown logs
  something like *"Failed to load entity model 'wooden_crate_2_b':
  assets\models\props\Boxes\wooden_crate_2_b.glb : Boxes\wooden_crate_2_b not found"*.
  Also a TrenchBroom quirk: for a moment it sets the property to the whole
  `value : label` text and tries to load that as a model, then replaces it
  with the correct value. The saved `.map` has the right path and the model
  shows up. Safe to ignore.

### 3c. Registering them

`trenchbroom/werewolf_fgd.tres` (the FGD file resource) lists them under
**Entity Definitions**:

```
entity_definitions = [info_player_spawn.tres, info_item_spawn.tres, prop_static.tres]
```

Only entities in this list get exported to TrenchBroom and recognised when building.

### 3d. Exporting to TrenchBroom

`trenchbroom/trenchbroom_config.tres` → Inspector → **Export GameConfig**.
This writes three files to the folder set in func_godot's local config
(`D:/TrenchBroom/games/Werewolf`):

- `GameConfig.cfg`: game settings. `entity_scale` is `40`, so models (made in
  metres) show at the right size. `set_default_properties` is on, so a newly
  placed entity starts with its default values filled in (for example
  `item` = `bat`, or `model` = the crate).
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

### 3f. `prop_static`: models from asset packs

Brushes are the blocks you draw in TrenchBroom. **Models** are ready-made 3D
objects (crates, barrels, furniture) from an asset pack. TrenchBroom can't turn a
model into a brush, so models are placed as a point entity, `prop_static`, which
says "put this model here".

**What each file does:**

| File | Job |
|---|---|
| `assets/models/props/` | The models, copied from the Pizza Doggy packs and organized in subfolders (see the table below). Each model's texture is inside its `.glb`; Godot unpacks it into a `.png` next to it when importing. |
| `scripts/levels/prop_static.gd` | `PropStatic extends StaticBody3D`. During the build it loads the model named in the `model` property, adds it as a child, and wraps each mesh in a **convex** collision shape (like shrink wrap), so players can stand on it and can't walk through it. `@tool`, no `Log`, same reasons as `ItemSpawnPoint`. |
| `scripts/levels/prop_static_model_list.gd` | Fills the `model` **dropdown**. When the TrenchBroom config is exported, it finds every `.glb` in `assets/models/props/` and its subfolders and lists them as e.g. `Boxes/wooden_crate_2`. `@tool`, no `Log`. |
| `trenchbroom/entities/prop_static.tres` | The definition. Its `model` property is a dropdown (a Dictionary, like `info_item_spawn`'s `item`) that defaults to `Boxes/wooden_crate_2`. **Entity Extension Script** is set to `prop_static_model_list.gd`, a func_godot hook that runs during export and can change the definition before it's written. Its **display descriptor** is set to `model`, which exports as `model(model)` in the FGD: "draw the file named in this entity's `model` property". |

**Model paths are written without `res://`**, e.g.
`assets/models/props/Boxes/wooden_crate_2.glb`. TrenchBroom finds the file relative to
its game path, which is set to the project folder. The script adds `res://`
during the build. (Dropdown values containing a `:`, like `res://`, get cut off
in TrenchBroom, see 3b. Picking from the dropdown also logs a harmless
"Failed to load entity model" error, also explained in 3b.)

**The entity's origin is the bottom of the model** (the pack's models have their
origin at the base), so rest it on the floor like the spawns.

**Tested** by building a test map in memory:
- a crate with the model set built with the model and a convex collision shape;
- a test ray from above hit its top at 1.08 m;
- an entity with no `model` value used the default crate;
- after moving the crates into `Boxes/`, the exported FGD listed all 30 in
  the dropdown and a crate picked from `Boxes/` built with its texture and collision;
- a bad path printed an error naming the entity:
  *"entity_3_prop_static: no model at res://...glb. Check the model property of
  this prop_static in TrenchBroom."*

**Adding more models from the pack:**

1. Copy only the `.glb` you want (not the `.fbx` / `.obj` copies) into a
   subfolder of `assets/models/props/` (e.g. `Barrels/`). If a file with that
   name is already there (different packs reuse names), rename the new one.
2. Let Godot import it: open or focus the Godot editor.
3. Re-export: select `trenchbroom/trenchbroom_config.tres` and click
   **Export File**. This rebuilds the dropdown.
4. In TrenchBroom, reload the entity definitions (or restart TrenchBroom), place
   a `prop_static`, and pick the model from its **model** dropdown.

**Moving or renaming a model** changes its path, so any `prop_static` already
using it can't find it any more (the build prints the "no model at ..." error).
Move files inside the Godot editor's FileSystem dock so Godot keeps track of
them, re-export, then re-pick the model on those entities in TrenchBroom.

**Wooden crates in `assets/models/props/Boxes/`** (measured in Godot, in map
units, width × height × depth). All of them have their origin at the bottom.
"Climb" uses the reach table in 2a.

| Model file | Size (w × h × d) | Climb | From the pack |
|---|---|---|---|
| `wooden_crate_1_1.glb` | 29 × 7 × 20 | Plain jump | Mega Pack |
| `wooden_crate_1.glb` | 29 × 14 × 20 | Plain jump | Mega Pack |
| `wooden_crate_2_a.glb`, `_2_b` | 38 × 20 × 21 | Plain jump | Mega Pack II |
| `wooden_crate_ii_3.glb` | 27 × 26 × 19 | Plain jump | Mega Pack II (renamed from `wooden_crate_3`) |
| `wooden_crate_6.glb` | 30 × 30 × 30 | Plain jump with a run-up | Mega Pack |
| `wooden_crate_2_c.glb` | 38 × 34 × 31 | Crouch jump | Mega Pack II |
| `wooden_crate_ii_1.glb` | 59 × 37 × 46 | Crouch jump | Mega Pack II (renamed from `wooden_crate_1`) |
| `wooden_crate_hx_6.glb`, `_6_1`, `_6_2` | 56 × 40 × 56 | Crouch jump | Mega Pack II |
| `wooden_crate_3.glb`, `_3_1` | 43 × 43 × 43 | Crouch jump | Mega Pack |
| `wooden_crate_2.glb`, `_4`, `_5` | 44 × 43 × 43 | Crouch jump | Mega Pack |
| `wooden_crate_8.glb`, `_9` | 44 × 44 × 44 | Crouch jump | PSX Bunkers |
| `wooden_crate_hx_5.glb`, `_5_1`, `_5_2` | 60 × 58 × 60 | Crouch jump | Mega Pack II |
| `wooden_crate_hx_2.glb`, `_2_1`, `_2_2` | 56 × 72 × 56 | Too tall alone, needs a step | Mega Pack II |
| `wooden_crate_hx_3.glb`, `_3_1`, `_3_2` | 60 × 73 × 60 | Too tall alone, needs a step | Mega Pack II |
| `wooden_crate_hx_4.glb`, `_4_1`, `_4_2` | 76 × 74 × 76 | Too tall alone, needs a step | Mega Pack II |

Files listed together are the same size but different versions; compare them
in TrenchBroom to pick the look you want. Crates less than 32 units deep are
narrow to land on (see 2a). Mega Pack and Mega Pack II both had a
`wooden_crate_1` and a `wooden_crate_3`, so the Mega Pack II ones were
renamed `wooden_crate_ii_1` and `wooden_crate_ii_3`.

**The other model folders** (props only; the packs' weapons/items, decals,
masks, modular walls and buildings were left out). Pack category folders with
similar contents were merged:

| Folder | Models | Copied from |
|---|---|---|
| `Boxes/` | 30 | All the wooden crates (see above) |
| `Debris/` | 34 | Mega Pack II *Debris & Misc* |
| `Doors/` | 6 | Mega Pack II *Doors & Gates* |
| `Electronics/` | 43 | Mega Pack *Electronics & Misc* |
| `Furniture/` | 151 | Mega Pack *Furniture* |
| `Large Props/` | 80 | Mega Pack *Large Props* + Mega Pack II *Large Props & Machinery* |
| `Lighting/` | 54 | Mega Pack *Lighting* + Mega Pack II *Light Sources* (just the models; they don't give off light) |
| `Modular Props/` | 27 | Mega Pack II *Modular Props* |
| `Props/` | 117 | Mega Pack II *Props* |
| `Small Props/` | 60 | Mega Pack *Small Props* |

Wooden crates were skipped when copying, since they're already in `Boxes/`.

**Limits to know about:**
- **Convex collision fills in gaps.** It's perfect for crates and barrels, but a
  table or an arch becomes a solid block. Hollow models would need a different
  collision option, which can be added later.
- **Rotation** (fixed, see "Rotating props" below).
- **Static only.** These never move. Throwable props (with `InteractionComponent`
  and network sync) would be a separate `prop_physics` entity.

**Rotating props** (turning *and* tipping over):

- **Keys** (TrenchBroom defaults, 90° about the selection's center):
  **Alt+Left / Alt+Right** turn (yaw), **Alt+PgUp / Alt+PgDn** tip forward
  or back (pitch), **Alt+Up / Alt+Down** tip sideways (roll). With the
  rotate tool on, they use the tool's angle and center instead. Rotating
  about the center also moves the entity's origin, so check it still rests
  on the floor afterwards.
- **Why `prop_static` has an `angles` property:** TrenchBroom picks how to
  store a point entity's rotation from its definition
  (`EntityRotation.cpp`, v2026.2). With an `angles` property it stores all
  three (`"pitch yaw roll"`). Without one it falls back to `angle`, which is
  yaw only, so the prop could turn but never tip over. Props placed before
  `angles` existed still work. If one has an `angle` property, delete it so
  TrenchBroom switches to `angles`.
- **The 180° fix in `prop_static.gd`:** func_godot turns every point entity an
  extra 180° when building (`entity_assembler.gd`, the `angles.y += 180`
  line). That's right for marker entities like spawns, but it made models
  face the opposite way from TrenchBroom. `prop_static.gd` turns the model
  back by 180°.
- **Tested:** props built with `angles` of `0 0 0`, `0 90 0`, `90 0 0`,
  `0 0 90` and `30 45 60` ended up rotated exactly as TrenchBroom's
  formula draws them, with collision lined up. Without the 180° fix none of
  them matched.

### 3g. Map textures (for brushes)

Brush textures live in `trenchbroom/textures/` (`base_texture_dir` in
`werewolf_settings.tres`). TrenchBroom's texture browser shows one group per
subfolder. The old texture set was replaced with the Pizza Doggy PSX textures:

| Folder | Textures | Copied from |
|---|---|---|
| `PSX_I/` | 219 | *PSX Textures/256*: Color Maps + Normal Maps |
| `PSX_II/` | 232 | *PSX Textures II/Textures/256*: Color Maps + Normal Maps |
| (top level) | `clip`, `skip` | Kept from before. func_godot treats these names specially: `clip` is invisible but solid, `skip` faces are removed. |

- **Folder names have no spaces.** A face's texture name is written into the
  `.map` file as plain text separated by spaces (e.g. `PSX_I/brick_1`), so a
  space in a folder or file name would break the map.
- **Normal maps** sit next to their texture with `_normal` on the end (e.g.
  `brick_1_normal.png`). func_godot finds them automatically when building
  (`normal_map_pattern` = `%s_normal` in the map settings), so lighting picks up
  the bumps. TrenchBroom hides them from the texture browser (the `excludes`
  list in the game config).
- One stray file from the pack, `concrete_wall_21_ambient.png`, was left out:
  it isn't a texture or a normal map and would have shown up in TrenchBroom.
- **Size on the wall:** in TrenchBroom, one texture pixel covers one unit at
  scale 1. A 256 px texture is 256 units (6.4 m) wide at scale 1, 128 units
  (3.2 m) at scale 0.5, and 64 units (1.6 m) at scale 0.25. Set the scale per
  face in the face inspector, or change the default for new brushes with
  `default_uv_scale` in `trenchbroom_config.tres` (then re-export).
- **Adding textures:** copy the `.png` (and its `_normal.png`, if any) into a
  folder under `trenchbroom/textures/`, let Godot import it, and restart
  TrenchBroom.

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
7. For props: place a `prop_static`. It shows the crate by default. To use a
   different model, pick it from the **model** dropdown (see 3f).
8. Save (Ctrl+S).
9. In Godot: open `levels/trench_broom_test_map.tscn`, select the
   **FuncGodotMap** node, click **Build Map** in the Inspector, then save the scene.
10. Play. You should see green-box spawns become `entity_N_info_player_spawn`
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
| Everything is the wrong size | `inverse_scale_factor` isn't 40, or the map wasn't rebuilt after changing it |
| Player spawns inside the floor | The spawn box is sunk into the floor in TrenchBroom: lift it so its bottom touches the floor |
