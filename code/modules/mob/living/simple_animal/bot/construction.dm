//Bot Construction

/obj/item/bot_assembly
	icon = 'icons/mob/aibots.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	force = 3
	throw_speed = 2
	throw_range = 5
	var/created_name
	var/build_step = ASSEMBLY_FIRST_STEP
	var/robot_arm = /obj/item/bodypart/r_arm/robot

/obj/item/bot_assembly/attackby(obj/item/I, mob/user, params)
	..()
	if(istype(I, /obj/item/pen))
		rename_bot()
		return

/obj/item/bot_assembly/proc/rename_bot()
	var/t = stripped_input(usr, "Enter new robot name", name, created_name,MAX_NAME_LEN)
	if(!t)
		return
	if(!in_range(src, usr) && loc != usr)
		return
	created_name = t

/obj/item/bot_assembly/proc/can_finish_build(obj/item/I, mob/user)
	if(istype(loc, /obj/item/storage/backpack))
		to_chat(user, span_warning("I must take [src] out of [loc] first!"))
		return FALSE
	if(!I || !user || !user.temporarilyRemoveItemFromInventory(I))
		return FALSE
	return TRUE

//Cleanbot assembly
/obj/item/bot_assembly/cleanbot
	desc = "It's a bucket with a sensor attached."
	name = "incomplete cleanbot assembly"
	icon_state = "bucket_proxy"
	throwforce = 5
	created_name = "Cleanbot"

/obj/item/bot_assembly/cleanbot/attackby(obj/item/W, mob/user, params)
	..()
	if(istype(W, /obj/item/bodypart/l_arm/robot) || istype(W, /obj/item/bodypart/r_arm/robot))
		if(!can_finish_build(W, user))
			return
		var/mob/living/simple_animal/bot/cleanbot/A = new(drop_location())
		A.name = created_name
		A.robot_arm = W.type
		to_chat(user, span_notice("I add [W] to [src]. Beep boop!"))
		qdel(W)
		qdel(src)


//Edbot Assembly
/obj/item/bot_assembly/ed209
	name = "incomplete ED-209 assembly"
	desc = "Some sort of bizarre assembly."
	icon_state = "ed209_frame"
	item_state = "ed209_frame"
	created_name = "ED-209 Security Robot" //To preserve the name if it's a unique securitron I guess
	var/lasercolor = ""
	var/vest_type = /obj/item/clothing/suit/armor/medium/vest

