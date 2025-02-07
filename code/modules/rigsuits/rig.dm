#define ONLY_DEPLOY 1
#define ONLY_RETRACT 2
#define SEAL_DELAY 30

/*
 * Defines the behavior of hardsuits/rigs/power armour.
 */

/obj/item/rig
	name = "hardsuit control module"
	icon = 'icons/obj/rig_modules.dmi'
	desc = "A back-mounted hardsuit deployment and control mechanism."
	slot_flags = INV_SLOTBIT_BACK
	req_one_access = list()
	req_access = list()
	w_class = WEIGHT_CLASS_BULKY
	//clothing_flags = STOPSPRESSUREDAMAGE | THICKMATERIAL

	// These values are passed on to all component pieces.
	armor = list(melee = 10, bullet = 5, laser = 10, energy = 5, bomb = 10, bio = 100, rad = 75)
	min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT
	max_heat_protection_temperature = SPACE_SUIT_MAX_TEMP_PROTECT
	siemens_coefficient = 0.2
	permeability_coefficient = 0.1
	//unacidable = 1

	var/interface_path = "hardsuit.tmpl"
	var/ai_interface_path = "hardsuit.tmpl"
	var/interface_title = "Hardsuit Controller"
	var/wearer_move_delay //Used for AI moving.
	var/ai_controlled_move_delay = 10

	// Keeps track of what this rig should spawn with.
	var/suit_type = "hardsuit"
	var/list/initial_modules
	var/chest_type = /obj/item/clothing/suit/space/new_rig
	var/helm_type =  /obj/item/clothing/head/helmet/space/new_rig
	var/boot_type =  /obj/item/clothing/shoes/magboots/rig
	var/glove_type = /obj/item/clothing/gloves/rig
	var/cell_type =  /obj/item/stock_parts/cell/high
	var/air_type =   /obj/item/tank/internals/oxygen

	//Component/device holders.
	var/obj/item/tank/air_supply                       // Air tank, if any.
	var/obj/item/clothing/shoes/magboots/boots = null             // Deployable boots, if any.
	var/obj/item/clothing/shoes/under_boots = null								//Boots that are between the feet and the rig boots, if any.
	var/obj/item/clothing/suit/space/new_rig/chest                // Deployable chestpiece, if any.
	var/obj/item/clothing/head/helmet/space/new_rig/helmet = null // Deployable helmet, if any.
	var/obj/item/clothing/gloves/rig/gloves = null            // Deployable gauntlets, if any.
	var/obj/item/stock_parts/cell/cell                             // Power supply, if any.
	var/obj/item/rig_module/selected_module = null            // Primary system (used with middle-click)
	var/obj/item/rig_module/vision/visor                      // Kinda shitty to have a var for a module, but saves time.
	var/obj/item/rig_module/voice/speech                      // As above.
	var/mob/living/carbon/human/wearer                        // The person currently wearing the rig.
	var/image/mob_icon                                        // Holder for on-mob icon.
	var/list/installed_modules = list()                       // Power consumption/use bookkeeping.

	// Rig status vars.
	var/open = FALSE                                              // Access panel status.
	var/locked = TRUE                                            // Lock status.
	var/subverted = FALSE
	var/interface_locked = FALSE
	var/control_overridden = FALSE
	var/ai_override_enabled = FALSE
	var/security_check_enabled = TRUE
	var/malfunctioning = FALSE
	var/malfunction_delay = 0
	var/electrified = FALSE
	var/locked_down = FALSE

	var/seal_delay = SEAL_DELAY
	var/sealing                                     // Keeps track of seal status independantly of NODROP.
	var/offline = 1                                 // Should we be applying suit maluses?
	var/offline_slowdown = 3                        // If the suit is deployed and unpowered, it sets slowdown to this.
	var/active_slowdown = 3							// How much the deployed suit slows down if powered.
	var/vision_restriction
	var/offline_vision_restriction = 1              // 0 - none, 1 - welder vision, 2 - blind. Maybe move this to helmets.
	var/airtight = TRUE 							//If set, will adjust AIRTIGHT and STOPSPRESSUREDMAGE flags on components. Otherwise it should leave them untouched.

	var/emp_protection = 0
	var/has_emergency_release = TRUE 					//Allows suit to be removed from outside.

	var/datum/effect_system/spark_spread/spark_system

/obj/item/rig/examine()
	//to_chat(usr, "This is [bicon(src)][src.name].")
	to_chat(usr, "This is [src.name].")
	to_chat(usr, "[src.desc]")
	if(wearer)
		for(var/obj/item/piece in list(helmet,gloves,chest,boots))
			if(!piece || piece.loc != wearer)
				continue
			//to_chat(usr, "[bicon(piece)] \The [piece] [piece.gender == PLURAL ? "are" : "is"] deployed.")
			to_chat(usr, "\The [piece] [piece.gender == PLURAL ? "are" : "is"] deployed.")

	if(src.loc == usr)
		to_chat(usr, "The maintenance panel is [open ? "open" : "closed"].")
		to_chat(usr, "Hardsuit systems are [offline ? "<font color='red'>offline</font>" : "<font color='green'>online</font>"].")

