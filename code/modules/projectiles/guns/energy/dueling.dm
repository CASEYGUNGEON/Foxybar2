#define DUEL_IDLE 1
#define DUEL_PREPARATION 2
#define DUEL_READY 3
#define DUEL_COUNTDOWN 4
#define DUEL_FIRING 5

//paper rock scissors
#define DUEL_SETTING_A "wide"
#define DUEL_SETTING_B "cone"
#define DUEL_SETTING_C "pinpoint"

#define DUEL_HUGBOX_NONE 0			//dismember head
#define DUEL_HUGBOX_LETHAL 1		//200 damage to chest
#define DUEL_HUGBOX_NONLETHAL 2		//stamcrit

/datum/duel
	var/obj/item/gun/energy/dueling/gun_A
	var/obj/item/gun/energy/dueling/gun_B
	var/state = DUEL_IDLE
	var/required_distance = 5
	var/list/confirmations = list()
	var/list/fired = list()
	var/countdown_length = 10
	var/countdown_step = 0
	var/static/next_id = 1
	var/id

/datum/duel/New()
	id = next_id++

/datum/duel/Destroy()
	if(gun_A)
		gun_A.duel = null
		gun_A = null
	if(gun_B)
		gun_B.duel = null
		gun_B = null
	STOP_PROCESSING(SSobj, src)
	. = ..()

/datum/duel/proc/try_begin()
	//Check if both guns are held and if so begin.
	var/mob/living/A = get_duelist(gun_A)
	var/mob/living/B = get_duelist(gun_B)
	if(!A || !B)
		message_duelists(span_warning("To begin the duel, both participants need to be holding paired dueling pistols."))
		return
	begin()

/datum/duel/proc/begin()
	state = DUEL_PREPARATION
	confirmations.Cut()
	fired.Cut()
	countdown_step = countdown_length

	message_duelists(span_notice("Set your gun setting and move [required_distance] steps away from your opponent."))

	START_PROCESSING(SSobj, src)

/datum/duel/proc/get_duelist(obj/item/gun/energy/dueling/G)
	var/mob/living/L = G.loc
	if(!istype(L) || !L.is_holding(G))
		return
	return L

/datum/duel/proc/message_duelists(message)
	var/mob/living/LA = get_duelist(gun_A)
	if(LA)
		to_chat(LA,message)
	var/mob/living/LB = get_duelist(gun_B)
	if(LB)
		to_chat(LB,message)

/datum/duel/proc/other_gun(obj/item/gun/energy/dueling/G)
	return G == gun_A ? gun_B : gun_A

/datum/duel/proc/end()
	message_duelists(span_notice("Duel finished. Re-engaging safety."))
	STOP_PROCESSING(SSobj, src)
	state = DUEL_IDLE

/datum/duel/process()
	switch(state)
		if(DUEL_PREPARATION)
			if(check_positioning())
				confirm_positioning()
			else if (!get_duelist(gun_A) && !get_duelist(gun_B))
				end()
		if(DUEL_READY)
			if(!check_positioning())
				back_to_prep()
			else if(confirmations.len == 2)
				confirm_ready()
		if(DUEL_COUNTDOWN)
			if(!check_positioning())
				back_to_prep()
			else
				countdown_step()
		if(DUEL_FIRING)
			if(check_fired())
				end()

/datum/duel/proc/back_to_prep()
	message_duelists(span_notice("Positions invalid. Please move to valid positions [required_distance] steps aways from each other to continue."))
	state = DUEL_PREPARATION
	confirmations.Cut()
	countdown_step = countdown_length

/datum/duel/proc/confirm_positioning()
	message_duelists(span_notice("Position confirmed. Confirm readiness by pulling the trigger once."))
	state = DUEL_READY

/datum/duel/proc/confirm_ready()
	message_duelists(span_notice("Readiness confirmed. Starting countdown. Commence firing at zero mark."))
	state = DUEL_COUNTDOWN

/datum/duel/proc/countdown_step()
	countdown_step--
	if(countdown_step == 0)
		state = DUEL_FIRING
		message_duelists(span_userdanger("Fire!"))
	else
		message_duelists(span_userdanger("[countdown_step]!"))

/datum/duel/proc/check_fired()
	if(fired.len == 2)
		return TRUE
	//Let's say if gun was dropped/stowed the user is finished
	if(!get_duelist(gun_A))
		return TRUE
	if(!get_duelist(gun_B))
		return TRUE
	return FALSE

