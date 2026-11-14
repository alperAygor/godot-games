extends PrizRule
## Yalnız test: genişletilebilirlik kanıtı. props[prop] taşıyan cihaz, params.slice diliminde
## çalışıyorsa params.extra blok fazla yük bindirir. Çekirdekte hiçbir değişiklik gerektirmez.


func modify_load(_level: PrizLevel, device: PrizDevice, _socket: PrizSocket, slice: int,
		blocks: int) -> int:
	if blocks <= 0 or not bool(device.get_prop(param_str("prop", "surge"), false)):
		return blocks
	if PrizSlice.from_id(param_str("slice", "night")) != slice:
		return blocks
	return blocks + param_int("extra", 1)


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var slice: int = PrizSlice.from_id(param_str("slice", "night"))
	var pool: Array[int] = []
	for i: int in ctx.level.devices.size():
		if PrizSlice.has(ctx.level.devices[i].slices, slice):
			pool.append(i)
	if pool.is_empty():
		return false
	ctx.shuffle_ints(pool)
	for k: int in mini(gen_range(ctx, "devices", 1, 1), pool.size()):
		ctx.level.devices[pool[k]].props[param_str("prop", "surge")] = true
	return true
