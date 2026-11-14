class_name PrizSolver
extends RefCounted
## Çözücü: tam ve geçerli atamaları (her cihaz takılı, hiçbir dilimde hat taşmıyor) sayar.
##
## Budama:
##  - Eş prizler (aynı hat, oda, props) tek sınıfta toplanır; sınıf yuva sayısı kadar cihaz alır.
##  - Birebir aynı davranan cihazlar için sınıf dizini azalmayan sırada atanır (simetri kırma).
##  - En kısıtlı cihaz önce; her adımda dilim başına kalan toplam kapasite, kalan cihazların
##    en az yüküyle karşılaştırılır.
## Durumsuzdur; her çağrı kendi arama nesnesini kurar (iş parçacığı güvenli).

const DEFAULT_NODE_LIMIT: int = 400000

var node_limit: int = DEFAULT_NODE_LIMIT


func _init(limit: int = DEFAULT_NODE_LIMIT) -> void:
	node_limit = limit


## En fazla `cap` çözüm sayar.
func count_solutions(level: PrizLevel, registry: PrizElementRegistry, cap: int = 1000) -> PrizSolveResult:
	return count_compiled(PrizCompiled.build(level, registry), cap)


func count_compiled(c: PrizCompiled, cap: int, ignore_capacity: bool = false) -> PrizSolveResult:
	var search: _Search = _Search.new(c, node_limit)
	var fixed: PackedInt32Array = PackedInt32Array()
	fixed.resize(c.n_devices)
	fixed.fill(-1)
	search.run(fixed, cap, true, ignore_capacity)
	return search.result()


func is_solvable(level: PrizLevel, registry: PrizElementRegistry) -> bool:
	return count_solutions(level, registry, 1).count > 0


## Bir çözüm: cihaz kimliği → priz kimliği; çözüm yoksa boş sözlük.
func first_solution(level: PrizLevel, registry: PrizElementRegistry) -> Dictionary:
	return count_solutions(level, registry, 1).solution


## Tahtanın mevcut planından ulaşılabilen bir çözüme göre ipucu.
## - Plan bir çözüme uzanabiliyorsa: takılı olmayan (en kısıtlı) bir cihaz ve doğru prizi (PLACE).
## - Uzanamıyorsa: yerinden çıkması gereken bir cihaz (MOVE); mümkünse gideceği priz de verilir.
## - Plan zaten tam ve geçerliyse NONE.
func hint(board: PrizBoard) -> PrizHint:
	var c: PrizCompiled = board.compiled()
	var placement: PackedInt32Array = board.placement_indices()
	if board.is_all_plugged() and c.is_valid_solution(placement):
		return PrizHint.make(PrizHint.NONE)
	var search: _Search = _Search.new(c, node_limit)
	if search.run(placement, 1, false, false) > 0:
		var d: int = search.first_free_device()
		if d >= 0:
			return PrizHint.make(PrizHint.PLACE, c.level.devices[d].id,
					c.level.sockets[search.solution_socket[d]].id)
	# Plan uzanamıyor: tek bir cihazı serbest bırakmak yetiyor mu?
	for d: int in c.n_devices:
		if placement[d] < 0:
			continue
		var trial: PackedInt32Array = placement.duplicate()
		trial[d] = -1
		var s2: _Search = _Search.new(c, node_limit)
		if s2.run(trial, 1, false, false) > 0:
			var target: int = s2.solution_socket[d]
			return PrizHint.make(PrizHint.MOVE, c.level.devices[d].id, c.level.sockets[target].id)
	# Birden çok cihaz yanlış: sıfırdan bir çözüm bul, sınıfı farklı olan ilk cihazı çıkar.
	var empty: PackedInt32Array = PackedInt32Array()
	empty.resize(c.n_devices)
	empty.fill(-1)
	var s3: _Search = _Search.new(c, node_limit)
	if s3.run(empty, 1, false, false) == 0:
		return PrizHint.make(PrizHint.UNSOLVABLE)
	for d: int in c.n_devices:
		if placement[d] >= 0 and c.socket_class[placement[d]] != s3.solution_class[d]:
			return PrizHint.make(PrizHint.MOVE, c.level.devices[d].id, "")
	# Sınıflar doğru ama yuvalar dolu olamaz; güvenli geri dönüş: ilk takılı cihaz.
	for d: int in c.n_devices:
		if placement[d] >= 0:
			return PrizHint.make(PrizHint.MOVE, c.level.devices[d].id, "")
	return PrizHint.make(PrizHint.UNSOLVABLE)


