extends PrizRule
## Bayrak eşleşmesi: cihazda device_flag varsa prizde socket_flag olmalı (topraklı priz).
## params: device_flag ("needs_ground"), socket_flag ("grounded"), reason ("needs_ground"),
##         catalog_flag ("ground": katalogda bu bayrağı taşıyan türler tercih edilir).
## gen: devices [min,max] bayraklı cihaz sayısı, extra_sockets [min,max] fazladan bayraklı priz.


func default_order() -> int:
	return 40


func check_plug(_level: PrizLevel, device: PrizDevice, socket: PrizSocket) -> StringName:
	var device_flag: String = param_str("device_flag", "needs_ground")
	var socket_flag: String = param_str("socket_flag", "grounded")
	if bool(device.get_prop(device_flag, false)) and not bool(socket.get_prop(socket_flag, false)):
		return StringName(param_str("reason", String(PrizReason.NEEDS_GROUND)))
	return PrizReason.OK


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var device_flag: String = param_str("device_flag", "needs_ground")
	var socket_flag: String = param_str("socket_flag", "grounded")
	var catalog_flag: String = param_str("catalog_flag", "")
	var preferred: Array[int] = []
	var others: Array[int] = []
	for i: int in ctx.level.devices.size():
		var device: PrizDevice = ctx.level.devices[i]
		if catalog_flag != "" and ctx.catalog.has_flag(device.type, catalog_flag):
			preferred.append(i)
		else:
			others.append(i)
	ctx.shuffle_ints(preferred)
	ctx.shuffle_ints(others)
	var pool: Array[int] = preferred + others
	var count: int = mini(gen_range(ctx, "devices", 1, 2), pool.size())
	if count <= 0:
		return false
	for k: int in count:
		var device: PrizDevice = ctx.level.devices[pool[k]]
		var socket: PrizSocket = ctx.planted_socket(device)
		if socket == null:
			return false
		device.props[device_flag] = true
		socket.props[socket_flag] = true
	var extra: int = gen_range(ctx, "extra_sockets", 0, 1)
	var plain: Array[int] = []
	for i: int in ctx.level.sockets.size():
		if not bool(ctx.level.sockets[i].get_prop(socket_flag, false)):
			plain.append(i)
	ctx.shuffle_ints(plain)
	for k: int in mini(extra, plain.size()):
		ctx.level.sockets[plain[k]].props[socket_flag] = true
	return true