/obj/item/rig/Initialize()
	..()

	item_state = icon_state
	wires = new /datum/wires/rig(src)

	if((!req_access || !req_access.len) && (!req_one_access || !req_one_access.len))
		locked = FALSE

	spark_system = new()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)

	START_PROCESSING(SSobj, src)

	if(initial_modules && initial_modules.len)
		for(var/path in initial_modules)
			var/obj/item/rig_module/module = new path(src)
			installed_modules += module
			module.installed(src)

	// Create and initialize our various segments.
	if(cell_type)
		cell = new cell_type(src)
	if(air_type)
		air_supply = new air_type(src)
	if(glove_type)
		gloves = new glove_type(src)
		verbs |= /obj/item/rig/proc/toggle_gauntlets
	if(helm_type)
		helmet = new helm_type(src)
		verbs |= /obj/item/rig/proc/toggle_helmet
		helmet.item_color="[initial(icon_state)]_sealed" //For the lightswitching to know the correct string to manipulate
	if(boot_type)
		boots = new boot_type(src)
		verbs |= /obj/item/rig/proc/toggle_boots
		boots.magboot_state="[initial(icon_state)]_sealed" //For the magboot (de)activation to know the correct string to manipulate
	if(chest_type)
		chest = new chest_type(src)
		if(allowed)
			chest.allowed = allowed
		chest.slowdown = offline_slowdown
		chest.holder = src
		verbs |= /obj/item/rig/proc/toggle_chest

	for(var/obj/item/piece in list(gloves,helmet,boots,chest))
		if(!istype(piece))
			continue
		piece.name = "[suit_type] [initial(piece.name)]"
		piece.desc = "It seems to be part of a [src.name]."
		piece.icon_state = "[initial(icon_state)]"
		piece.min_cold_protection_temperature = min_cold_protection_temperature
		piece.max_heat_protection_temperature = max_heat_protection_temperature
		if(piece.siemens_coefficient > siemens_coefficient) //So that insulated gloves keep their insulation.
			piece.siemens_coefficient = siemens_coefficient
		piece.permeability_coefficient = permeability_coefficient
		//piece.unacidable = unacidable
		if(islist(armor))
			var/list/L = armor
			piece.armor = L.Copy()

	update_icon(1)

/obj/item/rig/Destroy()
	for(var/obj/item/piece in list(gloves,boots,helmet,chest))
		var/mob/living/M = piece.loc
		if(istype(M))
			M.temporarilyRemoveItemFromInventory(piece, 1)
		qdel(piece)
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(wires)
	QDEL_NULL(spark_system)
	return ..()

/obj/item/rig/proc/suit_is_deployed()
	if(!istype(wearer) || src.loc != wearer || wearer.back != src)
		return 0
	if(helm_type && !(helmet && wearer.head == helmet))
		return 0
	if(glove_type && !(gloves && wearer.gloves == gloves))
		return 0
	if(boot_type && !(boots && wearer.shoes == boots))
		return 0
	if(chest_type && !(chest && wearer.wear_suit == chest))
		return 0
	return 1

/obj/item/rig/proc/reset()
	offline = 2
	item_flags &= ~NODROP
	if(helmet && helmet.on)
		helmet.toggle_light(wearer)
	if(boots && boots.magpulse)
		boots.attack_self(wearer)
	for(var/obj/item/piece in list(helmet,boots,gloves,chest))
		if(!piece) continue
		piece.icon_state = "[initial(icon_state)]"
		if(airtight)
			return
			//piece.flags &= ~(STOPSPRESSUREDMAGE | AIRTIGHT)
	update_icon(1)