## Tek bir arama. İç sınıf; dışarıdan kullanılmaz.
class _Search extends RefCounted:
	var c: PrizCompiled
	var node_limit: int = 0
	var nodes: int = 0
	var count: int = 0
	var cap: int = 1
	var stop: bool = false
	var limit_hit: bool = false
	var ignore_capacity: bool = false
	var symmetry: bool = true

	var order: PackedInt32Array = PackedInt32Array()
	var same_as_prev: PackedInt32Array = PackedInt32Array()
	## Cihaz başına uyumlu sınıflar.
	var dev_classes: Array[PackedInt32Array] = []
	## [(cihaz*n_classes + sınıf)*4 + dilim]
	var class_load: PackedInt32Array = PackedInt32Array()
	var rem: PackedInt32Array = PackedInt32Array()
	var sum_rem: PackedInt32Array = PackedInt32Array()
	## [k*4 + dilim]: order[k..] cihazlarının en az yük toplamı.
	var suffix_min: PackedInt32Array = PackedInt32Array()
	var class_free: PackedInt32Array = PackedInt32Array()
	var assign: PackedInt32Array = PackedInt32Array()
	var fixed: PackedInt32Array = PackedInt32Array()

	var solution_class: PackedInt32Array = PackedInt32Array()
	var solution_socket: PackedInt32Array = PackedInt32Array()
	var has_solution: bool = false

	func _init(compiled: PrizCompiled, limit: int) -> void:
		c = compiled
		node_limit = limit

	func result() -> PrizSolveResult:
		var r: PrizSolveResult = PrizSolveResult.new()
		r.count = count
		r.capped = count >= cap and stop and not limit_hit
		r.node_limit_hit = limit_hit
		r.nodes = nodes
		if has_solution:
			for d: int in c.n_devices:
				r.solution[c.level.devices[d].id] = c.level.sockets[solution_socket[d]].id
		return r

	func first_free_device() -> int:
		if order.size() == 0:
			return -1
		return order[0]

	## fixed_placement: cihaz → priz dizini (-1 = serbest). Bulunan çözüm sayısını döner.
	func run(fixed_placement: PackedInt32Array, solution_cap: int, use_symmetry: bool,
			no_capacity: bool) -> int:
		cap = maxi(solution_cap, 1)
		symmetry = use_symmetry
		ignore_capacity = no_capacity
		fixed = fixed_placement
		var nc: int = c.n_classes
		var nd: int = c.n_devices
		var sc: int = PrizSlice.COUNT
		rem = c.capacity.duplicate()
		for i: int in rem.size():
			rem[i] -= c.external[i]
		class_free = c.class_seats.duplicate()
		assign.resize(nd)
		assign.fill(-1)
		# Sabit cihazlar kapasiteyi ve yuvaları önceden tüketir.
		for d: int in nd:
			var sock: int = fixed[d]
			if sock < 0:
				continue
			if c.compat_of(d, sock) != PrizReason.OK:
				return 0
			var ci: int = c.socket_class[sock]
			class_free[ci] -= 1
			if class_free[ci] < 0:
				return 0
			assign[d] = ci
			var l: int = c.socket_line[sock]
			for s: int in sc:
				rem[l * sc + s] -= c.load_of(d, sock, s)
		if not ignore_capacity:
			for i: int in rem.size():
				if rem[i] < 0:
					return 0
		# Sınıf başına yük vektörleri ve uyumluluk (sınıfın ilk prizi temsilcidir).
		class_load.resize(nd * nc * sc)
		class_load.fill(0)
		dev_classes.clear()
		var signatures: PackedStringArray = PackedStringArray()
		for d: int in nd:
			var list: PackedInt32Array = PackedInt32Array()
			var sig: String = ""
			for ci: int in nc:
				var rep: int = c.class_sockets[ci][0]
				if c.compat_of(d, rep) != PrizReason.OK:
					continue
				list.append(ci)
				sig += "%d:" % ci
				for s: int in sc:
					var v: int = c.load_of(d, rep, s)
					class_load[(d * nc + ci) * sc + s] = v
					sig += "%d," % v
				sig += ";"
			dev_classes.append(list)
			signatures.append(sig)
		# Serbest cihazların sırası: az seçenekli önce, sonra ağır önce, sonra imza.
		var free: Array = []
		for d: int in nd:
			if fixed[d] >= 0:
				continue
			if dev_classes[d].size() == 0:
				return 0
			var total: int = 0
			for s: int in sc:
				total += c.load_of(d, c.class_sockets[dev_classes[d][0]][0], s)
			free.append([dev_classes[d].size(), -total, signatures[d], d])
		free.sort()
		order.clear()
		same_as_prev.clear()
		for k: int in free.size():
			var entry: Array = free[k]
			var d: int = int(entry[3])
			order.append(d)
			var same: int = 0
			if k > 0 and symmetry:
				var prev: Array = free[k - 1]
				if str(prev[2]) == str(entry[2]):
					same = 1
			same_as_prev.append(same)
		# Kalan toplam kapasite ve en az yük sonekleri.
		sum_rem.resize(sc)
		sum_rem.fill(0)
		for l: int in c.n_lines:
			for s: int in sc:
				sum_rem[s] += maxi(rem[l * sc + s], 0)
		var n: int = order.size()
		suffix_min.resize((n + 1) * sc)
		suffix_min.fill(0)
		for k: int in range(n - 1, -1, -1):
			var d: int = order[k]
			for s: int in sc:
				var best: int = 1 << 30
				for ci: int in dev_classes[d]:
					best = mini(best, class_load[(d * nc + ci) * sc + s])
				suffix_min[k * sc + s] = suffix_min[(k + 1) * sc + s] + best
		_rec(0)
		return count

	func _rec(k: int) -> void:
		nodes += 1
		if nodes > node_limit:
			limit_hit = true
			stop = true
			return
		var sc: int = PrizSlice.COUNT
		if k == order.size():
			count += 1
			if not has_solution:
				_store_solution()
			if count >= cap:
				stop = true
			return
		if not ignore_capacity:
			for s: int in sc:
				if suffix_min[k * sc + s] > sum_rem[s]:
					return
		var d: int = order[k]
		var nc: int = c.n_classes
		var start: int = 0
		if same_as_prev[k] == 1:
			start = assign[order[k - 1]]
		for ci: int in dev_classes[d]:
			if ci < start or class_free[ci] <= 0:
				continue
			var l: int = c.class_line[ci]
			var base: int = (d * nc + ci) * sc
			var fits: bool = true
			if not ignore_capacity:
				for s: int in sc:
					if class_load[base + s] > rem[l * sc + s]:
						fits = false
						break
			if not fits:
				continue
			class_free[ci] -= 1
			assign[d] = ci
			for s: int in sc:
				rem[l * sc + s] -= class_load[base + s]
				sum_rem[s] -= class_load[base + s]
			_rec(k + 1)
			for s: int in sc:
				rem[l * sc + s] += class_load[base + s]
				sum_rem[s] += class_load[base + s]
			class_free[ci] += 1
			assign[d] = -1
			if stop:
				return

	## Sınıf atamasını somut prizlere çevirir (sabitler yerinde kalır).
	func _store_solution() -> void:
		has_solution = true
		solution_class = assign.duplicate()
		solution_socket.resize(c.n_devices)
		solution_socket.fill(-1)
		var used: PackedInt32Array = PackedInt32Array()
		used.resize(c.n_sockets)
		used.fill(0)
		for d: int in c.n_devices:
			if fixed[d] >= 0:
				solution_socket[d] = fixed[d]
				used[fixed[d]] += 1
		for d: int in c.n_devices:
			if fixed[d] >= 0:
				continue
			for sock: int in c.class_sockets[assign[d]]:
				if used[sock] < c.socket_seats[sock]:
					solution_socket[d] = sock
					used[sock] += 1
					break
