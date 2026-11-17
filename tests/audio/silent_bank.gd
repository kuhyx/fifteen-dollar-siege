extends RefCounted
## Gives the director a silent stand-in for every sound file the bank could not
## load, so the voice tests run in a fresh clone or worktree with no rendered
## audio (no ./install.sh). These tests judge the voices, never the sound.
## Each file key gets its own stream: a test that checks which file a voice
## plays still tells the files apart. Files that did load are left alone.
## The music players took their streams at boot and stay as they are.

const RATE := 44100
## One second: a stand-in voice keeps playing as a rendered one would.
const FRAMES := RATE


static func fill(director: AudioDirector) -> void:
	for file in AudioCues.files():
		if director.bank.stream(file) == null:
			director.bank.streams[file] = _silence()


static func _silence() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	var data := PackedByteArray()
	data.resize(FRAMES * 2)
	data.fill(0)
	wav.data = data
	return wav