/obj/item/rig/proc/seal(mob/living/user)
	if(sealing)
		return 0

	if(!wearer || !user)
		return

	var/sealed = (item_flags & NODROP)
	if(sealed)
		to_chat(user, span_danger("\The [src] is already sealed!"))
		return 0

	if(!check_power_cost(user, 1)) //need power to seal the suit
		return 0

	var/failed_to_seal = FALSE

	if(!suit_is_deployed())
		to_chat(user, span_danger("\The [src] cannot seal, as it is not fully deployed!"))
		return 0

	item_flags |= NODROP
	sealing = TRUE

	to_chat(user, span_notice("\The [src] begins to tighten it's seals."))
	wearer.visible_message(span_notice("\The [wearer]'s suit emits a quiet hum as it begins to tighten it's seals."),
						   "<span class='notice'>With a quiet hum, your suit begins to seal.")

	if(seal_delay && !do_after(user, seal_delay, target = wearer))
		to_chat(user, span_warning("I must remain still to seal \the [src]!"))
		failed_to_seal = TRUE

	if(!failed_to_seal)
		deploy(user)

		var/list/pieces_data = list(list(wearer.shoes, boots, "boots", boot_type),
									list(wearer.gloves, gloves, "gloves", glove_type),
									list(wearer.head, helmet, "helmet", helm_type),
									list(wearer.wear_suit, chest, "chest", chest_type))

		for(var/list/piece_data in pieces_data)
			var/obj/item/user_piece = piece_data[1]
			var/obj/item/correct_piece = piece_data[2]
			var/msg_type = piece_data[3]
			var/piece_type = piece_data[4]

			if(!user_piece || !piece_type)
				continue

			if(user_piece != correct_piece)
				to_chat(user, span_danger("\The [user_piece] is blocking \the [src] from deploying."))
				failed_to_seal = TRUE

			if(seal_delay && !do_after(user, seal_delay, needhand = 0, target = wearer))
				to_chat(user, span_warning("I must remain still to seal \the [src]!"))
				failed_to_seal = TRUE

			if(failed_to_seal)
				break

			correct_piece.icon_state = "[initial(icon_state)]_sealed"
			switch(msg_type)
				if("boots")
					to_chat(wearer, "<font color='blue'>\The [correct_piece] seal around your feet.</font>")
					correct_piece.icon_state = "[initial(icon_state)]_sealed0" //Solution to not need a sprite for off, on, and unused magboots.
					if(user != wearer)
						to_chat(user, span_notice("\The [correct_piece] has been sealed."))
					wearer.update_inv_shoes()
				if("gloves")
					to_chat(wearer, "<font color='blue'>\The [correct_piece] tighten around your fingers and wrists.</font>")
					if(user != wearer)
						to_chat(user, span_notice("\The [correct_piece] has been sealed."))
					wearer.update_inv_gloves()
				if("chest")
					to_chat(wearer, "<font color='blue'>\The [correct_piece] cinches tight again your chest.</font>")
					if(user != wearer)
						to_chat(user, span_notice("\The [correct_piece] has been sealed."))
					wearer.update_inv_wear_suit()
				if("helmet")
					to_chat(wearer, "<font color='blue'>\The [correct_piece] hisses closed.</font>")
					correct_piece.icon_state = "[initial(icon_state)]_sealed0" //Solution to not need a sprite for off, on, and unused helmet light.
					if(user != wearer)
						to_chat(user, span_notice("\The [correct_piece] has been sealed."))
					wearer.update_inv_head()
					if(helmet)
						helmet.update_light(wearer)

			correct_piece.armor["bio"] = 100

	sealing = FALSE

	if(failed_to_seal)
		for(var/obj/item/piece in list(helmet, boots, gloves, chest))
			if(!piece)
				continue
			piece.icon_state = "[initial(icon_state)]"
		item_flags &= ~NODROP
		if(airtight)
			update_component_sealed()
		update_icon(1)
		return 0

	if(user != wearer)
		to_chat(user, span_notice("\The [src] has been loosened."))
	to_chat(wearer, span_notice("My entire suit tightens around you as the components lock into place."))
	if(airtight)
		update_component_sealed()
	update_icon(1)

/obj/item/rig/proc/unseal(mob/living/user)
	if(sealing)
		return 0

	if(!wearer || !user)
		return

	var/sealed = (item_flags & NODROP)
	if(!sealed)
		to_chat(user, span_danger("\The [src] is already unsealed!"))
		return 0

	sealing = TRUE

	var/failed_to_seal = FALSE

	if(!suit_is_deployed())
		to_chat(user, span_danger("\The [src] cannot unseal, as it is not fully deployed!"))
		failed_to_seal = TRUE

	if(!failed_to_seal)
		if(user != wearer)
			to_chat(user, span_notice("\The [src] begins to loosen it's seals."))
		wearer.visible_message(span_notice("\The [wearer]'s suit emits a quiet hum as it begins to loosen it's seals."),
							   "<span class='notice'>With a quiet hum, your suit begins to unseal.")

		if(seal_delay && !do_after(user, seal_delay, target = wearer))
			to_chat(user, span_warning("I must remain still to unseal \the [src]!"))
			failed_to_seal = TRUE

		if(!failed_to_seal)
			var/list/pieces_data = list(list(wearer.shoes, boots, "boots", boot_type),
										list(wearer.gloves, gloves, "gloves", glove_type),
										list(wearer.head, helmet, "helmet", helm_type),
										list(wearer.wear_suit, chest, "chest", chest_type))

			for(var/list/piece_data in pieces_data)
				var/obj/item/user_piece = piece_data[1]
				var/obj/item/correct_piece = piece_data[2]
				var/msg_type = piece_data[3]
				var/piece_type = piece_data[4]

				if(!correct_piece || !piece_type)
					continue

				if(user_piece != correct_piece)
					to_chat(user, span_danger("\The [user_piece] is blocking \the [src] from deploying."))
					failed_to_seal = TRUE

				if(seal_delay && !do_after(user, seal_delay, needhand = 0, target = wearer))
					to_chat(user, span_warning("I must remain still to unseal \the [src]!"))
					failed_to_seal = TRUE

				if(failed_to_seal)
					break

				correct_piece.icon_state = "[initial(icon_state)]"
				switch(msg_type)
					if("boots")
						to_chat(wearer, "<font color='blue'>\The [correct_piece] relax [correct_piece.p_their()] grip on your legs.</font>")
						if(user != wearer)
							to_chat(user, span_notice("\The [correct_piece] has been unsealed."))
						wearer.update_inv_shoes()
					if("gloves")
						to_chat(wearer, "<font color='blue'>\The [correct_piece] become loose around your fingers.</font>")
						if(user != wearer)
							to_chat(user, span_notice("\The [correct_piece] has been unsealed."))
						wearer.update_inv_gloves()
					if("chest")
						to_chat(wearer, "<font color='blue'>\The [correct_piece] releases your chest.</font>")
						if(user != wearer)
							to_chat(user, span_notice("\The [correct_piece] has been unsealed."))
						wearer.update_inv_wear_suit()
					if("helmet")
						to_chat(wearer, "<font color='blue'>\The [correct_piece] hisses open.</font>")
						if(user != wearer)
							to_chat(user, span_notice("\The [correct_piece] has been unsealed."))
						wearer.update_inv_head()
						if(helmet)
							helmet.update_light(wearer)

				correct_piece.armor["bio"] = armor["bio"]

	sealing = FALSE

	if(failed_to_seal)
		for(var/obj/item/piece in list(gloves, chest))
			if(!piece)
				continue
			piece.icon_state = "[initial(icon_state)]_sealed"
		if(helmet)
			helmet.icon_state = "[initial(icon_state)]_sealed[helmet.on]"
		if(boots)
			boots.icon_state = "[initial(icon_state)]_sealed[boots.magpulse]"
		if(airtight)
			update_component_sealed()
		update_icon(1)
		return 0

	if(user != wearer)
		to_chat(user, span_notice("\The [src] has been unsealed."))
	to_chat(wearer, span_notice("My entire suit loosens as the components relax."))

	item_flags &= ~NODROP

	for(var/obj/item/rig_module/module in installed_modules)
		module.deactivate()

	if(airtight)
		update_component_sealed()
	update_icon(1)