/obj/item/bot_assembly/ed209/attackby(obj/item/W, mob/user, params)
	..()
	switch(build_step)
		if(ASSEMBLY_FIRST_STEP, ASSEMBLY_SECOND_STEP)
			if(istype(W, /obj/item/bodypart/l_leg/robot) || istype(W, /obj/item/bodypart/r_leg/robot))
				if(!user.temporarilyRemoveItemFromInventory(W))
					return
				to_chat(user, span_notice("I add [W] to [src]."))
				qdel(W)
				name = "legs/frame assembly"
				if(build_step == ASSEMBLY_FIRST_STEP)
					item_state = "ed209_leg"
					icon_state = "ed209_leg"
				else
					item_state = "ed209_legs"
					icon_state = "ed209_legs"
				build_step++

		if(ASSEMBLY_THIRD_STEP)
			var/newcolor = ""
			if(istype(W, /obj/item/clothing/suit/redtag))
				newcolor = "r"
			else if(istype(W, /obj/item/clothing/suit/bluetag))
				newcolor = "b"
			if(newcolor || istype(W, /obj/item/clothing/suit/armor/medium/vest))
				if(!user.temporarilyRemoveItemFromInventory(W))
					return
				lasercolor = newcolor
				vest_type = W.type
				to_chat(user, span_notice("I add [W] to [src]."))
				qdel(W)
				name = "vest/legs/frame assembly"
				item_state = "[lasercolor]ed209_shell"
				icon_state = "[lasercolor]ed209_shell"
				build_step++

		if(ASSEMBLY_FOURTH_STEP)
			if(istype(W, /obj/item/weldingtool))
				if(W.use_tool(src, user, 0, volume=40) && build_step == ASSEMBLY_FOURTH_STEP)
					name = "shielded frame assembly"
					to_chat(user, span_notice("I weld the vest to [src]."))
					build_step++

		if(ASSEMBLY_FIFTH_STEP)
			switch(lasercolor)
				if("b")
					if(!istype(W, /obj/item/clothing/head/helmet/bluetaghelm))
						return

				if("r")
					if(!istype(W, /obj/item/clothing/head/helmet/redtaghelm))
						return

				if("")
					if(!istype(W, /obj/item/clothing/head/helmet))
						return

			if(!user.temporarilyRemoveItemFromInventory(W))
				return
			to_chat(user, span_notice("I add [W] to [src]."))
			qdel(W)
			name = "covered and shielded frame assembly"
			item_state = "[lasercolor]ed209_hat"
			icon_state = "[lasercolor]ed209_hat"
			build_step++

		if(5)
			if(isprox(W))
				if(!user.temporarilyRemoveItemFromInventory(W))
					return
				build_step++
				to_chat(user, span_notice("I add [W] to [src]."))
				qdel(W)
				name = "covered, shielded and sensored frame assembly"
				item_state = "[lasercolor]ed209_prox"
				icon_state = "[lasercolor]ed209_prox"

		if(6)
			if(istype(W, /obj/item/stack/cable_coil))
				var/obj/item/stack/cable_coil/coil = W
				if(coil.get_amount() < 1)
					to_chat(user, span_warning("I need one length of cable to wire the ED-209!"))
					return
				to_chat(user, span_notice("I start to wire [src]..."))
				if(coil.use_tool(src, user, 40, 1))
					if(build_step == 6)
						to_chat(user, span_notice("I wire [src]."))
						name = "wired ED-209 assembly"
						build_step++

		if(7)
			var/newname = ""
			switch(lasercolor)
				if("b")
					if(!istype(W, /obj/item/gun/energy/laser/bluetag))
						return
					newname = "bluetag ED-209 assembly"
				if("r")
					if(!istype(W, /obj/item/gun/energy/laser/redtag))
						return
					newname = "redtag ED-209 assembly"
				if("")
					if(!istype(W, /obj/item/gun/energy/e_gun/advtaser))
						return
					newname = "taser ED-209 assembly"
				else
					return
			if(!user.temporarilyRemoveItemFromInventory(W))
				return
			name = newname
			to_chat(user, span_notice("I add [W] to [src]."))
			item_state = "[lasercolor]ed209_taser"
			icon_state = "[lasercolor]ed209_taser"
			qdel(W)
			build_step++

		if(8)
			if(istype(W, /obj/item/screwdriver))
				to_chat(user, span_notice("I start attaching the gun to the frame..."))
				if(W.use_tool(src, user, 40, volume=100) && build_step == 8)
					name = "armed [name]"
					to_chat(user, span_notice("Taser gun attached."))
					build_step++

		if(9)
			if(istype(W, /obj/item/stock_parts/cell))
				if(!can_finish_build(W, user))
					return
				var/mob/living/simple_animal/bot/ed209/B = new(drop_location(),created_name,lasercolor)
				to_chat(user, span_notice("I complete the ED-209."))
				B.cell_type = W.type
				qdel(W)
				B.vest_type = vest_type
				qdel(src)


//Floorbot assemblies
/obj/item/bot_assembly/floorbot
	desc = "It's a toolbox with tiles sticking out the top."
	name = "tiles and toolbox"
	icon_state = "toolbox_tiles"
	throwforce = 10
	created_name = "Floorbot"
	var/toolbox = /obj/item/storage/toolbox/mechanical

/obj/item/bot_assembly/floorbot/Initialize()
	. = ..()
	update_icon()

