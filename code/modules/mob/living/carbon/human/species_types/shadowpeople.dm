#define HEART_RESPAWN_THRESHHOLD 40
#define HEART_SPECIAL_SHADOWIFY 2

/datum/species/shadow
	// Humans cursed to stay in the darkness, lest their life forces drain. They regain health in shadow and die in light.
	name = "???"
	id = "shadow"
	sexes = 0
	blacklisted = 1
	ignored_by = list(/mob/living/simple_animal/hostile/faithless)
	meat = /obj/item/reagent_containers/food/snacks/meat/slab/human/mutant/shadow
	species_traits = list(NOBLOOD,NOEYES,HAS_FLESH,HAS_BONE)
	inherent_traits = list(TRAIT_RADIMMUNE,TRAIT_VIRUSIMMUNE,TRAIT_NOBREATH)

	dangerous_existence = 1
	mutanteyes = /obj/item/organ/eyes/night_vision

	species_type = "shadow"

/datum/species/shadow/on_species_gain(mob/living/carbon/C, datum/species/old_species)
	. = ..()
	C.AddElement(/datum/element/photosynthesis, 1, 1, 0, 0, 0, 0, SHADOW_SPECIES_LIGHT_THRESHOLD, SHADOW_SPECIES_LIGHT_THRESHOLD)

/datum/species/shadow/on_species_loss(mob/living/carbon/C)
	. = ..()
	C.RemoveElement(/datum/element/photosynthesis, 1, 1, 0, 0, 0, 0, SHADOW_SPECIES_LIGHT_THRESHOLD, SHADOW_SPECIES_LIGHT_THRESHOLD)

/datum/species/shadow/check_roundstart_eligible()
//	if(SSevents.holidays && SSevents.holidays[HALLOWEEN])
//		return TRUE
	return ..()

/datum/species/shadow/nightmare
	name = "Nightmare"
	id = "nightmare"
	limbs_id = "shadow"
	burnmod = 1.5
	blacklisted = TRUE
	no_equip = list(SLOT_MASK, SLOT_WEAR_SUIT, SLOT_GLOVES, SLOT_SHOES, SLOT_W_UNIFORM, SLOT_S_STORE)
	species_traits = list(NOBLOOD,NO_UNDERWEAR,NO_DNA_COPY,NOTRANSSTING,NOEYES,NOGENITALS,NOAROUSAL)
	inherent_traits = list(TRAIT_RESISTCOLD,TRAIT_NOBREATH,TRAIT_RESISTHIGHPRESSURE,TRAIT_RESISTLOWPRESSURE,TRAIT_CHUNKYFINGERS,TRAIT_RADIMMUNE,TRAIT_VIRUSIMMUNE,TRAIT_PIERCEIMMUNE,TRAIT_NODISMEMBER,TRAIT_NOHUNGER)
	mutanteyes = /obj/item/organ/eyes/night_vision/nightmare
	mutant_organs = list(/obj/item/organ/heart/nightmare)
	mutant_brain = /obj/item/organ/brain/nightmare

	var/info_text = "I am a <span class='danger'>Nightmare</span>. The ability <span class='warning'>shadow walk</span> allows unlimited, unrestricted movement in the dark while activated. \
					Your <span class='warning'>light eater</span> will destroy any light producing objects you attack, as well as destroy any lights a living creature may be holding. You will automatically dodge gunfire and melee attacks when on a dark tile. If killed, you will eventually revive if left in darkness."

/datum/species/shadow/nightmare/on_species_gain(mob/living/carbon/C, datum/species/old_species)
	. = ..()
	to_chat(C, "[info_text]")

	C.fully_replace_character_name("[pick(GLOB.nightmare_names)]")

/datum/species/shadow/nightmare/bullet_act(obj/item/projectile/P, mob/living/carbon/human/H)
	var/turf/T = H.loc
	if(istype(T))
		var/light_amount = T.get_lumcount()
		if(light_amount < SHADOW_SPECIES_LIGHT_THRESHOLD)
			H.visible_message(span_danger("[H] dances in the shadows, evading [P]!"))
			playsound(T, "bullet_miss", 75, 1)
			return BULLET_ACT_FORCE_PIERCE
	return ..()

/datum/species/shadow/nightmare/check_roundstart_eligible()
	return FALSE

//Organs

/obj/item/organ/brain/nightmare
	name = "tumorous mass"
	desc = "A fleshy growth that was dug out of the skull of a Nightmare."
	icon_state = "brain-x-d"
	var/obj/effect/proc_holder/spell/targeted/shadowwalk/shadowwalk

/obj/item/organ/brain/nightmare/Insert(mob/living/carbon/M, special = 0, drop_if_replaced = TRUE)
	..()
	if(M.dna.species.id != "nightmare")
		M.set_species(/datum/species/shadow/nightmare)
		visible_message(span_warning("[M] thrashes as [src] takes root in [M.p_their()] body!"))
	var/obj/effect/proc_holder/spell/targeted/shadowwalk/SW = new
	M.AddSpell(SW)
	shadowwalk = SW

/obj/item/organ/brain/nightmare/Remove(special = FALSE)
	if(shadowwalk && owner)
		owner.RemoveSpell(shadowwalk)
	return ..()

/obj/item/organ/heart/nightmare
	name = "heart of darkness"
	desc = "An alien organ that twists and writhes when exposed to light."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "demon_heart-on"
	color = "#1C1C1C"
	var/respawn_progress = 0
	var/obj/item/light_eater/blade
	decay_factor = 0

/obj/item/organ/heart/nightmare/ComponentInitialize()
	. = ..()
	AddElement(/datum/element/update_icon_blocker)

