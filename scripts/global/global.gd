extends Node

enum MultiplayerBackend { ENET, STEAM }
# NOTE - Change this depending on whether or not you want to test locally
#        Also customize run instances under Debug at the top, and add "server"
#        feature to the first run instance.
var backend: MultiplayerBackend = MultiplayerBackend.STEAM
