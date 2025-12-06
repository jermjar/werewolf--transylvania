extends CanvasLayer

@onready var button_container: VBoxContainer = $Button_VBoxContainer
@onready var join_lobby_button: Button = %JoinLobby
@onready var create_lobby_button: Button = %CreateLobby
@onready var options_button: Button = %Options
@onready var quit_button: Button = %Quit

func _ready() -> void:
	create_lobby_button.button_up.connect(_on_create_lobby_button_up)
	join_lobby_button.button_up.connect(_on_join_lobby_button_up)
	quit_button.button_up.connect(_on_quit_button_up)

func _on_create_lobby_button_up() -> void:
	pass

func _on_join_lobby_button_up() -> void:
	pass

func _on_quit_button_up() -> void:
	pass

## Steam related stuff that I'm commenting out for now
#@onready var button_container: VBoxContainer = $Button_VBoxContainer
#@onready var join_lobby_button: Button = %JoinLobby
#@onready var create_lobby_button: Button = %CreateLobby
#@onready var options_button: Button = %Options
#@onready var quit_button: Button = %Quit
#
#@onready var scroll_container: ScrollContainer = $Lobby_ScrollContainer
#
#func _ready() -> void:
	#join_lobby_button.button_up.connect(_on_join_lobby_button_up)
	#create_lobby_button.button_up.connect(_on_create_lobby_button_up)
	#options_button.button_up.connect(_on_options_button_up)
	#quit_button.button_up.connect(_on_quit_button_up)
	#Steam.lobby_match_list.connect(_on_lobby_match_list)
#
#func _on_join_lobby_button_up() -> void:
	#button_container.visible = false
	#scroll_container.visible = true
	#
	## Set distance to worldwide
	#Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	#print("Requesting a lobby list")
	#
	## Triggers _on_lobby_match_list()
	#Steam.requestLobbyList()
#
#func _on_lobby_match_list(these_lobbies: Array) -> void:
	#for this_lobby in these_lobbies:
		## Pull lobby data from Steam
		#var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		#var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")
		#var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
		#
		#var lobby_button: Button = Button.new()
		#lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [this_lobby, lobby_name, lobby_mode, lobby_num_members])
		#lobby_button.set_size(Vector2(800, 50))
		#lobby_button.set_name("lobby_%s" % this_lobby)
		#lobby_button.pressed.connect(Steamworks.join_lobby.bind(this_lobby))
		#
		#scroll_container.get_child(0).add_child(lobby_button)
#
#func _on_create_lobby_button_up() -> void:
	#Steamworks.create_lobby()
#
#func _on_options_button_up() -> void:
	#pass
#
#func _on_quit_button_up() -> void:
	#get_tree().quit()
