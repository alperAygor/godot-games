extends PrizRule
## Kapalı hat: props[prop] dilim kimliği taşıyan hat o dilimde elektrik vermez (kapasite 0);
## o dilimde çalışan bir cihaz bu hatta olursa sigorta atar. params: prop ("off_slice").
## gen: lines [min,max]. Gizli çözümde o dilimde yükü sıfır olan (hat, dilim) seçilir.


func default_order() -> int:
	return 1000


func modify_capacity(_level: PrizLevel, line: PrizLine, slice: int, capacity: int) -> int:
	var off: Variant = line.get_prop(param_str("prop", "off_slice"), null)
	if off != null and PrizSlice.from_id(str(off)) == slice:
		return 0
	return capacity


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var prop: String = param_str("prop", "off_slice")
	var count: int = gen_range(ctx, "lines", 1, 1)
	for k: int in count:
		var loads: PackedInt32Array = ctx.planted_loads()
		var pairs: Array[int] = []
		for l: int in ctx.level.lines.size():
			var line: PrizLine = ctx.level.lines[l]
			if line.props.has(prop):
				continue
			var total: int = 0
			for s: int in PrizSlice.COUNT:
				total += loads[l * PrizSlice.COUNT + s]
			if total == 0:
				continue
			for s: int in PrizSlice.COUNT:
				if loads[l * PrizSlice.COUNT + s] == 0:
					pairs.append(l * PrizSlice.COUNT + s)
		if pairs.is_empty():
			return k > 0
		var pick: int = pairs[ctx.pick_index(pairs.size())]
		ctx.level.lines[int(pick / float(PrizSlice.COUNT))].props[prop] = \
				PrizSlice.id_of(pick % PrizSlice.COUNT)
	return true
