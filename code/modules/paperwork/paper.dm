/**
 * Paper
 * also scraps of paper
 *
 * lipstick wiping is in code/game/objects/items/weapons/cosmetics.dm!
 */
#define MAX_PAPER_LENGTH 5000
#define MAX_PAPER_STAMPS 30		// Too low?
#define MAX_PAPER_STAMPS_OVERLAYS 4
#define MODE_READING 0
#define MODE_WRITING 1
#define MODE_STAMPING 2


/**
 * Paper is now using markdown (like in github pull notes) for ALL rendering
 * so we do loose a bit of functionality but we gain in easy of use of
 * paper and getting rid of that crashing bug
 */
/obj/item/paper
	name = "paper"
	gender = NEUTER
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	item_state = "paper"
	// inhand_icon_state = "paper"
	// worn_icon_state = "paper"
	// custom_fire_overlay = "paper_onfire_overlay"
	throwforce = 0
	w_class = WEIGHT_CLASS_TINY
	throw_range = 1
	throw_speed = 1
	pressure_resistance = 0
	slot_flags = INV_SLOTBIT_HEAD
	body_parts_covered = HEAD
	resistance_flags = FLAMMABLE
	max_integrity = 50
	dog_fashion = /datum/dog_fashion/head
	// drop_sound = 'sound/items/handling/paper_drop.ogg'
	// pickup_sound =  'sound/items/handling/paper_pickup.ogg'
	grind_results = list(/datum/reagent/cellulose = 3)
	color = "white"
	/// What's actually written on the paper.
	var/info = ""
	var/show_written_words = TRUE

	/// The (text for the) stamps on the paper.
	var/list/stamps			/// Positioning for the stamp in tgui
	var/list/stamped		/// Overlay info

	var/contact_poison // Reagent ID to transfer on contact
	var/contact_poison_volume = 0

	/// When the sheet can be "filled out"
	/// This is an associated list
	var/list/form_fields = list()
	var/field_counter = 1
	var/pers_id

/obj/item/paper/Destroy()
	stamps = null
	stamped = null
	form_fields = null
	stamped = null
	. = ..()

/obj/item/paper/proc/SaveData()
	if(!pers_id)
		return

	var/list/dat = list()
	dat["name"] = name
	//dat["icon"] = icon
	dat["icon_state"] = icon_state
	dat["info"] = info
	dat["color"] = color
	dat["stamps"] = stamps
	dat["stamped"] = stamped
	dat["form_fields"] = form_fields
	dat["field_counter"] = field_counter

	return dat

/obj/item/paper/proc/LoadData(list/dat)
	if(!dat.len)
		return FALSE
	
	name = dat["name"]
	//icon = dat["icon"]
	icon_state = dat["icon_state"]
	info = dat["info"]
	color = dat["color"]
	stamps = dat["stamps"]
	stamped = dat["stamped"]
	form_fields = dat["form_fields"]
	field_counter = dat["field_counter"]

	return TRUE
/**
 * This proc copies this sheet of paper to a new
 * sheet,  Makes it nice and easy for carbon and
 * the copyer machine
 */
/obj/item/paper/proc/copy()
	var/obj/item/paper/N = new(arglist(args))
	N.info = info
	N.color = color
	N.update_icon_state()
	N.stamps = stamps
	N.stamped = stamped.Copy()
	N.form_fields = form_fields.Copy()
	N.field_counter = field_counter
	copy_overlays(N, TRUE)
	return N

/**
 * This proc sets the text of the paper and updates the
 * icons.  You can modify the pen_color after if need
 * be.
 */
/obj/item/paper/proc/setText(text)
	info = text
	form_fields = null
	field_counter = 0
	update_icon_state()

/obj/item/paper/pickup(user)
	if(contact_poison && ishuman(user))
		var/mob/living/carbon/human/H = user
		var/obj/item/clothing/gloves/G = H.gloves
		if(!istype(G) || G.transfer_prints)
			H.reagents.add_reagent(contact_poison,contact_poison_volume)
			contact_poison = null
	. = ..()