/datum/duel/proc/check_positioning()
	var/mob/living/A = get_duelist(gun_A)
	var/mob/living/B = get_duelist(gun_B)
	if(!A || !B)
		return FALSE
	if(!isturf(A.loc) || !isturf(B.loc))
		return FALSE
	if(get_dist(A, B) != required_distance)
		return FALSE
	for(var/i in getline(A.loc, B.loc))
		var/turf/T = i
		if(is_blocked_turf(T, TRUE))
			return FALSE
	return TRUE

/obj/item/gun/energy/dueling
	name = "dueling pistol"
	desc = "High-tech dueling pistol. Launches chaff and projectile according to preset settings."
	icon_state = "dueling_pistol"
	item_state = "gun"
	ammo_x_offset = 2
	weapon_class = WEAPON_CLASS_SMALL
	ammo_type = list(/obj/item/ammo_casing/energy/duel)
	automatic_charge_overlays = FALSE
	var/unlocked = FALSE
	var/setting = DUEL_SETTING_A
	var/datum/duel/duel
	var/mutable_appearance/setting_overlay
	var/hugbox = DUEL_HUGBOX_NONE

/obj/item/gun/energy/dueling/hugbox
	hugbox = DUEL_HUGBOX_LETHAL

/obj/item/gun/energy/dueling/hugbox/stamina
	hugbox = DUEL_HUGBOX_NONLETHAL

/obj/item/gun/energy/dueling/Initialize()
	. = ..()
	setting_overlay = mutable_appearance(icon,setting_iconstate())
	add_overlay(setting_overlay)

/obj/item/gun/energy/dueling/examine(mob/user)
	. = ..()
	if(duel)
		. += "Its linking number is [duel.id]."
	else
		. += "ERROR: No linking number on gun."

/obj/item/gun/energy/dueling/proc/setting_iconstate()
	switch(setting)
		if(DUEL_SETTING_A)
			return "duel_red"
		if(DUEL_SETTING_B)
			return "duel_green"
		if(DUEL_SETTING_C)
			return "duel_blue"
	return "duel_red"

/obj/item/gun/energy/dueling/attack_self(mob/living/user)
	if(duel.state == DUEL_IDLE)
		duel.try_begin()
	else
		toggle_setting(user)

/obj/item/gun/energy/dueling/proc/toggle_setting(mob/living/user)
	switch(setting)
		if(DUEL_SETTING_A)
			setting = DUEL_SETTING_B
		if(DUEL_SETTING_B)
			setting = DUEL_SETTING_C
		if(DUEL_SETTING_C)
			setting = DUEL_SETTING_A
	to_chat(user,span_notice("I switch [src] setting to [setting] mode."))
	update_icon()

/obj/item/gun/energy/dueling/update_overlays(force_update)
	. = ..()
	if(setting_overlay)
		setting_overlay.icon_state = setting_iconstate()
		. += setting_overlay

/obj/item/gun/energy/dueling/Destroy()
	if(duel)
		qdel(duel)
	return ..()

/obj/item/gun/energy/dueling/can_trigger_gun(mob/living/user)
	. = ..()
	switch(duel.state)
		if(DUEL_FIRING)
			return . && !duel.fired[src]
		if(DUEL_READY)
			return .
		else
			to_chat(user,span_warning("[src] is locked. Wait for FIRE signal before shooting."))
			return FALSE

/obj/item/gun/energy/dueling/proc/is_duelist(mob/living/L)
	if(!istype(L))
		return FALSE
	if(!L.is_holding(duel.other_gun(src)))
		return FALSE
	return TRUE

/obj/item/gun/energy/dueling/process_fire(atom/target, mob/living/user, message, params, zone_override, bonus_spread = 0, stam_cost = 0)
	if(duel.state == DUEL_READY)
		duel.confirmations[src] = TRUE
		to_chat(user,span_notice("I confirm your readiness."))
	else if(!is_duelist(target)) //I kinda want to leave this out just to see someone shoot a bystander or missing.
		to_chat(user,span_warning("[src] safety system prevents shooting anyone but your designated opponent."))
	else
		duel.fired[src] = TRUE
		. = ..()

/obj/item/gun/energy/dueling/before_firing(target,user)
	var/obj/item/ammo_casing/energy/duel/D = chambered
	D.setting = setting
	D.hugbox = hugbox

/obj/effect/temp_visual/dueling_chaff
	icon = 'icons/effects/effects.dmi'
	icon_state = "shield-old"
	duration = 30
	var/setting

/obj/effect/temp_visual/dueling_chaff/update_icon()
	. = ..()
	switch(setting)
		if(DUEL_SETTING_A)
			color = "red"
		if(DUEL_SETTING_B)
			color = "green"
		if(DUEL_SETTING_C)
			color = "blue"

