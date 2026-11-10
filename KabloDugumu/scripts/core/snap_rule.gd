class_name SnapRule
extends RefCounted

## Birakma aninda fisin hangi prize denk geldigini ve rengin uyup uymadigini soyler.
## Sahne bilmez; saf kural. Yalnizca pano duzlemi (x,y) kullanilir: fis suruklerken
## kameraya dogru kalkar (z buyur), bu snap'i engellememelidir.

enum Result { NONE, SNAP, WRONG_COLOR }

## Snap yaricapi; menzil disi birakma -> NONE.
static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()


## Verilen fis konumuna yaricap icindeki en yakin BOS prizi dondurur (-1 yok).
static func nearest_socket(plug_position: Vector3, sockets: Array[SocketSpec],
		free_sockets: Array[int], radius: float) -> int:
	if radius <= 0.0:
		return -1
	var best: int = -1
	var best_distance: float = radius
	for socket_index: int in free_sockets:
		if socket_index < 0 or socket_index >= sockets.size():
			continue
		var distance: float = _flat_distance(plug_position, sockets[socket_index].position)
		if distance < best_distance:
			best_distance = distance
			best = socket_index
	return best


## {"result": Result, "socket_index": int, "distance": float}
## En yakin bos priz kendi rengiyse SNAP; farkli renkse WRONG_COLOR; menzilde
## bos priz yoksa NONE (distance = -1).
static func evaluate(plug_position: Vector3, sockets: Array[SocketSpec],
		free_sockets: Array[int], cable_index: int, cables: Array[CableSpec],
		radius: float) -> Dictionary:
	if cable_index < 0 or cable_index >= cables.size():
		return {"result": Result.NONE, "socket_index": -1, "distance": -1.0}
	var socket_index: int = nearest_socket(plug_position, sockets, free_sockets, radius)
	if socket_index < 0:
		return {"result": Result.NONE, "socket_index": -1, "distance": -1.0}
	var distance: float = _flat_distance(plug_position, sockets[socket_index].position)
	if sockets[socket_index].color_id == cables[cable_index].color_id:
		return {"result": Result.SNAP, "socket_index": socket_index, "distance": distance}
	return {"result": Result.WRONG_COLOR, "socket_index": socket_index, "distance": distance}