/obj/item/rig/proc/update_component_sealed()
	if(istype(boots) && !(item_flags & NODROP) && boots.magpulse) //If we have (active) boots and unsealed the suit, we deactivate the magboots.
		boots.attack_self(wearer)
	if(istype(helmet) && !(item_flags & NODROP) && helmet.on) //If we have an (active) headlamp and unsealed the suit, we deactivate the headlamp.
		helmet.toggle_light(wearer)
	//for(obj/item/piece in list(helmet,boots,gloves,chest))
	//	if(!(item_flags & NODROP))
	//		piece.flags &= ~(STOPSPRESSUREDMAGE | AIRTIGHT)
	//	else
			//piece.flags |= STOPSPRESSUREDMAGE | AIRTIGHT

/obj/item/rig/process()
	// If we've lost any parts, grab them back.
	var/mob/living/carbon/M
	for(var/obj/item/piece in list(gloves,boots,helmet,chest))
		if(piece.loc != src && !(wearer && piece.loc == wearer))
			if(istype(piece.loc, /mob/living))
				M = piece.loc
				M.temporarilyRemoveItemFromInventory(piece, 1)
			piece.forceMove(src)

	if(cell && cell.charge > 0 && electrified > 0)
		electrified--

	if(malfunction_delay > 0)
		malfunction_delay--
	else if(malfunctioning)
		malfunctioning--
		malfunction()

	if(!istype(wearer) || loc != wearer || wearer.back != src || !(item_flags & NODROP) || !cell || cell.charge <= 0)
		if(!cell || cell.charge <= 0)
			if(electrified > 0)
				electrified = 0
			if(!offline)
				if(istype(wearer))
					if(item_flags & NODROP)
						if(offline_slowdown < 3)
							to_chat(wearer, span_danger("My suit beeps stridently, and suddenly goes dead."))
						else
							to_chat(wearer, span_danger("My suit beeps stridently, and suddenly you're wearing a leaden mass of metal and plastic composites instead of a powered suit."))
					if(offline_vision_restriction == 1)
						to_chat(wearer, span_danger("The suit optics flicker and die, leaving you with restricted vision."))
					else if(offline_vision_restriction == 2)
						to_chat(wearer, span_danger("The suit optics drop out completely, drowning you in darkness."))
		if(!offline)
			offline = 1
			if(istype(wearer) && wearer.wearing_rig)
				wearer.wearing_rig = null
	else
		if(offline)
			offline = 0
			if(istype(wearer) && !wearer.wearing_rig)
				wearer.wearing_rig = src
			chest.slowdown = active_slowdown

	if(offline)
		if(offline == 1)
			for(var/obj/item/rig_module/module in installed_modules)
				module.deactivate()
			offline = 2
			chest.slowdown = offline_slowdown
		return


	for(var/obj/item/rig_module/module in installed_modules)
		cell.use(module.process()*10)

/obj/item/rig/proc/check_power_cost(mob/living/user, cost, use_unconcious, obj/item/rig_module/mod, user_is_ai)
	if(!istype(user))
		return 0

	var/fail_msg

	if(!user_is_ai)
		var/mob/living/carbon/human/H = user
		if(istype(H) && H.back != src)
			fail_msg = span_warning("I must be wearing \the [src] to do this.")
		else if(user.incorporeal_move)
			fail_msg = span_warning("I must be solid to do this.")
	if(sealing)
		fail_msg = span_warning("The hardsuit is in the process of adjusting seals and cannot be activated.")
	else if(!fail_msg && ((use_unconcious && user.stat > 1) || (!use_unconcious && user.stat)))
		fail_msg = span_warning("I am in no fit state to do that.")
	else if(!cell)
		fail_msg = span_warning("There is no cell installed in the suit.")
	else if(cost && cell.charge < cost * 10) //TODO: Cellrate?
		fail_msg = span_warning("Not enough stored power.")

	if(fail_msg)
		to_chat(user, "[fail_msg]")
		return 0

	// This is largely for cancelling stealth and whatever.
	if(mod && mod.disruptive)
		for(var/obj/item/rig_module/module in (installed_modules - mod))
			if(module.active && module.disruptable)
				module.deactivate()

	cell.use(cost*10)
	return 1

