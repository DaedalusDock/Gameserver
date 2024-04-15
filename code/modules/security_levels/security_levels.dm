/proc/set_security_level(level)
	switch(level)
		if("green")
			level = SEC_LEVEL_GREEN
		if("blue")
			level = SEC_LEVEL_BLUE
		if("red")
			level = SEC_LEVEL_RED
		if("delta")
			level = SEC_LEVEL_DELTA

	//Will not be announced if you try to set to the same level as it already is
	if(level >= SEC_LEVEL_GREEN && level <= SEC_LEVEL_DELTA && level != SSsecurity_level.current_level)
		switch(level)
			if(SEC_LEVEL_GREEN)
				priority_announce(CONFIG_GET(string/alert_green), sub_title = "Security level lowered to green.", do_not_modify = TRUE)

			if(SEC_LEVEL_BLUE)
				if(SSsecurity_level.current_level < SEC_LEVEL_BLUE)
					priority_announce(CONFIG_GET(string/alert_blue_upto), sub_title = "Security level elevated to blue.", do_not_modify = TRUE, sound_type = ANNOUNCER_ALERT)
				else
					priority_announce(CONFIG_GET(string/alert_blue_downto), sub_title = "Security level lowered to blue.", do_not_modify = TRUE, sound_type = ANNOUNCER_ALERT)

			if(SEC_LEVEL_RED)
				if(SSsecurity_level.current_level < SEC_LEVEL_RED)
					priority_announce(CONFIG_GET(string/alert_red_upto), sub_title = "Security level elevated to red.", do_not_modify = TRUE, sound_type = ANNOUNCER_ALERT)
				else
					priority_announce(CONFIG_GET(string/alert_red_upto), sub_title = "Security level lowered to red.", do_not_modify = TRUE, sound_type = ANNOUNCER_ALERT)

			if(SEC_LEVEL_DELTA)
				priority_announce(CONFIG_GET(string/alert_delta), sub_title = "Security level elevated to delta.", do_not_modify = TRUE, sound_type = ANNOUNCER_ALERT)

		SSsecurity_level.set_level(level)

/proc/get_security_level()
	switch(SSsecurity_level.current_level)
		if(SEC_LEVEL_GREEN)
			return "green"
		if(SEC_LEVEL_BLUE)
			return "blue"
		if(SEC_LEVEL_RED)
			return "red"
		if(SEC_LEVEL_DELTA)
			return "delta"

/proc/num2seclevel(num)
	switch(num)
		if(SEC_LEVEL_GREEN)
			return "green"
		if(SEC_LEVEL_BLUE)
			return "blue"
		if(SEC_LEVEL_RED)
			return "red"
		if(SEC_LEVEL_DELTA)
			return "delta"

/proc/seclevel2num(seclevel)
	switch( lowertext(seclevel) )
		if("green")
			return SEC_LEVEL_GREEN
		if("blue")
			return SEC_LEVEL_BLUE
		if("red")
			return SEC_LEVEL_RED
		if("delta")
			return SEC_LEVEL_DELTA
