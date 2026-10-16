class_name ComicAudio
extends RefCounted
static var cache: Dictionary = {}

static func sound(kind: String) -> AudioStreamWAV:
	if cache.has(kind):
		return cache[kind]
	var duration := 0.42 if kind in ["gag_fizz","gag_dice"] else 0.24
	var count := int(22050*duration)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var low := 0.0
	for i in count:
		var t := float(i)/22050
		var x := float(i)/count
		var noise_value := rng.randf_range(-1,1)
		low = lerpf(low,noise_value,0.18)
		var value := 0.0
		match kind:
			"gag_magnet":
				var pulse := maxf(0,sin(t*TAU*5))
				value=(sin(TAU*260*t)+sin(TAU*390*t)*0.45)*pulse*0.35
			"gag_fizz", "gag_soda":
				value=(noise_value-low)*pow(1-x,1.5)*0.62
			"gag_dice":
				var clack := exp(-fmod(t,0.065)*90)
				value=(noise_value*0.5+sin(TAU*960*t)*0.18)*clack*(1-x)
			"gag_delivery":
				value=(sin(TAU*1100*t)+sin(TAU*2100*t)*0.4)*exp(-x*7)*0.5
			"gag_romance", "gag_letters":
				value=(sin(TAU*660*t)+sin(TAU*990*t)*0.4)*exp(-x*6)*0.4
			"gag_land":
				value=(sin(TAU*(150-55*x)*t)*0.7+low*0.8)*exp(-x*7)
			"gag_house", "gag_gavel":
				value=low*sin(x*PI)*0.55
			_:
				value=(noise_value-low)*sin(x*PI)*0.25
		value *= minf(1,x*50)
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*10000))
	var result := AudioStreamWAV.new()
	result.format=AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate=22050
	result.data=bytes
	cache[kind]=result
	return result