/obj/item/bot_assembly/floorbot/update_icon()
	..()
	switch(build_step)
		if(ASSEMBLY_FIRST_STEP)
			desc = initial(desc)
			name = initial(name)
			icon_state = initial(icon_state)

		if(ASSEMBLY_SECOND_STEP)
			desc = "It's a toolbox with tiles sticking out the top and a sensor attached."
			name = "incomplete floorbot assembly"
			icon_state = "toolbox_tiles_sensor"

/obj/item/storage/toolbox/mechanical/attackby(obj/item/stack/tile/plasteel/T, mob/user, params)
	if(!istype(T, /obj/item/stack/tile/plasteel))
		..()
		return
	if(contents.len >= 1)
		to_chat(user, span_warning("They won't fit in, as there is already stuff inside!"))
		return
	if(T.use(10))
		var/obj/item/bot_assembly/floorbot/B = new
		B.toolbox = type
		user.put_in_hands(B)
		to_chat(user, span_notice("I add the tiles into the empty [src.name]. They protrude from the top."))
		qdel(src)
	else
		to_chat(user, span_warning("I need 10 floor tiles to start building a floorbot!"))
		return

/obj/item/bot_assembly/floorbot/attackby(obj/item/W, mob/user, params)
	..()
	switch(build_step)
		if(ASSEMBLY_FIRST_STEP)
			if(isprox(W))
				if(!user.temporarilyRemoveItemFromInventory(W))
					return
				to_chat(user, span_notice("I add [W] to [src]."))
				qdel(W)
				build_step++
				update_icon()

		if(ASSEMBLY_SECOND_STEP)
			if(istype(W, /obj/item/bodypart/l_arm/robot) || istype(W, /obj/item/bodypart/r_arm/robot))
				if(!can_finish_build(W, user))
					return
				var/mob/living/simple_animal/bot/floorbot/A = new(drop_location())
				A.name = created_name
				A.robot_arm = W.type
				A.toolbox = toolbox
				to_chat(user, span_notice("I add [W] to [src]. Boop beep!"))
				qdel(W)
				qdel(src)


//Medbot Assembly
/obj/item/bot_assembly/medbot
	name = "incomplete medibot assembly"
	desc = "A first aid kit with a robot arm permanently grafted to it."
	icon_state = "firstaid_arm"
	created_name = "Ny4ke" //To preserve the name if it's a unique medbot I guess
	var/skin = null //Same as medbot, set to tox or ointment for the respective kits.
	var/healthanalyzer = /obj/item/healthanalyzer
	var/firstaid = /obj/item/storage/firstaid

/obj/item/bot_assembly/medbot/Initialize()
	. = ..()
	spawn(5)
		if(skin)
			add_overlay("kit_skin_[skin]")

/obj/item/storage/firstaid/attackby(obj/item/bodypart/S, mob/user, params)

	if((!istype(S, /obj/item/bodypart/l_arm/robot)) && (!istype(S, /obj/item/bodypart/r_arm/robot)))
		return ..()

	//Making a medibot!
	if(contents.len >= 1)
		to_chat(user, span_warning("I need to empty [src] out first!"))
		return

	var/obj/item/bot_assembly/medbot/A = new
/*	if(istype(src, /obj/item/storage/firstaid/fire))
		A.skin = "ointment"
	else if(istype(src, /obj/item/storage/firstaid/toxin))
		A.skin = "tox"
	else if(istype(src, /obj/item/storage/firstaid/o2))
		A.skin = "o2"
	else if(istype(src, /obj/item/storage/firstaid/brute))
		A.skin = "brute"*/
	user.put_in_hands(A)
	to_chat(user, span_notice("I add [S] to [src]."))
	A.robot_arm = S.type
	A.firstaid = type
	qdel(S)
	qdel(src)

