extends AudioStreamPlayer

# Plays the ambient bed on a loop. Looping is set here rather than in the
# import settings, so it does not depend on how the file was imported.

func _ready() -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	play()