/obj/item/organ/heart/nightmare/attack(mob/M, mob/living/carbon/user, obj/target)
	if(M != user)
		return ..()
	user.visible_message(span_warning("[user] raises [src] to [user.p_their()] mouth and tears into it with [user.p_their()] teeth!"), \
						span_danger("[src] feels unnaturally cold in your hands. You raise [src] your mouth and devour it!"))
	playsound(user, 'sound/magic/demon_consume.ogg', 50, 1)


	user.visible_message(span_warning("Blood erupts from [user]'s arm as it reforms into a weapon!"), \
						span_userdanger("Icy blood pumps through your veins as your arm reforms itself!"))
	user.temporarilyRemoveItemFromInventory(src, TRUE)
	Insert(user)

/obj/item/organ/heart/nightmare/Insert(mob/living/carbon/M, special = 0, drop_if_replaced = TRUE)
	..()
	if(special != HEART_SPECIAL_SHADOWIFY)
		blade = new/obj/item/light_eater
		M.put_in_hands(blade)

/obj/item/organ/heart/nightmare/Remove(special = FALSE)
	respawn_progress = 0
	if(!QDELETED(owner) && blade && special != HEART_SPECIAL_SHADOWIFY)
		owner.visible_message(span_warning("\The [blade] disintegrates!"))
		QDEL_NULL(blade)
	return ..()

/obj/item/organ/heart/nightmare/Stop()
	return 0

/obj/item/organ/heart/nightmare/on_death()
	if(!owner)
		return
	var/turf/T = get_turf(owner)
	if(istype(T))
		var/light_amount = T.get_lumcount()
		if(light_amount < SHADOW_SPECIES_LIGHT_THRESHOLD)
			respawn_progress++
			playsound(owner,'sound/effects/singlebeat.ogg',40,1)
	if(respawn_progress >= HEART_RESPAWN_THRESHHOLD)
		owner.revive(full_heal = TRUE)
		if(!(owner.dna.species.id == "shadow" || owner.dna.species.id == "nightmare"))
			var/mob/living/carbon/old_owner = owner
			Remove(HEART_SPECIAL_SHADOWIFY)
			old_owner.set_species(/datum/species/shadow)
			Insert(old_owner, HEART_SPECIAL_SHADOWIFY)
			to_chat(owner, span_userdanger("I feel the shadows invade your skin, leaping into the center of your chest! You're alive!"))
			SEND_SOUND(owner, sound('sound/effects/ghost.ogg'))
		owner.visible_message(span_warning("[owner] staggers to [owner.p_their()] feet!"))
		playsound(owner, 'sound/hallucinations/far_noise.ogg', 50, 1)
		respawn_progress = 0

//Weapon

/obj/item/light_eater
	name = "light eater" //as opposed to heavy eater
	icon_state = "arm_blade"
	item_state = "arm_blade"
	force = 25
	lefthand_file = 'icons/mob/inhands/antag/changeling_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/changeling_righthand.dmi'
	item_flags = ABSTRACT | DROPDEL
	w_class = WEIGHT_CLASS_HUGE
	sharpness = SHARP_EDGED
	total_mass = TOTAL_MASS_HAND_REPLACEMENT

/obj/item/light_eater/Initialize()
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, HAND_REPLACEMENT_TRAIT)
	AddComponent(/datum/component/butchering, 80, 70)

/obj/item/light_eater/afterattack(atom/movable/AM, mob/user, proximity)
	. = ..()
	if(!proximity)
		return
	if(isopenturf(AM))
		var/turf/open/T = AM
		if(T.light_range && !isspaceturf(T)) //no fairy grass or light tile can escape the fury of the darkness.
			to_chat(user, span_notice("I scrape away [T] with your [name] and snuff out its lights."))
			T.ScrapeAway(flags = CHANGETURF_INHERIT_AIR)
	else if(isliving(AM))
		var/mob/living/L = AM
		if(isethereal(AM))
			AM.emp_act(50)
		if(iscyborg(AM))
			var/mob/living/silicon/robot/borg = AM
			if(borg.lamp_intensity)
				borg.update_headlamp(TRUE, INFINITY)
				to_chat(borg, span_danger("My headlamp is fried! You'll need a human to help replace it."))
			for(var/obj/item/assembly/flash/cyborg/F in borg.held_items)
				if(!F.crit_fail)
					F.burn_out()
		else
			for(var/obj/item/O in AM)
				if(O.light_range && O.light_power)
					disintegrate(O)
		if(L.pulling && L.pulling.light_range && isitem(L.pulling))
			disintegrate(L.pulling)
	else if(isitem(AM))
		var/obj/item/I = AM
		if(I.light_range && I.light_power)
			disintegrate(I)

/obj/item/light_eater/proc/disintegrate(obj/item/O)
	if(istype(O, /obj/item/pda))
		var/obj/item/pda/PDA = O
		PDA.set_light(0)
		PDA.fon = FALSE
		PDA.f_lum = 0
		PDA.update_icon()
		visible_message(span_danger("The light in [PDA] shorts out!"))
	else if(istype(O, /obj/item/gun))
		var/obj/item/gun/weapon = O
		if(weapon.gun_light)
			var/obj/item/flashlight/seclite/light = weapon.gun_light
			light.forceMove(get_turf(weapon))
			light.burn()
			weapon.set_gun_light(null)
			weapon.update_gunlight()
			QDEL_NULL(weapon.alight)
			visible_message(span_danger("[light] on [O] flickers out and disintegrates!"))
	else
		visible_message(span_danger("[O] is disintegrated by [src]!"))
		O.burn()
	playsound(src, 'sound/items/welder.ogg', 50, 1)

#undef HEART_SPECIAL_SHADOWIFY
#undef HEART_RESPAWN_THRESHHOLD
