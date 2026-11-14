extends PrizRule
## Çoklu priz: aynı odadaki birkaç tekli priz tek bir uzatmada toplanır (yuva sayısı korunur;
## hepsi uzatmanın hattına bağlanır). Yuva dolu ret kodu çekirdektedir (PrizReason.SOCKET_FULL).
## gen: strips [min,max] uzatma sayısı, seats [min,max] uzatma başına yuva.


func default_order() -> int:
	return 20


func gen_stage() -> int:
	return STAGE_PRE_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var strips: int = gen_range(ctx, "strips", 1, 2)
	var made: int = 0
	for k: int in strips:
		var seats: int = gen_range(ctx, "seats", 2, 3)
		# Tekli prizi en az `seats` olan odalar.
		var rooms: Array[String] = []
		for room: String in ctx.level.rooms:
			var n: int = 0
			for socket: PrizSocket in ctx.level.sockets:
				if socket.room == room and socket.seats == 1:
					n += 1
			if n >= seats:
				rooms.append(room)
		if rooms.is_empty():
			break
		var room: String = rooms[ctx.pick_index(rooms.size())]
		var singles: Array[PrizSocket] = []
		for socket: PrizSocket in ctx.level.sockets:
			if socket.room == room and socket.seats == 1:
				singles.append(socket)
		var host: PrizSocket = singles[ctx.pick_index(singles.size())]
		singles.erase(host)
		for m: int in seats - 1:
			var victim: PrizSocket = singles[ctx.pick_index(singles.size())]
			singles.erase(victim)
			ctx.level.sockets.erase(victim)
			host.seats += 1
		made += 1
	if made == 0:
		return false
	# Uzatma birleştirmesi bir hattı prizsiz bırakmış olabilir.
	for line: PrizLine in ctx.level.lines:
		var has_socket: bool = false
		for socket: PrizSocket in ctx.level.sockets:
			if socket.line == line.id:
				has_socket = true
				break
		if not has_socket:
			return false
	return true
