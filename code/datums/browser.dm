/datum/browser
	var/mob/user
	var/title
	var/window_id // window_id is used as the window name for browse and onclose
	var/width = 0
	var/height = 0
	var/atom/ref = null
	var/window_options = "focus=0;can_close=1;can_minimize=1;can_maximize=0;can_resize=1;titlebar=1;" // window option is set using window_id
	var/stylesheets[0]
	var/scripts[0]
	var/title_image
	var/head_elements
	var/body_elements
	var/head_content = ""
	var/content = ""


/datum/browser/New(nuser, nwindow_id, ntitle = 0, nwidth = 0, nheight = 0, atom/nref = null)

	user = nuser
	window_id = nwindow_id
	if (ntitle)
		title = format_text(ntitle)
	if (nwidth)
		width = nwidth
	if (nheight)
		height = nheight
	if (nref)
		ref = nref
	add_stylesheet("common", 'html/browser/common.css') // this CSS sheet is common to all UIs

/datum/browser/proc/add_head_content(nhead_content)
	head_content = nhead_content

/datum/browser/proc/set_window_options(nwindow_options)
	window_options = nwindow_options

/datum/browser/proc/set_title_image(ntitle_image)
	//title_image = ntitle_image

/datum/browser/proc/add_stylesheet(name, file)
	stylesheets[name] = file

/datum/browser/proc/add_script(name, file)
	scripts[name] = file

/datum/browser/proc/set_content(ncontent)
	content = entity_ja(ncontent)

/datum/browser/proc/add_content(ncontent)
	content += entity_ja(ncontent)