//Casing

/obj/item/ammo_casing/energy/duel
	e_cost = 0
	projectile_type = /obj/item/projectile/energy/duel
	var/setting
	var/hugbox = DUEL_HUGBOX_NONE

/obj/item/ammo_casing/energy/duel/ready_proj(atom/target, mob/living/user, quiet, zone_override)
	. = ..()
	var/obj/item/projectile/energy/duel/D = BB
	D.setting = setting
	D.hugbox = hugbox
	D.update_icon()

/obj/item/ammo_casing/energy/duel/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, damage_multiplier, penetration_multiplier, projectile_speed_multiplier, atom/fired_from)
	. = ..()
	var/obj/effect/temp_visual/dueling_chaff/C = new(get_turf(user))
	C.setting = setting
	C.update_icon()

//Projectile

/obj/item/projectile/energy/duel
	name = "dueling beam"
	icon_state = "declone"
	is_reflectable = FALSE
	homing = TRUE
	var/setting
	var/hugbox = DUEL_HUGBOX_NONE

/obj/item/projectile/energy/duel/update_icon()
	. = ..()
	switch(setting)
		if(DUEL_SETTING_A)
			color = "red"
		if(DUEL_SETTING_B)
			color = "green"
		if(DUEL_SETTING_C)
			color = "blue"

/obj/item/projectile/energy/duel/on_hit(atom/target, blocked)
	. = ..()
	var/turf/T = get_turf(target)
	var/obj/effect/temp_visual/dueling_chaff/C = locate() in T
	if(C)
		var/counter_setting
		switch(setting)
			if(DUEL_SETTING_A)
				counter_setting = DUEL_SETTING_B
			if(DUEL_SETTING_B)
				counter_setting = DUEL_SETTING_C
			if(DUEL_SETTING_C)
				counter_setting = DUEL_SETTING_A
		if(C.setting == counter_setting)
			return BULLET_ACT_BLOCK

	if(!isliving(target))
		return BULLET_ACT_BLOCK

	var/mob/living/L = target
	switch(hugbox)
		if(DUEL_HUGBOX_NONE)
			var/obj/item/bodypart/B = L.get_bodypart(BODY_ZONE_HEAD)
			B.dismember()
			QDEL_IN(B, 1)
		if(DUEL_HUGBOX_LETHAL)
			L.adjustBruteLoss(180)
			L.death()				//Die, powergamers.
		if(DUEL_HUGBOX_NONLETHAL)
			L.adjustStaminaLoss(200, forced = TRUE)		//Die, powergamers x 2
			L.Paralyze(100)	//For good measure.

//Storage case.
/obj/item/storage/lockbox/dueling
	name = "dueling pistol case"
	desc = "Let's solve this like gentlespacemen."
	icon_state = "medalbox+l"
	item_state = "syringe_kit"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	req_access = list(ACCESS_CAPTAIN)
	icon_locked = "medalbox+l"
	icon_closed = "medalbox"
	icon_broken = "medalbox+b"
	var/gun_type = /obj/item/gun/energy/dueling

/obj/item/storage/lockbox/dueling/ComponentInitialize()
	. = ..()
	var/datum/component/storage/STR = GetComponent(/datum/component/storage)
	STR.max_w_class = WEIGHT_CLASS_SMALL
	STR.max_items = 2
	STR.can_hold = typecacheof(/obj/item/gun/energy/dueling)

/obj/item/storage/lockbox/dueling/update_icon_state()
	var/locked = SEND_SIGNAL(src, COMSIG_IS_STORAGE_LOCKED)
	if(locked)
		icon_state = "medalbox+l"
	else
		icon_state = "medalbox"
		if(open)
			icon_state += "open"
		if(broken)
			icon_state += "+b"

/obj/item/storage/lockbox/dueling/PopulateContents()
	. = ..()
	var/obj/item/gun/energy/dueling/gun_A = new gun_type(src)
	var/obj/item/gun/energy/dueling/gun_B = new gun_type(src)
	var/datum/duel/D = new
	gun_A.duel = D
	gun_B.duel = D
	D.gun_A = gun_A
	D.gun_B = gun_B

/obj/item/storage/lockbox/dueling/hugbox
	gun_type = /obj/item/gun/energy/dueling/hugbox
	req_access = null

/obj/item/storage/lockbox/dueling/hugbox/stamina
	gun_type = /obj/item/gun/energy/dueling/hugbox/stamina
	req_access = null