/obj/item/paper/Initialize()
	. = ..()
	pixel_y = rand(-8, 8)
	pixel_x = rand(-9, 9)
	update_icon()

/obj/item/paper/update_icon_state()
	if(info && show_written_words)
		icon_state = "[initial(icon_state)]_words"

/obj/item/paper/verb/rename()
	set name = "Rename paper"
	set category = "Object"
	set src in usr

	if(!usr.can_read(src) || usr.incapacitated(TRUE, TRUE) || (isobserver(usr) && !IsAdminGhost(usr)))
		return
	if(ishuman(usr))
		var/mob/living/carbon/human/H = usr
		if(HAS_TRAIT(H, TRAIT_CLUMSY) && prob(25))
			to_chat(H, span_warning("I cut yourself on the paper! Ahhhh! Ahhhhh!"))
			H.damageoverlaytemp = 9001
			H.update_damage_hud()
			return
	var/n_name = stripped_input(usr, "What would you like to label the paper?", "Paper Labelling", null, MAX_NAME_LEN)
	if((loc == usr && usr.stat == CONSCIOUS))
		name = "paper[(n_name ? text("- '[n_name]'") : null)]"
	add_fingerprint(usr)

/obj/item/paper/proc/clearpaper()
	info = ""
	stamps = null
	LAZYCLEARLIST(stamped)
	cut_overlays()
	update_icon_state()

/obj/item/paper/examine(mob/user)
	. = ..()
	if(!in_range(user, src) && !isobserver(user))
		. += span_warning("You're too far away to read it!")
		return
	if(user.can_read(src))
		ui_interact(user)
		return
	. += span_warning("I cannot read it!")

/obj/item/paper/ui_status(mob/user,/datum/ui_state/state)
		// Are we on fire?  Hard ot read if so
	if(resistance_flags & ON_FIRE)
		return UI_CLOSE
	if(!in_range(user,src))
		return UI_CLOSE
	if(user.incapacitated(TRUE, TRUE) || (isobserver(user) && !IsAdminGhost(user)))
		return UI_UPDATE
	// Even harder to read if your blind...braile? humm
	// .. or if you cannot read
	if(!user.can_read(src))
		return UI_CLOSE
	if(in_contents_of(/obj/machinery/door/airlock))
		return UI_INTERACTIVE
	return ..()



/obj/item/paper/can_interact(mob/user)
	if(in_contents_of(/obj/machinery/door/airlock) || in_contents_of(/obj/structure/noticeboard))
		return TRUE
	return ..()


/obj/item/proc/burn_paper_product_attackby_check(obj/item/I, mob/living/user, bypass_clumsy)
	var/ignition_message = I.ignition_effect(src, user)
	if(!ignition_message)
		return
	. = TRUE
	if(!bypass_clumsy && HAS_TRAIT(user, TRAIT_CLUMSY) && prob(10) && Adjacent(user))
		user.visible_message(span_warning("[user] accidentally ignites [user.p_them()]self!"), \
							span_userdanger("I miss [src] and accidentally light yourself on fire!"))
		if(user.is_holding(I)) //checking if they're holding it in case TK is involved
			user.dropItemToGround(I)
		user.adjust_fire_stacks(1)
		user.IgniteMob()
		return

	if(user.is_holding(src)) //no TK shit here.
		user.dropItemToGround(src)
	user.visible_message(ignition_message)
	add_fingerprint(user)
	fire_act(I.get_temperature())