/obj/item/rig/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = TRUE)
	if(!user)
		return

	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, ((src.loc != user) ? ai_interface_path : interface_path), interface_title, 480, 550)
		ui.open()
		ui.autoupdate = TRUE

/obj/item/rig/ui_data(mob/user) //, ui_key = "main", datum/topic_state/state = inventory_state)
	var/data[0]

	data["primarysystem"] = null
	if(selected_module)
		data["primarysystem"] = "[selected_module.interface_name]"

	data["ai"] = 0
	if(src.loc != user)
		data["ai"] = 1

	var/is_sealed = (item_flags & NODROP)	//1 if NODROP, 0 if no-nodrop
	data["seals"] =     "[!is_sealed]"	//1 if not NODROP (unsealed), 0 if NODROP (sealed)
	data["sealing"] =   "[src.sealing]"
	data["helmet"] =    (helmet ? "[helmet.name]" : "None.")
	data["gauntlets"] = (gloves ? "[gloves.name]" : "None.")
	data["boots"] =     (boots ?  "[boots.name]" :  "None.")
	data["chest"] =     (chest ?  "[chest.name]" :  "None.")

	data["charge"] =       cell ? round(cell.charge,1) : 0
	data["maxcharge"] =    cell ? cell.maxcharge : 0
	data["chargestatus"] = (cell.charge/cell.maxcharge)*50

	data["emagged"] =       subverted
	data["coverlock"] =     locked
	data["interfacelock"] = interface_locked
	data["aicontrol"] =     control_overridden
	data["aioverride"] =    ai_override_enabled
	data["securitycheck"] = security_check_enabled
	data["malf"] =          malfunction_delay


	var/list/module_list = list()
	var/i = 1
	for(var/obj/item/rig_module/module in installed_modules)
		var/list/module_data = list(
			"index" =             i,
			"name" =              "[module.interface_name]",
			"desc" =              "[module.interface_desc]",
			"can_use" =           "[module.usable]",
			"can_select" =        "[module.selectable]",
			"can_toggle" =        "[module.toggleable]",
			"is_active" =         "[module.active]",
			"engagecost" =        module.use_power_cost*10,
			"activecost" =        module.active_power_cost*10,
			"passivecost" =       module.passive_power_cost*10,
			"engagestring" =      module.engage_string,
			"activatestring" =    module.activate_string,
			"deactivatestring" =  module.deactivate_string,
			"damage" =            module.damage
			)

		if(module.charges && module.charges.len)

			module_data["charges"] = list()
			var/datum/rig_charge/selected = module.charges[module.charge_selected]
			module_data["chargetype"] = selected ? "[selected.display_name]" : "none"

			for(var/chargetype in module.charges)
				var/datum/rig_charge/charge = module.charges[chargetype]
				module_data["charges"] += list(list("caption" = "[chargetype] ([charge.charges])", "index" = "[chargetype]"))

		module_list += list(module_data)
		i++

	if(module_list.len)
		data["modules"] = module_list

	return data

/obj/item/rig/update_icon(update_mob_icon)
	//TODO: Maybe consider a cache for this (use mob_icon as blank canvas, use suit icon overlay).
	overlays.Cut()
//	if(!mob_icon || update_mob_icon)
//		var/species_icon = 'icons/mob/rig_back.dmi'
		// Since setting mob_icon will override the species checks in
		// update_inv_wear_suit(), handle species checks here.
//		if(wearer && sprite_sheets && sprite_sheets[wearer.dna.species.name])
//			species_icon =  sprite_sheets[wearer.dna.species.name]
		//mob_icon = image("icon" = species_icon, "icon_state" = "[icon_state]")

	if(installed_modules.len)
		for(var/obj/item/rig_module/module in installed_modules)
			if(module.suit_overlay)
				chest.overlays += image("icon" = 'icons/mob/rig_modules.dmi', "icon_state" = "[module.suit_overlay]", "dir" = SOUTH)

	if(wearer)
		wearer.update_inv_shoes()
		wearer.update_inv_gloves()
		wearer.update_inv_head()
		wearer.update_inv_wear_suit()
		wearer.update_inv_back()
	return

/obj/item/rig/proc/check_suit_access(mob/living/carbon/human/user)
	if(!security_check_enabled)
		return 1

	if(istype(user))
		//if(malfunction_check(user))
		//	return 0
		if(user.back != src)
			return 0
		else if(!src.allowed(user))
			to_chat(user, span_danger("Unauthorized user. Access denied."))
			return 0

	else if(!ai_override_enabled)
		to_chat(user, span_danger("Synthetic access disabled. Please consult hardware provider."))
		return 0

	return 1

