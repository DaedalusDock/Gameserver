/particles/rune
	icon = 'icons/effects/particles/generic.dmi'
	icon_state = list("dot"=4,"cross"=1,"curl"=1)

	width = 500
	height = 500
	count = 500

	spawning = 8
	lifespan = 3 SECONDS
	fade = 1 SECONDS

	scale = list(1.5, 1.5)
	grow = list(-0.04, -0.04)

	color = 0
	color_change = 0.05
	gradient = list("#4dffb5","#1f4d39")

	position = generator(GEN_CIRCLE, 42, 46, UNIFORM_RAND)
	velocity = generator(GEN_CIRCLE, 1, 1, NORMAL_RAND)
	drift = generator(GEN_VECTOR, list(0, 0.15), list(0, 0.2), NORMAL_RAND)