/obj/item/paper/attackby(obj/item/P, mob/living/user, params)
	if(burn_paper_product_attackby_check(P, user))
		SStgui.close_uis(src)
		return

	if(istype(P, /obj/item/pen) || istype(P, /obj/item/toy/crayon))
		if(length(info) >= MAX_PAPER_LENGTH) // Sheet must have less than 1000 charaters
			to_chat(user, span_warning("This sheet of paper is full!"))
			return
		ui_interact(user)
		return
	else if(istype(P, /obj/item/stamp))
		to_chat(user, span_notice("I ready your stamp over the paper! "))
		ui_interact(user)
		return /// Normaly you just stamp, you don't need to read the thing
	else
		// cut paper?  the sky is the limit!
		ui_interact(user)	// The other ui will be created with just read mode outside of this

	return ..()


/obj/item/paper/fire_act(exposed_temperature, exposed_volume)
	. = ..()
	if(.)
		info = "[stars(info)]"

/obj/item/paper/ui_assets(mob/user)
	return list(
		get_asset_datum(/datum/asset/spritesheet/simple/paper),
	)

/obj/item/paper/ui_interact(mob/user, datum/tgui/ui)
	// Update the UI
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PaperSheet", name)
		ui.open()


/obj/item/paper/ui_static_data(mob/user)
	. = list()
	.["text"] = info
	.["max_length"] = MAX_PAPER_LENGTH
	.["paper_color"] = !color || color == "white" ? "#FFFFFF" : color	// color might not be set
	.["paper_state"] = icon_state	/// TODO: show the sheet will bloodied or crinkling?
	.["stamps"] = stamps



/obj/item/paper/ui_data(mob/user)
	var/list/data = list()
	var/obj/O = user.get_active_held_item()
	if(istype(O, /obj/item/toy/crayon))
		var/obj/item/toy/crayon/PEN = O
		data["pen_font"] = CRAYON_FONT
		data["pen_color"] = PEN.paint_color
		data["edit_mode"] = MODE_WRITING
		data["is_crayon"] = TRUE
		data["stamp_class"] = "FAKE"
		data["stamp_icon_state"] = "FAKE"
	else if(istype(O, /obj/item/pen))
		var/obj/item/pen/PEN = O
		data["pen_font"] = PEN.font
		data["pen_color"] = PEN.colour
		data["edit_mode"] = MODE_WRITING
		data["is_crayon"] = FALSE
		data["stamp_class"] = "FAKE"
		data["stamp_icon_state"] = "FAKE"
	else if(istype(O, /obj/item/stamp))
		var/datum/asset/spritesheet/sheet = get_asset_datum(/datum/asset/spritesheet/simple/paper)
		data["stamp_icon_state"] = O.icon_state
		data["stamp_class"] = sheet.icon_class_name(O.icon_state)
		data["edit_mode"] = MODE_STAMPING
		data["pen_font"] = "FAKE"
		data["pen_color"] = "FAKE"
		data["is_crayon"] = FALSE
	else
		data["edit_mode"] = MODE_READING
		data["pen_font"] = "FAKE"
		data["pen_color"] = "FAKE"
		data["is_crayon"] = FALSE
		data["stamp_icon_state"] = "FAKE"
		data["stamp_class"] = "FAKE"
	data["field_counter"] = field_counter
	data["form_fields"] = form_fields

	return data