/obj/item/rig/Topic(href,href_list)
	if(!check_suit_access(usr))
		return 0

	if(href_list["toggle_piece"])
		if(ishuman(usr) && (usr.stat || usr.restrained() || usr.lying))
			return 0
		toggle_piece(href_list["toggle_piece"], usr)
	else if(href_list["toggle_seals"])
		if(item_flags & NODROP)
			unseal(usr)
		else
			seal(usr)
	else if(href_list["interact_module"])
		var/module_index = text2num(href_list["interact_module"])

		if(module_index > 0 && module_index <= installed_modules.len)
			var/obj/item/rig_module/module = installed_modules[module_index]
			switch(href_list["module_mode"])
				if("activate")
					module.activate()
				if("deactivate")
					module.deactivate()
				if("engage")
					module.engage()
				if("select")
					selected_module = module
				if("select_charge_type")
					module.charge_selected = href_list["charge_type"]
	else if(href_list["toggle_ai_control"])
		ai_override_enabled = !ai_override_enabled
		notify_ai("Synthetic suit control has been [ai_override_enabled ? "enabled" : "disabled"].")
	else if(href_list["toggle_suit_lock"])
		locked = !locked

	usr.set_machine(src)
	add_fingerprint(usr)
	return 0

/obj/item/rig/proc/notify_ai(message)
	if(!message || !installed_modules || !installed_modules.len)
		return
	for(var/obj/item/rig_module/module in installed_modules)
		for(var/mob/living/silicon/ai/ai in module.contents)
			if(ai && ai.client && !ai.stat)
				to_chat(ai, "[message]")

/obj/item/rig/equipped(mob/living/carbon/human/M, slot)
	..()
	if(!istype(M) || slot != SLOT_BACK)
		return //we don't care about picking up/nonhumans

	spawn(1) //equipped() is called BEFORE the item is actually set as the slot

		if(seal_delay > 0 && istype(M) && M.back == src)
			M.visible_message("<font color='blue'>[M] starts putting on \the [src]...</font>", "<font color='blue'>You start putting on \the [src]...</font>")
			if(!do_after(M, seal_delay, target = M))
				if(M && M.back == src)
					M.doUnEquip(src)
					M.put_in_hands(src)
				return

		if(istype(M) && M.back == src)
			M.visible_message("<font color='blue'><b>[M] struggles into \the [src].</b></font>", "<font color='blue'><b>You struggle into \the [src].</b></font>")
			wearer = M
			wearer.wearing_rig = src
			if(has_emergency_release)
				M.verbs |= /obj/item/rig/proc/emergency_release
			update_icon()

/obj/item/rig/proc/toggle_piece(piece, mob/living/user, deploy_mode, force)
	if(!istype(wearer) || wearer.back != src)
		if(force) //can only force retracting sorry
			for(var/obj/item/uneq_piece in list(helmet, gloves, boots, chest))
				if(uneq_piece)
					if(isliving(uneq_piece.loc))
						var/mob/living/L = uneq_piece.loc
						L.temporarilyRemoveItemFromInventory(uneq_piece, 1, 1)
						if(uneq_piece == boots)
							if(under_boots)
								if(L.equip_to_slot_if_possible(under_boots, SLOT_SHOES))
									under_boots = null
								else
									to_chat(user, span_warning("Somehow, your [under_boots] got stuck to the [boots], and were retracted with them. ((This shouldn't happen, bug report this.))"))
					uneq_piece.forceMove(src)
		return 0

	if(sealing || !cell || !cell.charge)
		return 0

	if(!(deploy_mode == ONLY_RETRACT && force)) //This should be the case while stripping, stripping does trigger the if statement below.
		if(user == wearer && user.incapacitated()) // If the user isn't wearing the suit it's probably an AI.
			return 0

	var/obj/item/check_slot
	var/equip_to
	var/obj/item/use_obj

	switch(piece)
		if("helmet")
			equip_to = SLOT_HEAD
			use_obj = helmet
			check_slot = wearer.head
		if("gauntlets")
			equip_to = SLOT_GLOVES
			use_obj = gloves
			check_slot = wearer.gloves
		if("boots")
			equip_to = SLOT_SHOES
			use_obj = boots
			check_slot = wearer.shoes
		if("chest")
			equip_to = SLOT_WEAR_SUIT
			use_obj = chest
			check_slot = wearer.wear_suit

	if(use_obj)
		if(check_slot == use_obj && deploy_mode != ONLY_DEPLOY) //user is wearing it, retract it if not forced to deploy
			if((item_flags & NODROP) && equip_to != SLOT_HEAD && !force) //you can only retract the helmet if the suit isn't unsealed
				to_chat(user, span_warning("I can't retract \the [use_obj] while the suit is sealed!"))
				return

			var/mob/living/to_strip
			if(wearer)
				to_strip = wearer
			else if(isliving(use_obj.loc))
				to_strip = use_obj.loc

			if(to_strip)
				to_strip.temporarilyRemoveItemFromInventory(use_obj, 1)
				if(use_obj == boots)
					if(under_boots)
						if(to_strip.equip_to_slot_if_possible(under_boots, SLOT_SHOES))
							under_boots = null
						else
							to_chat(user, span_warning("Somehow, your [under_boots] got stuck to the [boots], and were retracted with them. ((This shouldn't happen, bug report this.))"))
			use_obj.forceMove(src)
			if(wearer)
				to_chat(wearer, "<span class='notice'>Your [use_obj] [use_obj.gender == PLURAL ? "retract" : "retracts"] swiftly.")

		else if(deploy_mode != ONLY_RETRACT)
			if(check_slot)
				if(check_slot != use_obj) //If use_obj is already in check_slot, silently bail. Otherwise, tell the user why the part didn't deploy.
					if(use_obj == boots)
						under_boots = check_slot
						wearer.temporarilyRemoveItemFromInventory(under_boots, 1, 1)
						under_boots.forceMove(src)
					else
						to_chat(wearer, span_danger("I am unable to deploy \the [piece] as \the [check_slot] [check_slot.gender == PLURAL ? "are" : "is"] in the way."))
						return
			use_obj.forceMove(wearer)
			if(!wearer.equip_to_slot_if_possible(use_obj, equip_to, 0, 1))
				use_obj.forceMove(src)
			else
				if(wearer)
					to_chat(wearer, span_notice("My [use_obj.name] [use_obj.gender == PLURAL ? "deploy" : "deploys"] swiftly."))

	if(piece == "helmet" && helmet)
		helmet.update_light(wearer)

