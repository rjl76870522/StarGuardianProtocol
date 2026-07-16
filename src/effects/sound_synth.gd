class_name SoundSynth
extends RefCounted


static func tone(frequency: float, duration: float, volume: float = 0.22) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(1, int(duration * sample_rate))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var fade := 1.0 - float(index) / float(sample_count)
		var wave := sin(TAU * frequency * float(index) / float(sample_rate))
		var sample := int(clampf(wave * fade * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

