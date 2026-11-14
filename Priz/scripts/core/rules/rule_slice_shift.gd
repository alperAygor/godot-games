extends PrizRule
## Zamanlayıcılı priz: props[prop] = k taşıyan prize takılan cihazın çalışma dilimleri
## k dilim ileri kayar (gece → sabaha sarar). params: prop ("timer").
## gen: sockets [min,max] zamanlayıcılı priz sayısı, shift [min,max] kaydırma.
## Önce gizli çözümde dört dilimden azında çalışan bir cihazın prizi seçilir (etki görünür olsun).


func default_order() -> int:
	return 15


func modify_mask(_level: PrizLevel, _device: PrizDevice, socket: PrizSocket, mask: int) -> int:
	var shift: int = int(socket.get_prop(param_str("prop", "timer"), 0))
	if shift == 0:
		return mask
	return PrizSlice.rotate(mask, shift)


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var prop: String = param_str("prop", "timer")
	var count: int = gen_range(ctx, "sockets", 1, 1)
	var hosts: Array[PrizSocket] = []
	for device: PrizDevice in ctx.level.devices:
		if device.slices == PrizSlice.ALL_MASK:
			continue
		var socket: PrizSocket = ctx.planted_socket(device)
		if socket != null and socket.seats == 1 and not hosts.has(socket):
			hosts.append(socket)
	if hosts.is_empty():
		return false
	for k: int in mini(count, hosts.size()):
		var socket: PrizSocket = hosts[ctx.pick_index(hosts.size())]
		hosts.erase(socket)
		socket.props[prop] = clampi(gen_range(ctx, "shift", 1, 2), 1, PrizSlice.COUNT - 1)
	return true
