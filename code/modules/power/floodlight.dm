
/obj/structure/floodlight_frame
	name = "floodlight frame"
	desc = "A bare metal frame looking vaguely like a floodlight. Requires wrenching down."
	max_integrity = 100
	icon = 'icons/obj/lighting.dmi'
	icon_state = "floodlight_c1"
	density = TRUE
	var/state = FLOODLIGHT_NEEDS_WRENCHING

/obj/structure/floodlight_frame/attackby(obj/item/O, mob/user, params)
	if(istype(O, /obj/item/wrench) && (state == FLOODLIGHT_NEEDS_WRENCHING))
		to_chat(user, span_notice("I secure [src]."))
		anchored = TRUE
		state = FLOODLIGHT_NEEDS_WIRES
		desc = "A bare metal frame looking vaguely like a floodlight. Requires wiring."
	else if(istype(O, /obj/item/stack/cable_coil) && (state == FLOODLIGHT_NEEDS_WIRES))
		if(O.use_tool(src, user, 0, 5))
			to_chat(user, span_notice("I wire [src]."))
			name = "wired [name]"
			desc = "A bare metal frame looking vaguely like a floodlight. Requires securing with a screwdriver."
			icon_state = "floodlight_c2"
			state = FLOODLIGHT_NEEDS_SECURING
	else if(istype(O, /obj/item/light/tube) && (state == FLOODLIGHT_NEEDS_LIGHTS))
		if(user.transferItemToLoc(O))
			to_chat(user, span_notice("I put lights in [src]."))
			new /obj/machinery/power/floodlight(src.loc)
			qdel(src)
	else if(istype(O, /obj/item/screwdriver) && (state == FLOODLIGHT_NEEDS_SECURING))
		to_chat(user, span_notice("I fasten the wiring and electronics in [src]."))
		name = "secured [name]"
		desc = "A bare metal frame that looks like a floodlight. Requires light tubes."
		icon_state = "floodlight_c3"
		state = FLOODLIGHT_NEEDS_LIGHTS
	else
		..()

/obj/machinery/power/floodlight
	name = "floodlight"
	desc = "A pole with powerful mounted lights on it. Due to its high power draw, it must be powered by a direct connection to a wire node."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "floodlight"
	density = TRUE
	max_integrity = 100
	integrity_failure = 0.8
	idle_power_usage = 100
	active_power_usage = 1000
	var/list/light_setting_list = list(0, 5, 10, 15)
	var/light_power_coefficient = 300
	var/setting = 1
	light_power = 1.75

/obj/machinery/power/floodlight/process()
	if(avail(active_power_usage))
		add_load(active_power_usage)
	else
		change_setting(1)

/obj/machinery/power/floodlight/proc/change_setting(val, mob/user)
	if((val < 1) || (val > light_setting_list.len))
		return
	active_power_usage = light_setting_list[val]
	if(!avail(active_power_usage))
		return change_setting(val - 1)
	setting = val
	set_light(light_setting_list[val])
	var/setting_text = ""
	if(val > 1)
		icon_state = "[initial(icon_state)]_on"
	else
		icon_state = initial(icon_state)
	switch(val)
		if(1)
			setting_text = "OFF"
		if(2)
			setting_text = "low power"
		if(3)
			setting_text = "standard lighting"
		if(4)
			setting_text = "high power"
	if(user)
		to_chat(user, "I set [src] to [setting_text].")

/obj/machinery/power/floodlight/attackby(obj/item/O, mob/user, params)
	if(istype(O, /obj/item/wrench))
		default_unfasten_wrench(user, O, time = 20)
		change_setting(1)
		if(anchored)
			connect_to_network()
		else
			disconnect_from_network()
	else
		. = ..()

/obj/machinery/power/floodlight/on_attack_hand(mob/user, act_intent = user.a_intent, unarmed_attack_flags)
	var/current = setting
	if(current == 1)
		current = light_setting_list.len
	else
		current--
	change_setting(current, user)
	..()

/obj/machinery/power/floodlight/obj_break(damage_flag)
	if(!(flags_1 & NODECONSTRUCT_1))
		playsound(loc, 'sound/effects/glassbr3.ogg', 100, 1)
		var/obj/structure/floodlight_frame/F = new(loc)
		F.state = FLOODLIGHT_NEEDS_LIGHTS
		new /obj/item/light/tube/broken(loc)
		qdel(src)

/obj/machinery/power/floodlight/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	playsound(src, 'sound/effects/glasshit.ogg', 75, 1)