/obj/item/paper/ui_act(action, params,datum/tgui/ui)
	if(..())
		return
	switch(action)
		if("stamp")
			var/stamp_x = text2num(params["x"])
			var/stamp_y = text2num(params["y"])
			var/stamp_r = text2num(params["r"])	// rotation in degrees
			var/stamp_icon_state = params["stamp_icon_state"]
			var/stamp_class = params["stamp_class"]
			if (isnull(stamps))
				stamps = list()
			if(stamps.len < MAX_PAPER_STAMPS)
				// I hate byond when dealing with freaking lists
				stamps[++stamps.len] = list(stamp_class, stamp_x, stamp_y, stamp_r)	/// WHHHHY

				/// This does the overlay stuff
				if (isnull(stamped))
					stamped = list()
				if(stamped.len < MAX_PAPER_STAMPS_OVERLAYS)
					var/mutable_appearance/stampoverlay = mutable_appearance('icons/obj/bureaucracy.dmi', "paper_[stamp_icon_state]")
					stampoverlay.pixel_x = rand(-2, 2)
					stampoverlay.pixel_y = rand(-3, 2)
					add_overlay(stampoverlay)
					LAZYADD(stamped, stamp_icon_state)

				update_static_data(usr,ui)
				ui.user.visible_message(span_notice("[ui.user] stamps [src] with [stamp_class]!"), span_notice("I stamp [src] with [stamp_class]!"))
			else
				to_chat(usr, pick("I try to stamp but you miss!", "There is no where else you can stamp!"))
			. = TRUE

		if("save")
			var/in_paper = params["text"]
			var/paper_len = length(in_paper)
			field_counter = params["field_counter"] ? text2num(params["field_counter"]) : field_counter

			if(paper_len > MAX_PAPER_LENGTH)
				// Side note, the only way we should get here is if
				// the javascript was modified, somehow, outside of
				// byond.  but right now we are logging it as
				// the generated html might get beyond this limit
				log_paper("[key_name(ui.user)] writing to paper [name], and overwrote it by [paper_len-MAX_PAPER_LENGTH]")
			if(paper_len == 0)
				to_chat(ui.user, pick("Writing block strikes again!", "I forgot to write anthing!"))
			else
				log_paper("[key_name(ui.user)] writing to paper [name]")
				if(info != in_paper)
					to_chat(ui.user, "I have added to your paper masterpiece!");
					info = in_paper
					update_static_data(usr,ui)


			update_icon()
			. = TRUE

/**
 * Construction paper
 */
/obj/item/paper/construction

/obj/item/paper/construction/Initialize()
	. = ..()
	color = pick("FF0000", "#33cc33", "#ffb366", "#551A8B", "#ff80d5", "#4d94ff")

/**
 * Natural paper
 */
/obj/item/paper/natural/Initialize()
	. = ..()
	color = "#FFF5ED"

/obj/item/paper/crumpled
	name = "paper scrap"
	icon_state = "scrap"
	slot_flags = null
	show_written_words = FALSE

/obj/item/paper/crumpled/update_icon_state()
	return

/obj/item/paper/crumpled/bloody
	icon_state = "scrap_bloodied"

/obj/item/paper/crumpled/muddy
	icon_state = "scrap_mud"

/obj/item/paper/report_card
	var/grade = "F" // See me after class
	
/obj/item/paper/report_card/ComponentInitialize()
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_GET_VALUE, PROC_REF(fridge_report_card_get_value))

/obj/item/paper/report_card/proc/fridge_report_card_get_value()
	switch(grade)
		if("P")
			return COINS_TO_CREDITS(2500)
		if("S")
			return COINS_TO_CREDITS(1000) // we're going out for frosty chocolate milkshakes
		if("A+")
			return COINS_TO_CREDITS(250)
		if("A")
			return COINS_TO_CREDITS(200)
		if("A-")
			return COINS_TO_CREDITS(175)
		if("B+")
			return COINS_TO_CREDITS(75)
		if("B")
			return COINS_TO_CREDITS(50)
		if("B-")
			return COINS_TO_CREDITS(10)
		if("C+")
			return COINS_TO_CREDITS(5)
		if("C")
			return COINS_TO_CREDITS(1)
		else
			return COINS_TO_CREDITS(1) // If I get a 75% or below, I dont pass, and neither will you

/obj/item/paper/supplyreport
	var/costvalue = 0 // See me after class
	
/obj/item/paper/supplyreport/ComponentInitialize()
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_GET_VALUE, PROC_REF(getcostvalue))

/obj/item/paper/supplyreport/proc/getcostvalue()
	return costvalue


#undef MAX_PAPER_LENGTH
#undef MAX_PAPER_STAMPS
#undef MAX_PAPER_STAMPS_OVERLAYS
#undef MODE_READING
#undef MODE_WRITING
#undef MODE_STAMPING
