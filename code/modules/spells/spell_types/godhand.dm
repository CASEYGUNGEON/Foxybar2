/obj/item/melee/touch_attack
	name = "\improper outstretched hand"
	desc = "High Five?"
	var/catchphrase = "High Five!"
	var/on_use_sound = null
	var/obj/effect/proc_holder/spell/targeted/touch/attached_spell
	icon = 'icons/obj/items_and_weapons.dmi'
	icon_state = "syndballoon"
	item_state = null
	item_flags = NEEDS_PERMIT | ABSTRACT | DROPDEL
	w_class = WEIGHT_CLASS_HUGE
	force = 0
	throwforce = 0
	throw_range = 0
	throw_speed = 0
	var/charges = 1

/obj/item/melee/touch_attack/Initialize()
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, ABSTRACT_ITEM_TRAIT)

/obj/item/melee/touch_attack/attack(mob/target, mob/living/carbon/user)
	if(!iscarbon(user)) //Look ma, no hands
		return
	if(user.lying || user.handcuffed)
		to_chat(user, span_warning("I can't reach out!"))
		return
	..()

/obj/item/melee/touch_attack/afterattack(atom/target, mob/user, proximity)
	. = ..()
	user.say(catchphrase, forced = "spell")
	playsound(get_turf(user), on_use_sound,50,1)
	charges--
	if(charges <= 0)
		qdel(src)

/obj/item/melee/touch_attack/Destroy()
	if(attached_spell)
		attached_spell.on_hand_destroy(src)
	return ..()

/obj/item/melee/touch_attack/disintegrate
	name = "\improper disintegrating touch"
	desc = "This hand of mine glows with an awesome power!"
	catchphrase = "EI NATH!!"
	on_use_sound = 'sound/magic/disintegrate.ogg'
	icon_state = "disintegrate"
	item_state = "disintegrate"

/obj/item/melee/touch_attack/disintegrate/afterattack(atom/target, mob/living/carbon/user, proximity)
	if(!proximity || target == user || !ismob(target) || !iscarbon(user) || user.lying || user.handcuffed) //exploding after touching yourself would be bad
		return
	if(!user.can_speak_vocal())
		to_chat(user, span_notice("I can't get the words out!"))
		return
	var/mob/M = target
	do_sparks(4, FALSE, M.loc)
	for(var/mob/living/L in view(src, 7))
		if(L != user)
			L.flash_act(affect_silicon = FALSE)
	var/atom/A = M.anti_magic_check()
	if(A)
		if(isitem(A))
			target.visible_message(span_warning("[target]'s [A] glows brightly as it wards off the spell!"))
		user.visible_message(span_warning("The feedback blows [user]'s arm off!"),span_userdanger("The spell bounces from [M]'s skin back into your arm!"))
		user.flash_act()
		var/obj/item/bodypart/part = user.get_holding_bodypart_of_item(src)
		if(part)
			part.dismember()
		return ..()
	M.gib()
	return ..()

/obj/item/melee/touch_attack/fleshtostone
	name = "\improper petrifying touch"
	desc = "That's the bottom line, because flesh to stone said so!"
	catchphrase = "STAUN EI!!"
	on_use_sound = 'sound/magic/fleshtostone.ogg'
	icon_state = "fleshtostone"
	item_state = "fleshtostone"

/obj/item/melee/touch_attack/fleshtostone/afterattack(atom/target, mob/living/carbon/user, proximity)
	if(!proximity || target == user || !isliving(target) || !iscarbon(user) || user.lying || user.handcuffed) //getting hard after touching yourself would also be bad
		return
	if(user.lying || user.handcuffed)
		to_chat(user, span_warning("I can't reach out!"))
		return
	if(!user.can_speak_vocal())
		to_chat(user, span_notice("I can't get the words out!"))
		return
	var/mob/living/M = target
	if(M.anti_magic_check())
		to_chat(user, span_warning("The spell can't seem to affect [M]!"))
		to_chat(M, span_warning("I feel your flesh turn to stone for a moment, then revert back!"))
		..()
		return
	M.Stun(40)
	M.petrify()
	return ..()

/obj/item/melee/touch_attack/nuclearfist
	name = "\improper PURE MANLINESS"
	desc = "SHOW THEM RAW POWER"
	catchphrase = "I CAST FIST!"
	on_use_sound = 'sound/weapons/nuclear_fist.ogg'
	icon_state = "disintegrate"
	item_state = "disintegrate"

/obj/item/melee/touch_attack/nuclearfist/afterattack(atom/movable/target, mob/living/carbon/user, proximity)
	if(!proximity || target == user || !ismob(target) || !iscarbon(user) || user.lying || user.handcuffed) //exploding after touching yourself would be bad
		return
	if(!user.can_speak_vocal())
		to_chat(user, span_notice("I can't get the words out!"))
		return
	var/mob/M = target
	var/atom/A = M.anti_magic_check()
	if(A)
		if(isitem(A))
			target.visible_message(span_warning("[target]'s [A] glows brightly as it wards off the spell!"))
		user.visible_message(span_warning("The feedback blows [user]'s arm off!"),span_userdanger("The spell bounces from [M]'s skin back into your arm!"))
		user.flash_act()
		var/obj/item/bodypart/part = user.get_holding_bodypart_of_item(src)
		if(part)
			part.dismember()
		return ..()
	var/angle = dir2angle(get_dir(src, get_step_away(target, src)))
	var/obj/item/projectile/magic/nuclear/P = new(get_turf(src))
	P.victim = target
	target.forceMove(P)
	P.setAngle(angle)
	P.original = user
	P.firer = user
	P.fire()
	return ..()