/obj/item/bot_assembly/medbot/attackby(obj/item/W, mob/user, params)
	..()
	switch(build_step)
		if(ASSEMBLY_FIRST_STEP)
			if(istype(W, /obj/item/healthanalyzer))
				if(!user.temporarilyRemoveItemFromInventory(W))
					return
				healthanalyzer = W.type
				to_chat(user, span_notice("I add [W] to [src]."))
				qdel(W)
				name = "first aid/robot arm/health analyzer assembly"
				add_overlay("na_scanner")
				build_step++

		if(ASSEMBLY_SECOND_STEP)
			if(isprox(W))
				if(!can_finish_build(W, user))
					return
				qdel(W)
				var/mob/living/simple_animal/bot/medbot/S = new(drop_location(), skin)
				to_chat(user, span_notice("I complete the Medbot. Beep boop!"))
				S.name = created_name
				S.firstaid = firstaid
				S.robot_arm = robot_arm
				S.healthanalyzer = healthanalyzer
				qdel(src)

//Secbot Assembly
/obj/item/bot_assembly/secbot
	name = "incomplete securitron assembly"
	desc = "Some sort of bizarre assembly made from a proximity sensor, helmet, and signaler."
	icon_state = "helmet_signaler"
	item_state = "helmet"
	created_name = "Securitron" //To preserve the name if it's a unique securitron I guess
	var/swordamt = 0 //If you're converting it into a grievousbot, how many swords have you attached
	var/toyswordamt = 0 //honk

