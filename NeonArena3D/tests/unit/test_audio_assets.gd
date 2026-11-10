extends TestCase
## Ses varlıkları gerçekten var ve yüklenebiliyor mu? Sound tablosuyla birebir eşleşmeli.

const SoundScript = preload("res://scripts/autoload/sound.gd")

func test_all_sfx_exist_and_load() -> void:
	for id in SoundScript.SFX:
		var path: String = SoundScript.AUDIO_DIR + str(SoundScript.SFX[id][0]) + ".wav"
		check(ResourceLoader.exists(path), "eksik ses dosyası: " + path)
		if ResourceLoader.exists(path):
			var stream = load(path)
			check(stream is AudioStreamWAV, "AudioStreamWAV değil: " + path)
			if stream is AudioStreamWAV:
				gt((stream as AudioStreamWAV).get_length(), 0.03, "ses çok kısa: " + id)

func test_music_tracks_exist() -> void:
	for id in SoundScript.MUSIC:
		var path: String = SoundScript.AUDIO_DIR + str(SoundScript.MUSIC[id][0]) + ".wav"
		check(ResourceLoader.exists(path), "eksik müzik: " + path)
		if ResourceLoader.exists(path):
			var stream = load(path)
			check(stream is AudioStreamWAV, "AudioStreamWAV değil: " + path)
			if stream is AudioStreamWAV:
				gt((stream as AudioStreamWAV).get_length(), 10.0, "müzik döngüsü çok kısa: " + id)

func test_sfx_buses_are_known() -> void:
	for id in SoundScript.SFX:
		check(str(SoundScript.SFX[id][4]) in ["SFX", "UI"], "bilinmeyen kanal: " + id)
