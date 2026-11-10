class_name PlayerSpawnPoint extends Marker3D

# Where a player can start the round.
#
# Placed in TrenchBroom as an "info_player_spawn" entity (defined in
# trenchbroom/entities/info_player_spawn.tres). Building the map turns each one
# into one of these nodes, and the level spawns a player at each of them.
#
# In TrenchBroom the entity's box is exactly the size of a player, and this node
# sits at the centre of that box, which is also where the player's centre goes.
# So rest the box on the floor and the player will stand on the floor.
