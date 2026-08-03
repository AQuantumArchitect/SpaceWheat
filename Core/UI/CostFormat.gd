extends RefCounted

## The one cost-dictionary → display-string authority (slop knot #13).
##
## Five sites used to hand-roll this with three drifting conventions —
## EscapeMenu's copy even carried a comment saying it was manually kept in
## sync with ChipResolverRegistry's. Each caller now delegates here, pinning
## its EXACT historical convention via opts (OverlayChrome precedent: shared
## body, per-site params, zero visible change — parity-probed 2026-08-03).
##
## opts:
##   pair:   "emoji_times"     → "🌾×5"        (ProbeActions refusal messages)
##           "amount_emoji"    → "5 🌾"        (FarmEconomy messages)
##           "neg_tight"       → "−5🌾"        (chip badges; ROUNDS floats)
##           "neg_emoji_times" → "−🌾×5"/"−🌾" (submenu chips; bare emoji at ≤1)
##           "emoji_neg"       → "🌾−5"        (EscapeMenu dev-inspector row)
##   sorted: sort emoji keys (default false — insertion order)
##   joiner: separator (default " ")
##   empty:  string returned for an empty cost (default "")
##
## The sign conventions are LAW, not style: a bare "🍼1" reads ambiguous
## (cost or reward?) — signed variants say what the wallet loses (d1-03).

static func format_cost(cost: Dictionary, opts: Dictionary = {}) -> String:
	if cost.is_empty():
		return str(opts.get("empty", ""))
	var keys: Array = cost.keys()
	if bool(opts.get("sorted", false)):
		keys.sort()
	var pair := str(opts.get("pair", "emoji_times"))
	var parts: Array[String] = []
	for emoji in keys:
		var raw = cost[emoji]
		match pair:
			"emoji_times":
				parts.append("%s×%d" % [str(emoji), int(raw)])
			"amount_emoji":
				parts.append("%d %s" % [int(raw), str(emoji)])
			"neg_tight":
				# Rounds (0.6🍼 → −1🍼): the chip badge shows what the wallet
				# will actually be charged, never a misleading −0.
				parts.append("−%d%s" % [int(round(float(raw))), str(emoji)])
			"neg_emoji_times":
				if float(raw) > 1.0:
					parts.append("−%s×%d" % [str(emoji), int(raw)])
				else:
					parts.append("−%s" % str(emoji))
			"emoji_neg":
				parts.append("%s−%d" % [str(emoji), int(raw)])
	return str(opts.get("joiner", " ")).join(parts)
