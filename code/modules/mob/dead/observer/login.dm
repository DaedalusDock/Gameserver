/mob/dead/observer/Login()
	. = ..()
	if(!. || !client)
		return FALSE

	if(isAdminGhostAI(src))
		has_unlimited_silicon_privilege = TRUE

	if(client.prefs.unlock_content)
		ghost_orbit = client.prefs.read_preference(/datum/preference/choiced/ghost_orbit)

	var/turf/T = get_turf(src)
	if (isturf(T))
		update_z(T.z)

	client.set_right_click_menu_mode(FALSE)
	lighting_alpha = default_lighting_alpha()
	update_sight()
	update_monochrome()