/datum/browser/proc/get_header()
	var/key
	var/filename
	for (key in stylesheets)
		filename = "[ckey(key)].css"
		user << browse_rsc(stylesheets[key], filename)
		head_content += "<link rel='stylesheet' type='text/css' href='[filename]'>"

	for (key in scripts)
		filename = "[ckey(key)].js"
		user << browse_rsc(scripts[key], filename)
		head_content += "<script type='text/javascript' src='[filename]'></script>"

	var/title_attributes = "class='uiTitle'"
	if (title_image)
		title_attributes = "class='uiTitle icon' style='background-image: url([title_image]);'"

	return {"<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
	<meta http-equiv="Content-Type" content="text/html; charset=windows-1251">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<head>
		[head_content]
	</head>
	<body scroll=auto>
		<div class='uiWrapper'>
			[title ? "<div class='uiTitleWrapper'><div [title_attributes]><tt>[title]</tt></div></div>" : ""]
			<div class='uiContent'>
	"}

/datum/browser/proc/get_footer()
	return {"
			</div>
		</div>
		<script>
			document.body.innerHTML = document.body.innerHTML.replace(/�/g, "�");<!-- omg its so weird --!>
		</script>
	</body>
</html>"}

/datum/browser/proc/get_content()
	return {"
	[get_header()]
	[content]
	[get_footer()]
	"}
//"
/datum/browser/proc/open(use_onclose = 1)
	var/window_size = ""
	if (width && height)
		window_size = "size=[width]x[height];"
	user << browse(get_content(), "window=[window_id];[window_size][window_options]")
	if (use_onclose)
		onclose(user, window_id, ref)

/datum/browser/proc/close()
	user << browse(null, "window=[window_id]")

/datum/browser/modal
	var/opentime = 0
	var/timeout
	var/selectedbutton = 0
	var/stealfocus

/datum/browser/modal/New(nuser, nwindow_id, ntitle = 0, nwidth = 0, nheight = 0, atom/nref = null, StealFocus = TRUE, Timeout = 6000)
	..()
	stealfocus = StealFocus
	if (!StealFocus)
		window_options += "focus=false;"
	timeout = Timeout

/datum/browser/modal/close()
	. = ..()
	opentime = 0

/datum/browser/modal/open()
	set waitfor = 0
	opentime = world.time

	if (stealfocus)
		. = ..(use_onclose = 1)
	else
		var/focusedwindow = winget(user, null, "focus")
		. = ..(use_onclose = 1)

		//waits for the window to show up client side before attempting to un-focus it
		//winexists sleeps until it gets a reply from the client, so we don't need to bother sleeping
		for (var/i in 1 to 10)
			if (user && winexists(user, window_id))
				if (focusedwindow)
					winset(user, focusedwindow, "focus=true")
				else
					winset(user, "mapwindow", "focus=true")
				break
	if (timeout)
		addtimer(CALLBACK(src, .proc/close), timeout)

/datum/browser/modal/proc/wait()
	while (opentime && selectedbutton <= 0 && (!timeout || opentime+timeout > world.time))
		stoplag()

/datum/browser/modal/listpicker
	var/valueslist = list()

/datum/browser/modal/listpicker/New(User, Message, Title, Button1 = "Ok", Button2, Button3, StealFocus = 1, Timeout = FALSE, list/values, inputtype = "checkbox", width, height, slidecolor)
	if (!User)
		return

	var/output =  {"<form><input type="hidden" name="src" value="\ref[src]"><ul class="sparse">"}
	if (inputtype == "checkbox" || inputtype == "radio")
		for (var/i in values)
			var/div_slider = slidecolor
			if(!i["allowed_edit"])
				div_slider = "locked"
			output += {"<li>
						<label class="switch">
							<input type="[inputtype]" value="1" name="[i["name"]]"[i["checked"] ? " checked" : ""][i["allowed_edit"] ? "" : " onclick='return false' onkeydown='return false'"]>
								<div class="slider [div_slider ? "[div_slider]" : ""]"></div>
									<span>[i["name"]]</span>
						</label>
						</li>"}
	else
		for (var/i in values)
			output += {"<li><input id="name="[i["name"]]"" style="width: 50px" type="[type]" name="[i["name"]]" value="[i["value"]]">
			<label for="[i["name"]]">[i["name"]]</label></li>"}
	output += {"</ul><div style="text-align:center">
		<button type="submit" name="button" value="1" style="font-size:large;float:[( Button2 ? "left" : "right" )]">[Button1]</button>"}

	if (Button2)
		output += {"<button type="submit" name="button" value="2" style="font-size:large;[( Button3 ? "" : "float:right" )]">[Button2]</button>"}

	if (Button3)
		output += {"<button type="submit" name="button" value="3" style="font-size:large;float:right">[Button3]</button>"}

	output += {"</form></div>"}
	..(User, ckey("[User]-[Message]-[Title]-[world.time]-[rand(1,10000)]"), Title, width, height, src, StealFocus, Timeout)
	set_content(output)

/datum/browser/modal/listpicker/Topic(href, href_list)
	if (href_list["close"] || !user || !user.client)
		opentime = 0
		return
	if (href_list["button"])
		var/button = text2num(href_list["button"])
		if (button <= 3 && button >= 1)
			selectedbutton = button
	for (var/item in href_list)
		switch(item)
			if ("close", "button", "src")
				continue
			else
				valueslist[item] = href_list[item]
	opentime = 0
	close()

/proc/presentpicker(mob/User, Message, Title, Button1 = "Ok", Button2, Button3, StealFocus = TRUE, Timeout = 6000, list/values, inputtype = "checkbox", width, height, slidecolor)
	if (!istype(User))
		if (istype(User, /client/))
			var/client/C = User
			User = C.mob
		else
			return
	var/datum/browser/modal/listpicker/A = new(User, Message, Title, Button1, Button2, Button3, StealFocus,Timeout, values, inputtype, width, height, slidecolor)
	A.open()
	A.wait()
	if (A.selectedbutton)
		return list("button" = A.selectedbutton, "values" = A.valueslist)

/proc/input_bitfield(var/mob/User, title, bitfield, current_value, nwidth = 350, nheight = 350, nslidecolor, allowed_edit_list = null)
	if (!User || !(bitfield in global.bitfields))
		return
	var/list/pickerlist = list()
	for (var/i in global.bitfields[bitfield])
		var/can_edit = 1
		if(!isnull(allowed_edit_list) && !(allowed_edit_list & global.bitfields[bitfield][i]))
			can_edit = 0
		if (current_value & global.bitfields[bitfield][i])
			pickerlist += list(list("checked" = 1, "value" = global.bitfields[bitfield][i], "name" = i, "allowed_edit" = can_edit))
		else
			pickerlist += list(list("checked" = 0, "value" = global.bitfields[bitfield][i], "name" = i, "allowed_edit" = can_edit))
	var/list/result = presentpicker(User, "", title, Button1 = "Save", Button2 = "Cancel", Timeout = FALSE, values = pickerlist, width = nwidth, height = nheight, slidecolor = nslidecolor)
	if (islist(result))
		if (result["button"] == 2) // If the user pressed the cancel button
			return
		. = 0
		for (var/flag in result["values"])
			. |= global.bitfields[bitfield][flag]
	else
		return


// This will allow you to show an icon in the browse window
// This is added to mob so that it can be used without a reference to the browser object
// There is probably a better place for this...
/mob/proc/browse_rsc_icon(icon, icon_state, dir = -1)
	/*
	var/icon/I
	if (dir >= 0)
		I = new /icon(icon, icon_state, dir)
	else
		I = new /icon(icon, icon_state)
		dir = "default"

	var/filename = "[ckey("[icon]_[icon_state]_[dir]")].png"
	src << browse_rsc(I, filename)
	return filename
	*/


// Registers the on-close verb for a browse window (client/verb/.windowclose)
// this will be called when the close-button of a window is pressed.
//
// This is usually only needed for devices that regularly update the browse window,
// e.g. canisters, timers, etc.
//
// windowid should be the specified window name
// e.g. code is	: user << browse(text, "window=fred")
// then use 	: onclose(user, "fred")
//
// Optionally, specify the "ref" parameter as the controlled atom (usually src)
// to pass a "close=1" parameter to the atom's Topic() proc for special handling.
// Otherwise, the user mob's machine var will be reset directly.
//
/proc/onclose(mob/user, windowid, atom/ref=null)
	if(!user.client) return
	var/param = "null"
	if(ref)
		param = "\ref[ref]"

	winset(user, windowid, "on-close=\".windowclose [param]\"")

	//world << "OnClose [user]: [windowid] : ["on-close=\".windowclose [param]\""]"


// the on-close client verb
// called when a browser popup window is closed after registering with proc/onclose()
// if a valid atom reference is supplied, call the atom's Topic() with "close=1"
// otherwise, just reset the client mob's machine var.
//
/client/verb/windowclose(atomref as text)
	set hidden = 1						// hide this verb from the user's panel
	set name = ".windowclose"			// no autocomplete on cmd line

	//world << "windowclose: [atomref]"
	if(atomref!="null")				// if passed a real atomref
		var/hsrc = locate(atomref)	// find the reffed atom
		var/href = "close=1"
		if(hsrc)
			//world << "[src] Topic [href] [hsrc]"
			usr = src.mob
			src.Topic(href, params2list(href), hsrc)	// this will direct to the atom's
			return										// Topic() proc via client.Topic()

	// no atomref specified (or not found)
	// so just reset the user mob's machine var
	if(src && src.mob)
		//world << "[src] was [src.mob.machine], setting to null"
		src.mob.unset_machine()
	return
