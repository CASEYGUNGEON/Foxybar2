/obj/item/projectile/bullet/dart
	name = "dart"
	icon_state = "cbbolt"
	damage = 6
	var/piercing = FALSE

/obj/item/projectile/bullet/dart/Initialize()
	. = ..()
	create_reagents(50, NO_REACT, NO_REAGENTS_VALUE)

/obj/item/projectile/bullet/dart/on_hit(atom/target, blocked = FALSE, skip = FALSE)
	if(iscarbon(target))
		var/mob/living/carbon/M = target
		if(blocked != 100) // not completely blocked
			if(M.can_inject(null, FALSE, def_zone, piercing)) // Pass the hit zone to see if it can inject by whether it hit the head or the body.
				..()
				if(skip == TRUE)
					return BULLET_ACT_HIT
				reagents.reaction(M, INJECT)
				reagents.trans_to(M, reagents.total_volume)
				return TRUE
			else
				blocked = 100
				target.visible_message(span_danger("\The [src] was deflected!"), \
									   span_userdanger("I were protected against \the [src]!"))

	..(target, blocked)
	DISABLE_BITFIELD(reagents.reagents_holder_flags, NO_REACT)
	reagents.handle_reactions()
	return BULLET_ACT_HIT

/obj/item/projectile/bullet/dart/piercing
	piercing = TRUE

/obj/item/projectile/bullet/dart/metalfoam/Initialize()
	. = ..()
	reagents.add_reagent(/datum/reagent/aluminium, 15)
	reagents.add_reagent(/datum/reagent/foaming_agent, 5)
	reagents.add_reagent(/datum/reagent/toxin/acid, 5)

/obj/item/projectile/bullet/dart/syringe
	name = "syringe"
	icon_state = "syringeproj"

//I am in a mess of my own making
/obj/item/projectile/bullet/dart/syringe/dart
	name = "Smartdart"
	icon_state = "dartproj"
	damage = 0
	var/emptrig = FALSE

/obj/item/projectile/bullet/dart/syringe/dart/on_hit(atom/target, blocked = FALSE)
	if(iscarbon(target))
		var/mob/living/carbon/M = target
		if(blocked != 100)
			if(M.can_inject(null, FALSE, def_zone, piercing)) // Pass the hit zone to see if it can inject by whether it hit the head or the body.
				..(target, blocked, TRUE)
				for(var/datum/reagent/medicine/R in reagents.reagent_list) //OD prevention time!
					if(M.reagents.has_reagent(R.type))
						if(R.overdose_threshold == 0 || emptrig == TRUE) //Is there a possible OD?
							M.reagents.add_reagent(R.type, R.volume)
						else
							var/transVol = clamp(R.volume, 0, (R.overdose_threshold - M.reagents.get_reagent_amount(R.type)) -1)
							M.reagents.add_reagent(R.type, transVol)
					else
						if(!R.overdose_threshold == 0)
							var/transVol = clamp(R.volume, 0, R.overdose_threshold-1)
							M.reagents.add_reagent(R.type, transVol)
						else
							M.reagents.add_reagent(R.type, R.volume)

				target.visible_message(span_notice("\The [src] beeps!"), span_hear("I feel a tiny prick as a smartdart embeds itself in you with a beep."))
				return BULLET_ACT_HIT
			else
				blocked = 100
				target.visible_message(span_danger("\The [src] was deflected!"), \
									   span_userdanger("I see a [src] bounce off you, booping sadly!"))

	target.visible_message(span_danger("\The [src] fails to land on target!"))
	return BULLET_ACT_BLOCK