/obj/item/bot_assembly/secbot/attackby(obj/item/I, mob/user, params)
	..()
	var/atom/Tsec = drop_location()
	switch(build_step)
		if(ASSEMBLY_FIRST_STEP)
			if(istype(I, /obj/item/weldingtool))
				if(I.use_tool(src, user, 0, volume=40))
					add_overlay("hs_hole")
					to_chat(user, span_notice("I weld a hole in [src]!"))
					build_step++

			else if(istype(I, /obj/item/screwdriver)) //deconstruct
				new /obj/item/assembly/signaler(Tsec)
				new /obj/item/clothing/head/helmet/sec(Tsec)
				to_chat(user, span_notice("I disconnect the signaler from the helmet."))
				qdel(src)

		if(ASSEMBLY_SECOND_STEP)
			if(isprox(I))
				if(!user.temporarilyRemoveItemFromInventory(I))
					return
				to_chat(user, span_notice("I add [I] to [src]!"))
				add_overlay("hs_eye")
				name = "helmet/signaler/prox sensor assembly"
				qdel(I)
				build_step++

			else if(istype(I, /obj/item/weldingtool)) //deconstruct
				if(I.use_tool(src, user, 0, volume=40))
					cut_overlay("hs_hole")
					to_chat(user, span_notice("I weld the hole in [src] shut!"))
					build_step--

		if(ASSEMBLY_THIRD_STEP)
			if((istype(I, /obj/item/bodypart/l_arm/robot)) || (istype(I, /obj/item/bodypart/r_arm/robot)))
				if(!user.temporarilyRemoveItemFromInventory(I))
					return
				to_chat(user, span_notice("I add [I] to [src]!"))
				name = "helmet/signaler/prox sensor/robot arm assembly"
				add_overlay("hs_arm")
				robot_arm = I.type
				qdel(I)
				build_step++

			else if(istype(I, /obj/item/screwdriver)) //deconstruct
				cut_overlay("hs_eye")
				new /obj/item/assembly/prox_sensor(Tsec)
				to_chat(user, span_notice("I detach the proximity sensor from [src]."))
				build_step--

		if(ASSEMBLY_FOURTH_STEP)
			if(istype(I, /obj/item/melee/baton))
				if(!can_finish_build(I, user))
					return
				to_chat(user, span_notice("I complete the Securitron! Beep boop."))
				var/mob/living/simple_animal/bot/secbot/S = new(Tsec)
				S.name = created_name
				S.baton_type = I.type
				S.robot_arm = robot_arm
				qdel(I)
				qdel(src)
			if(istype(I, /obj/item/wrench))
				to_chat(user, "I adjust [src]'s arm slots to mount extra weapons")
				build_step ++
				return
			if(istype(I, /obj/item/toy/sword))
				if(toyswordamt < 3 && swordamt <= 0)
					if(!user.temporarilyRemoveItemFromInventory(I))
						return
					created_name = "General Beepsky"
					name = "helmet/signaler/prox sensor/robot arm/toy sword assembly"
					icon_state = "grievous_assembly"
					to_chat(user, span_notice("I superglue [I] onto one of [src]'s arm slots."))
					qdel(I)
					toyswordamt ++
				else
					if(!can_finish_build(I, user))
						return
					to_chat(user, span_notice("I complete the Securitron!...Something seems a bit wrong with it..?"))
					var/mob/living/simple_animal/bot/secbot/grievous/toy/S = new(Tsec)
					S.name = created_name
					S.robot_arm = robot_arm
					qdel(I)
					qdel(src)

			else if(istype(I, /obj/item/screwdriver)) //deconstruct
				cut_overlay("hs_arm")
				var/obj/item/bodypart/dropped_arm = new robot_arm(Tsec)
				robot_arm = null
				to_chat(user, span_notice("I remove [dropped_arm] from [src]."))
				build_step--
				if(toyswordamt > 0 || toyswordamt)
					icon_state = initial(icon_state)
					to_chat(user, span_notice("The superglue binding [src]'s toy swords to its chassis snaps!"))
					for(var/IS in 1 to toyswordamt)
						new /obj/item/toy/sword(Tsec)
						toyswordamt--

		if(ASSEMBLY_FIFTH_STEP)
			if(istype(I, /obj/item/melee/transforming/plasmacutter/sword/saber))
				if(swordamt < 3)
					if(!user.temporarilyRemoveItemFromInventory(I))
						return
					created_name = "General Beepsky"
					name = "helmet/signaler/prox sensor/robot arm/energy sword assembly"
					icon_state = "grievous_assembly"
					to_chat(user, span_notice("I bolt [I] onto one of [src]'s arm slots."))
					qdel(I)
					swordamt ++
				else
					if(!can_finish_build(I, user))
						return
					to_chat(user, span_notice("I complete the Securitron!...Something seems a bit wrong with it..?"))
					var/mob/living/simple_animal/bot/secbot/grievous/S = new(Tsec)
					S.name = created_name
					S.robot_arm = robot_arm
					qdel(I)
					qdel(src)
			else if(istype(I, /obj/item/screwdriver)) //deconstruct
				build_step--
				icon_state = initial(icon_state)
				to_chat(user, span_notice("I unbolt [src]'s energy swords"))
				for(var/IS in 1 to swordamt)
					new /obj/item/melee/transforming/plasmacutter/sword/saber(Tsec)
					swordamt--

//Firebot Assembly
/obj/item/bot_assembly/firebot
	name = "incomplete firebot assembly"
	desc = "A fire extinguisher with an arm attached to it."
	icon_state = "firebot_arm"
	created_name = "Firebot"

/obj/item/bot_assembly/firebot/attackby(obj/item/I, mob/user, params)
	..()
	switch(build_step)
		if(ASSEMBLY_FIRST_STEP)
			if(istype(I, /obj/item/clothing/head/hardhat/red))
				if(!user.temporarilyRemoveItemFromInventory(I))
					return
				to_chat(user,span_notice("I add the [I] to [src]!"))
				icon_state = "firebot_helmet"
				desc = "An incomplete firebot assembly with a fire helmet."
				qdel(I)
				build_step++

		if(ASSEMBLY_SECOND_STEP)
			if(isprox(I))
				if(!can_finish_build(I, user))
					return
				to_chat(user, span_notice("I add the [I] to [src]! Beep Boop!"))
				var/mob/living/simple_animal/bot/firebot/F = new(drop_location())
				F.name = created_name
				qdel(I)
				qdel(src)
