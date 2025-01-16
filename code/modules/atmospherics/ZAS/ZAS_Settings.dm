#define SETTING_DEF(var_name, default_value, name, description, category) \
	var/##var_name = default_value;\
	var/name_##var_name = name;\
	var/desc_##var_name = description;\
	var/cat_##var_name = category;\

/datum/zas_controller
	var/datum/pl_control/plc = new

	//* Fire Settings *//
	SETTING_DEF(fire_consumption_rate, 0.25, "Air Consumption Ratio", "Ratio of air removed and combusted per tick.", "Fire")
	SETTING_DEF(fire_firelevel_multiplier, 25, "Firelevel Constant", "Multiplied by the equation for firelevel, affects mainly the extingiushing of fires.", "Fire")
	/// Note that this parameter and the phoron heat capacity have a significant impact on TTV yield.
	/// Value is in J/mol.
	SETTING_DEF(fire_fuel_energy_release, 866000, "Fuel energy release", "The energy in joule released when burning one mol of a burnable substance", "Fire")

	//* Airflow Settings *//
	SETTING_DEF(airflow_lightest_pressure, 20, "Small Movement Threshold %", "Percent of 1 Atm. at which items with the small weight classes will move.", "Airflow")
	SETTING_DEF(airflow_light_pressure, 35, "Medium Movement Threshold %", "Percent of 1 Atm. at which items with the medium weight classes will move.", "Airflow")
	SETTING_DEF(airflow_medium_pressure, 50, "Heavy Movement Threshold %", "Percent of 1 Atm. at which items with the largest weight classes will move.", "Airflow")
	SETTING_DEF(airflow_mob_pressure, 65, "Mob Movement Threshold %", "Percent of 1 Atm. at which mobs will move.", "Airflow")
	SETTING_DEF(airflow_dense_pressure, 85, "Dense Movement Threshold %", "Percent of 1 Atm. at which dense objs can move.", "Airflow")
	SETTING_DEF(airflow_speed_decay, 1.5, "Speed Decay Rate", "Speed removed from an airborne object per tick.", "Airflow")
	SETTING_DEF(airflow_speed_for_density, 5, "Force Density Speed", "The speed value required to be able to impact objects during airflow, if not normally dense.", "Airflow")
	SETTING_DEF(airflow_retrigger_delay, 0 SECONDS, "Airflow Retrigger Grace", "After being affected by spacewind, wait this long before affecting again.", "Airflow")
	SETTING_DEF(airflow_mob_slowdown, 1, "Mob Slowdown", "Additive slowdown applied to mobs affected by spacewind.", "Airflow")

	SETTING_DEF(airflow_stun_pressure, 60, "Mob Stunning Threshold %", "Percent of 1 Atm. at which mobs will be stunned by airflow.", "Airflow Impact")
	SETTING_DEF(airflow_stun, 1 SECOND, "Stun Duration", "How long a mob is stunned when hit by an airborne object.", "Airflow Impact")
	SETTING_DEF(airflow_stun_cooldown, 1 SECOND, "Stun Cooldown", "How long, in tenths of a second, to wait before stunning them again.", "Airflow Impact")
	SETTING_DEF(airflow_damage, 3, "Damage", "Damage from airflow impacts.", "Airflow Impact")


	//* Bomb Settings *//
	SETTING_DEF(maxex_devastation_range, 4, "Devastation Cap", "By default, 1/4th of fire range.", "Bomb")
	SETTING_DEF(maxex_heavy_range, 8, "Heavy Cap", "By default, 1/2 of light range.", "Bomb")
	SETTING_DEF(maxex_light_range, 18, "Light Cap", "By default, this is the baseline for other explosion values.", "Bomb")
	SETTING_DEF(maxex_fire_range, 16, "Fire Cap", "By default, equal to light range.", "Bomb")
	SETTING_DEF(maxex_flash_range, 20, "Flash Cap", "By default, 5/4ths of light range.", "Bomb")

	/// See /proc/compile_vars()
	var/list/edittable_vars = list()

/datum/zas_controller/New()
	compile_vars()

// Reject all VV edits, use the panel.
/datum/zas_controller/vv_edit_var(var_name, var_value)
	return FALSE

/datum/zas_controller/proc/set_bomb_cap(val)
	if(!isnum(val))
		CRASH("Non-number given to set_bomb_cap.")

	maxex_devastation_range = val/4
	maxex_heavy_range = val/2
	maxex_light_range = val
	maxex_fire_range = val
	maxex_flash_range = val*1.2

/datum/zas_controller/proc/compile_vars()
	edittable_vars += nameof(fire_consumption_rate)
	edittable_vars += nameof(fire_firelevel_multiplier)
	edittable_vars += nameof(fire_fuel_energy_release)

	edittable_vars += nameof(airflow_lightest_pressure)
	edittable_vars += nameof(airflow_light_pressure)
	edittable_vars += nameof(airflow_medium_pressure)
	edittable_vars += nameof(airflow_mob_pressure)
	edittable_vars += nameof(airflow_dense_pressure)
	edittable_vars += nameof(airflow_speed_decay)
	edittable_vars += nameof(airflow_speed_for_density)
	edittable_vars += nameof(airflow_retrigger_delay)
	edittable_vars += nameof(airflow_mob_slowdown)

	edittable_vars += nameof(airflow_stun_pressure)
	edittable_vars += nameof(airflow_stun)
	edittable_vars += nameof(airflow_stun_cooldown)
	edittable_vars += nameof(airflow_damage)

	edittable_vars += nameof(maxex_devastation_range)
	edittable_vars += nameof(maxex_heavy_range)
	edittable_vars += nameof(maxex_light_range)
	edittable_vars += nameof(maxex_fire_range)
	edittable_vars += nameof(maxex_flash_range)

/datum/zas_controller/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ZasSettings")
		ui.open()

/datum/zas_controller/ui_state(mob/user)
	return GLOB.admin_state

/datum/zas_controller/ui_data(mob/user)
	var/list/data = list()
	var/list/settings = list()
	var/list/categories = list()
	data["settings"] = settings
	data["categories"] = categories

	for(var/var_name in edittable_vars)
		var/var_category = vars["cat_[var_name]"]
		settings[var_name] = list(
			"value" = vars[var_name],
			"name" = vars["name_[var_name]"],
			"desc" = vars["desc_[var_name]"],
			"category" = var_category,
		)

		categories |= var_category

	return data


/datum/zas_controller/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("change_var")
			var/var_name = params["var_name"]
			var/var_human_name = params["var_human_name"]
			if(!(var_name in edittable_vars))
				return TRUE

			var/new_val = tgui_input_number(ui.user, "Change [var_human_name]", "ZAS Settings", vars[var_name], round_value = FALSE)
			if(isnull(new_val))
				return

			log_admin("[key_name_admin(ui.user)] updated ZAS setting [var_human_name]: [vars[var_name]] -> [new_val]")
			message_admins("[key_name_admin(ui.user)] updated ZAS setting [var_human_name]: [vars[var_name]] -> [new_val]")
			vars[var_name] = new_val
			return TRUE
