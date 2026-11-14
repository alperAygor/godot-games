extends PrizRule
## Eski kablo: hattın props[prop] değeri kadar blok kapasiteden düşer (tüpte kullanılamaz
## bloklar olarak çizilir). params: prop (varsayılan "old_cable").
## gen: lines [min,max] kaç hat, amount [min,max] kaç blok.


func default_order() -> int:
	return 30


func modify_capacity(_level: PrizLevel, line: PrizLine, _slice: int, capacity: int) -> int:
	var amount: int = int(line.get_prop(param_str("prop", "old_cable"), 0))
	return capacity - amount


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var prop: String = param_str("prop", "old_cable")
	var count: int = mini(gen_range(ctx, "lines", 1, 1), ctx.level.lines.size())
	var indices: Array[int] = []
	for i: int in ctx.level.lines.size():
		indices.append(i)
	ctx.shuffle_ints(indices)
	for k: int in count:
		ctx.level.lines[indices[k]].props[prop] = gen_range(ctx, "amount", 1, 2)
	return true