/obj/item/rig/proc/deploy(mob/user)
	if(!wearer || !user)
		return 0

	if(item_flags & NODROP) //We need to check if we have the part, the person is wearing something in the parts slot, and if yes, are they the same.
		if(helmet && wearer.head && wearer.head != helmet)
			to_chat(user, span_danger("\The [wearer.head] is blocking \the [src] from deploying!"))
			return 0
		if(gloves && wearer.gloves && wearer.gloves != gloves)
			to_chat(user, span_danger("\The [wearer.gloves] is preventing \the [src] from deploying!"))
			return 0
		/*if(boots && wearer.shoes && wearer.shoes != boots)
			to_chat(user, span_danger("\The [wearer.shoes] is preventing \the [src] from deploying!"))
			return 0*/
		if(chest && wearer.wear_suit && wearer.wear_suit != chest)
			to_chat(user, span_danger("\The [wearer.wear_suit] is preventing \the [src] from deploying!"))
			return 0


	for(var/piece in list("helmet", "gauntlets", "chest", "boots"))
		toggle_piece(piece, user, ONLY_DEPLOY)

/obj/item/rig/dropped(mob/user)
	..()
	user.verbs -= /obj/item/rig/proc/emergency_release
	for(var/piece in list("helmet","gauntlets","chest","boots"))
		toggle_piece(piece, user, ONLY_RETRACT, 1)
	if(wearer)
		wearer.wearing_rig = null
		wearer = null

//Todo
/obj/item/rig/proc/malfunction()
	return 0

/obj/item/rig/emp_act(severity_class)
	//set malfunctioning
	//if(emp_protection < 30) //for ninjas, really.
	//	malfunctioning += 10
	//	if(malfunction_delay <= 0)
	//		malfunction_delay = max(malfunction_delay, round(30/severity_class))

	//drain some charge
	if(cell) 
		cell.emp_act(severity_class + 15)

	//possibly damage some modules
	//take_hit((100/severity_class), "electrical pulse", 1)

/obj/item/rig/proc/shock(mob/user)
	if(get_dist(src, user) <= 1) //Needs to be adjecant to the rig to get shocked.
		if(electrocute_mob(user, cell, src)) //electrocute_mob() handles removing charge from the cell, no need to do that here.
			spark_system.start()
			if(user.restrained())
				return 1
	return 0
