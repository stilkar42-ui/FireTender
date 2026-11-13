extends RefCounted
## Original silhouettes for the fuel dock. IDs match Fire.SPECIES.

const ART := [
	"""<path fill="#d5ba89" d="M9 10q8-5 15 0l20 3-7 17q-8 1-16-4l-14 2z"/><path fill="#f2d9a5" d="M13 10q7-3 11 0l19 3-4 5-20-3-9 2z"/><path d="m14 20 7 1m3 3 9 2m0-8 6 1" stroke="#7f573c" stroke-width="2"/>""",
	"""<g fill="none" stroke-linecap="round"><path d="m7 29 40-20M9 25l36 3M13 29l23-23" stroke="#6a4535" stroke-width="5"/><path d="m8 28 40-19M10 24l34 3M14 28l23-22m-14 15-2-8m12 5 9 1m-14 2-3 8" stroke="#b98755" stroke-width="2.5"/></g>""",
	"""<path fill="#684330" stroke="#492d23" d="m5 24 34-15 11 6-5 9-32 11z"/><path fill="#c0925c" d="m5 24 34-15 10 5-32 16z"/><path fill="#e1bc82" d="m41 17 9-3-4 10-8 3z"/><path d="m15 24 25-11m-24 17 15-6" stroke="#835836" fill="none"/>""",
	"""<path fill="#465353" stroke="#273735" d="m6 24 32-14 11 6-4 9-31 9z"/><path fill="#78948d" d="m6 24 32-14 10 5-31 15z"/><path fill="#a5b3a0" d="m40 20 9-5-4 10-8 2z"/><path d="m16 23 21-9m-14 12 12-6" stroke="#b9cfc4"/><path fill="#81bcd0" d="M16 6q-8 10-3 12 8 2 3-12zm14-3q-6 8-2 10 6 1 2-10z"/>""",
	"""<g fill="none" stroke-linecap="round"><path d="M7 24q13-13 37-3M9 27q11-8 36-3m-31 7q13-14 26-4" stroke="#754632" stroke-width="5"/><path d="M8 23q11-13 32-3m-24 9q-3-10 15-11t8-6m-27 9q0-9 13-13m2 19q6-6 18-5M20 30q13 1 14-7m-22 2q7 4 13-3" stroke="#dfaa70" stroke-width="2.3"/></g>""",
	"""<g fill="none" stroke-linecap="round"><path d="M27 31Q12 22 10 9m17 22q-7-16-3-27m4 27q0-20 7-25m-6 25q9-17 17-17m-19 17Q17 18 9 18m18 13Q16 16 17 9m12 22q9-4 16-5" stroke="#b2a370" stroke-width="2.3"/><path d="m22 27 11 2m-11-4 11 3" stroke="#e0bd7c" stroke-width="2"/></g>""",
	"""<path fill="#d9a96d" stroke="#8f613e" d="m7 28 38-16-27 21zm3-5 31-17-15 15zm13 7 25-9-16 10z"/><path d="m15 27 21-11m-15 5 13-9" stroke="#f1c78e"/>""",
	"""<g stroke-linecap="round"><path d="m8 28 37-17m-35 9 29-12m-24 23 32-9" stroke="#694631" stroke-width="5.5"/><path d="m8 27 37-17m-35 9 29-12m-24 23 32-9" stroke="#b78250" stroke-width="2.7"/><path d="m34 15 5-1m-16 9 4-1" stroke="#dca569"/></g>""",
	"""<path fill="#795139" stroke="#543628" d="m6 25 32-13 11 1-3 8-31 10z"/><path fill="#d8a66d" d="m6 25 32-13 11 1-34 15z"/><path d="m15 24 23-9m-16 11 16-7" stroke="#9c663d"/><path fill="#ae7e53" d="m34 15-5-7 4-2 8 8z"/>""",
	"""<path fill="#78513a" stroke="#503229" d="m5 25 17-8 14-4 10-8 4 3-7 11 7 2-2 5-15-1-20 10z"/><path fill="#a97a50" d="m5 25 17-8 15-4 9-7-7 12 6 3-14 1-18 8z"/><ellipse cx="10" cy="29" rx="5" ry="4" fill="#d0a370"/><path d="m16 26 18-8m-24 9-2 2 2 2" stroke="#8d5f43" fill="none"/>""",
	"""<path fill="#754832" stroke="#482d24" d="m3 27 37-19 11 4-3 9-35 13z"/><path fill="#cfa168" d="m3 27 37-19 11 4-38 17z"/><path fill="#e4bd81" d="m43 16 8-4-3 9-7 4z"/><path d="m12 26 26-14m-19 16 22-11m-20 12 12-5" fill="none" stroke="#a47248"/>""",
	"""<path fill="#98704e" stroke="#513d2d" d="m5 27 29-14 7-10 4 2-5 9 10-2 1 4-13 6-26 12z"/><path d="m10 27 30-13m-24 15 15-8" stroke="#c39463"/><path d="m31 10 5 4m10-8-4 7" stroke="#6b7c49" stroke-width="2"/>""",
	"""<path fill="#d9c9a5" stroke="#705d47" d="m5 25 34-14 10 1 2 7-37 15z"/><path d="m13 26 6 2m3-7 4 1m5-6 6 1m-2 6 5 1" stroke="#674d3b" stroke-width="2"/><ellipse cx="47" cy="15" rx="4" ry="4" fill="#c69764"/>""",
	"""<path d="M6 28Q18 28 30 18T49 10M19 24Q24 17 23 9" fill="none" stroke="#626544" stroke-width="7" stroke-linecap="round"/><path d="M7 26Q18 26 30 16T48 8M19 23Q25 16 24 9" fill="none" stroke="#b4a575" stroke-width="3" stroke-linecap="round"/>""",
	"""<path fill="#ba854e" stroke="#69452d" d="M9 25Q5 12 21 7q10 11-5 20zM27 26Q24 10 44 7q9 15-9 21z"/><path fill="none" stroke="#ead1a0" d="m12 28 7-16m10 16 12-15"/>""",
	"""<path fill="#94623b" stroke="#68482e" d="M6 18q4-7 20-9 18 0 22 9l-7 13H13z"/><path fill="none" stroke="#e4b67e" stroke-width="2" d="M7 18q15 12 41 0M9 21q15-11 33-8m-27 15q8-17 22-17m-10 20q9-15 19-13"/>""",
]

static func make(kind: int) -> ImageTexture:
	var image := Image.new()
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="54" height="36" viewBox="0 0 54 36">' + ART[kind] + "</svg>"
	image.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(image)
