class_name MotionProfile
extends RefCounted

static func for_actor(id: int) -> Dictionary:
	var profile := {"kind":"stride","breath":0.012,"cadence":8.0,"bob":2.0,"lean":0.025,"lunge":8.0,"hover":0.0,"weight":1.0}
	if id in [10,12,15,16,21,27,30,36,39,43,46,50]:
		profile.merge({"kind":"float","breath":0.008,"cadence":6.0,"bob":1.0,"lean":0.018,"lunge":5.0,"hover":3.0,"weight":0.5},true)
	elif id in [0,4,11,13,20,24,28,31,33,35,45,48,51,55,57,62]:
		profile.merge({"kind":"heavy","breath":0.009,"cadence":6.0,"bob":1.0,"lean":0.012,"lunge":6.0,"weight":1.6},true)
	elif id in [1,9,19,37]:
		profile.merge({"kind":"hop","breath":0.018,"cadence":10.0,"bob":4.8,"lean":0.035,"lunge":11.0,"weight":0.7},true)
	elif id in [22,25,44]:
		profile.merge({"kind":"slither","breath":0.014,"cadence":7.0,"bob":0.4,"lean":0.045,"lunge":10.0,"weight":0.8},true)
	return profile
