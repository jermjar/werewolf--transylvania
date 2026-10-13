class_name Chat extends Control

# In-game text chat. Enter opens it, Enter sends, Esc cancels.
# - Living players talk to everyone.
# - Spectators (dead players, and people who joined late) only talk to each
#   other, but they can read everyone.
# - Once the round has ended, everyone talks freely.
#
# Every message goes through the host, which decides who gets it (see
# _can_read()). Machines that shouldn't read a message never receive it.

const MAX_LENGTH: int = 150
const MAX_RECENT: int = 6 # How many recent messages are shown while not typing
const RECENT_TIME: float = 8.0 # Seconds a new message stays on screen while not typing
const FADE_TIME: float = 1.0
const SPECTATOR_COLOR: Color = Color(0.6, 0.6, 0.6)

# True while we're typing. Movement keys are also letters, so the player
# ignores them while this is true (see Player._physics_process()).
static var is_typing: bool = false

@onready var history: RichTextLabel = %History # Every message, shown while typing
@onready var recent: VBoxContainer = %Recent # The last few messages, shown while not typing
@onready var input: LineEdit = %Input

func _ready() -> void:
	Log.debug("Chat._ready()")
	history.hide()
	input.hide()
	input.max_length = MAX_LENGTH
	input.text_submitted.connect(_on_text_submitted)
	input.editing_toggled.connect(_on_editing_toggled)

func _exit_tree() -> void:
	Log.debug("Chat._exit_tree()")
	is_typing = false # The level can unload while we're typing

func _unhandled_input(event: InputEvent) -> void:
	if not is_typing and event.is_action_pressed("chat"):
		get_viewport().set_input_as_handled()
		_open()

func _open() -> void:
	Log.debug("Chat._open()")
	is_typing = true
	recent.hide()
	history.show()
	input.show()
	input.edit() # Focuses the box and starts typing

# The LineEdit stops editing after Enter sends, on Esc, or if it loses focus.
# All of those close the chat.
func _on_editing_toggled(editing: bool) -> void:
	Log.debug("Chat._on_editing_toggled()")
	if editing: return
	is_typing = false
	input.clear()
	# Otherwise the box keeps focus, and the next Enter would start typing in it without opening the chat
	input.release_focus()
	input.hide()
	history.hide()
	recent.show()

func _on_text_submitted(text: String) -> void:
	Log.debug("Chat._on_text_submitted()")
	if not text.strip_edges().is_empty():
		_send_message.rpc_id(Networking.HOST_ID, text)

# Player -> Host
@rpc("any_peer", "call_local", "reliable")
func _send_message(text: String) -> void:
	Log.debug("Chat._send_message()")
	if not multiplayer.is_server(): return

	# The sender is whoever sent this RPC, so nobody can pretend to be someone else
	var sender_id: int = multiplayer.get_remote_sender_id()
	text = text.strip_edges().left(MAX_LENGTH)
	if text.is_empty(): return

	var from_spectator: bool = not RoundManager.instance.is_alive(sender_id)
	var everyone: Array[int] = [multiplayer.get_unique_id()]
	for peer_id in multiplayer.get_peers():
		everyone.append(peer_id)
	for reader_id in everyone:
		if _can_read(sender_id, reader_id):
			_show_message.rpc_id(reader_id, sender_id, text, from_spectator)

# Host only - the one place that decides who reads a message
func _can_read(sender_id: int, reader_id: int) -> bool:
	Log.debug("Chat._can_read()")
	var round_manager: RoundManager = RoundManager.instance
	if round_manager.phase == RoundManager.Phase.ENDED: return true # The round is over, everyone talks freely
	if round_manager.is_alive(sender_id): return true # Living players talk to everyone (could become proximity later)
	return not round_manager.is_alive(reader_id) # Spectators only talk to other spectators

# Host -> Each reader
@rpc("call_local", "reliable")
func _show_message(sender_id: int, text: String, from_spectator: bool) -> void:
	Log.debug("Chat._show_message()")
	var line: String = "%s%s: %s" % ["[DEAD] " if from_spectator else "", Networking.get_display_name(sender_id), text]
	var color: Color = SPECTATOR_COLOR if from_spectator else Color.WHITE

	# add_text() shows the text exactly as typed, so players can't sneak in formatting
	history.push_color(color)
	history.add_text(line)
	history.pop()
	history.newline()

	var label: Label = Label.new()
	label.text = line
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recent.add_child(label)
	if recent.get_child_count() > MAX_RECENT:
		recent.get_child(0).queue_free()

	# Stays for a while, then fades out and is removed
	var tween: Tween = label.create_tween()
	tween.tween_interval(RECENT_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)
