extends PrizRule
## Komşu hattı: props[prop] dört dilimlik yük dizisi ([sabah, öğle, akşam, gece]) hatta dış
## yük olarak biner (komşunun cihazları). params: prop ("neighbour").
## gen: max [min,max] dilim başına en çok blok, slices [min,max] yüklü dilim sayısı.


func default_order() -> int:
	return 60


func external_load(_level: PrizLevel, line: PrizLine, slice: int) -> int:
	var v: Variant = line.get_prop(param_str("prop", "neighbour"), null)
	if typeof(v) != TYPE_ARRAY:
		return 0
	var arr: Array = v
	if slice < 0 or slice >= arr.size():
		return 0
	return maxi(int(arr[slice]), 0)


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var line: PrizLine = ctx.level.lines[ctx.pick_index(ctx.level.lines.size())]
	var busy: int = clampi(gen_range(ctx, "slices", 1, 2), 1, PrizSlice.COUNT)
	var order: Array[int] = [0, 1, 2, 3]
	ctx.shuffle_ints(order)
	var arr: Array = [0, 0, 0, 0]
	for k: int in busy:
		arr[order[k]] = maxi(gen_range(ctx, "max", 1, 2), 1)
	line.props[param_str("prop", "neighbour")] = arr
	return true
