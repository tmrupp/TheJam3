extends Node

@onready var music_player1 = $"MusicPlayer1"
@onready var music_player2 = $"MusicPlayer2"

const LOOP_BEGIN_FADE_TIME:float = 85 #seconds
const LOOP_END_TIME:float = 95 #seconds
const LOOP_WINDOW:float = LOOP_END_TIME - LOOP_BEGIN_FADE_TIME #seconds
const FADE_OUT_VOLUME:float = -60 #dB

var player1_is_primary:bool = true

var stored_volume:float #set in _ready

func _ready():
	music_player1.play(0)
	stored_volume = music_player1.volume_db
	
	# this is to prevent what I accidentally did to myself where a divide by 0
	# made the sound incredibly loud
	if LOOP_WINDOW <= 0:
		assert(0)
	
func _process(delta):
	if player1_is_primary:
		control_fade_in_fade_out(music_player1, music_player2)
	else:
		control_fade_in_fade_out(music_player2, music_player1)

func control_fade_in_fade_out(music_player_A, music_player_B):
	var time_after_fade_time = music_player_A.get_playback_position() - LOOP_BEGIN_FADE_TIME
	if time_after_fade_time >= 0:
		music_player_B.playing = true
		
		#begin/continue fading player A out
		music_player_A.set_volume_db(lerp(stored_volume, FADE_OUT_VOLUME, time_after_fade_time / LOOP_WINDOW))
		
		#begin/continue fading player B in
		music_player_B.set_volume_db(lerp(FADE_OUT_VOLUME, stored_volume, time_after_fade_time / LOOP_WINDOW))
		
	if time_after_fade_time >= LOOP_WINDOW:
		music_player_A.stop()
		player1_is_primary = !player1_is_primary