/*
/obj/item/rig/proc/take_hit(damage, source, is_emp=0)

	if(!installed_modules.len)
		return

	var/chance
	if(!is_emp)
		chance = 2*max(0, damage - (chest? chest.breach_threshold : 0))
	else
		//Want this to be roughly independant of the number of modules, meaning that X emp hits will disable Y% of the suit's modules on average.
		//that way people designing hardsuits don't have to worry (as much) about how adding that extra module will affect emp resiliance by 'soaking' hits for other modules
		chance = 2*max(0, damage - emp_protection)*min(installed_modules.len/15, 1)

	if(!prob(chance))
		return

	//deal addition damage to already damaged module first.
	//This way the chances of a module being disabled aren't so remote.
	var/list/valid_modules = list()
	var/list/damaged_modules = list()
	for(var/obj/item/rig_module/module in installed_modules)
		if(module.damage < 2)
			valid_modules |= module
			if(module.damage > 0)
				damaged_modules |= module

	var/obj/item/rig_module/dam_module = null
	if(damaged_modules.len)
		dam_module = pick(damaged_modules)
	else if(valid_modules.len)
		dam_module = pick(valid_modules)

	if(!dam_module) return

	dam_module.damage++

	if(!source)
		source = "hit"

	if(wearer)
		if(dam_module.damage >= 2)
			to_chat(wearer, span_danger("The [source] has disabled your [dam_module.interface_name]!"))
		else
			to_chat(wearer, span_warning("The [source] has damaged your [dam_module.interface_name]!"))
	dam_module.deactivate()

/obj/item/rig/proc/malfunction_check(mob/living/carbon/human/user)
	if(malfunction_delay)
		if(offline)
			to_chat(user, span_danger("The suit is completely unresponsive."))
		else
			to_chat(user, span_danger("ERROR: Hardware fault. Rebooting interface..."))
		return 1
	return 0

/obj/item/rig/proc/ai_can_move_suit(mob/user, check_user_module = 0, check_for_ai = 0)

	if(check_for_ai)
		if(!(locate(/obj/item/rig_module/ai_container) in contents))
			return 0
		var/found_ai
		for(var/obj/item/rig_module/ai_container/module in contents)
			if(module.damage >= 2)
				continue
			if(module.integrated_ai && module.integrated_ai.client && !module.integrated_ai.stat)
				found_ai = 1
				break
		if(!found_ai)
			return 0

	if(check_user_module)
		if(!user || !user.loc || !user.loc.loc)
			return 0
		var/obj/item/rig_module/ai_container/module = user.loc.loc
		if(!istype(module) || module.damage >= 2)
			to_chat(user, span_warning("My host module is unable to interface with the suit."))
			return 0

	if(offline || !cell || !cell.charge || locked_down)
		if(user)
			to_chat(user, span_warning("My host rig is unpowered and unresponsive."))
		return 0
	if(!wearer || wearer.back != src)
		if(user)
			to_chat(user, span_warning("My host rig is not being worn."))
		return 0
	if(!wearer.stat && !control_overridden && !ai_override_enabled)
		if(user)
			to_chat(user, span_warning("I am locked out of the suit servo controller."))
		return 0
	return 1
*/
/obj/item/rig/proc/force_rest(mob/user)
//	if(!ai_can_move_suit(user, check_user_module = 1))
	wearer.lay_down()
	to_chat(user, span_notice("\The [wearer] is now [wearer.resting ? "resting" : "getting up"]."))

/obj/item/rig/proc/forced_move(direction, mob/user)

	// Why is all this shit in client/Move()? Who knows?
	if(world.time < wearer_move_delay)
		return

	if(!wearer || !wearer.loc)
		return

	//This is sota the goto stop mobs from moving var
	if(wearer.notransform || !wearer.canmove)
		return

//	if(!wearer.lastarea)
//		wearer.lastarea = get_area(wearer.loc)

//	if((istype(wearer.loc, /turf/space)) || (wearer.lastarea.has_gravity == 0))
//		if(!wearer.Process_Spacemove(0))
//			return 0

//	if(malfunctioning)
//		direction = pick(cardinal)

	// Inside an object, tell it we moved.
	if(isobj(wearer.loc) || ismob(wearer.loc))
		var/atom/O = wearer.loc
		return O.relaymove(wearer, direction)

	if(isturf(wearer.loc))
		if(wearer.restrained())//because they can just escape
			for(var/mob/M in range(wearer, 1))
				if(M.pulling == wearer)
					if(!M.restrained() && M.stat == 0 && M.canmove && wearer.Adjacent(M))
						to_chat(user, span_notice("My host is restrained! They can't move!"))
						return 0
					else
						M.stop_pulling()

	// AIs are a bit slower than regular and ignore move intent.
	wearer_move_delay = world.time + ai_controlled_move_delay

	if(wearer.buckled)							//if we're buckled to something, tell it we moved.
		return wearer.buckled.relaymove(wearer, direction)

	if(cell.use(200)) //Arbitrary, TODO
		wearer.Move(get_step(get_turf(wearer),direction),direction)

// This returns the rig if you are contained inside one, but not if you are wearing it
/atom/proc/get_rig()
	if(loc)
		return loc.get_rig()
	return null

/obj/item/rig/get_rig()
	return src

/mob/living/carbon/human/get_rig()
	if(istype(back,/obj/item/rig))
		return back
	else
		return null

/obj/item/rig/proc/emergency_release()
	set name = "Suit Emergency Release"
	set desc = "Activate the suits emergency release system."
	set category = "Object"
	set src in oview(1)
	var/obj/item/rig/T = get_rig()
	return T.do_emergency_release(usr)

/obj/item/rig/proc/do_emergency_release(mob/living/user)
	if(!can_touch(user, wearer) || !has_emergency_release)
		return can_touch(user,wearer)
	usr.visible_message(span_warning("[user] starts activating \the [src] emergency seals release!"))
	if(!do_after(user, 240, target = wearer))
		to_chat(user, span_notice("I need to focus on activating the emergency release."))
		return 0
	usr.visible_message(span_warning("[user] activated \the [src] emergency seals release!"))
	malfunctioning += 1
	malfunction_delay = 30
	unseal(user)
	return 1

/obj/item/rig/proc/can_touch(mob/user, mob/wearer)
	if(!user)
		return 0
	if(!wearer.Adjacent(user))
		return 0
	if(user.restrained())
		to_chat(user, span_notice("I need your hands free for this."))
		return 0
	if(user.stat || user.resting || user.lying || user.restrained())
		return 0
	return 1
#undef ONLY_DEPLOY
#undef ONLY_RETRACT
#undef SEAL_DELAY
