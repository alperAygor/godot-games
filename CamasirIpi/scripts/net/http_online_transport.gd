class_name HttpOnlineTransport
extends OnlineTransport

## Gerçek aktarım: `HTTPRequest` ile düz bir GET. İstekte kişisel veri, çerez ya da başlık yok;
## yalnız "internet var mı" sorusu sorulur. HTTPRequest düğümü her istek için kurulur ve silinir.

var _host: Node = null


## `host`: HTTPRequest düğümünün ekleneceği kalıcı düğüm (sahne değişince silinmeyen: kök).
func _init(host: Node) -> void:
	_host = host


func probe(url: String, expected_status: int, timeout_seconds: float) -> bool:
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		return false
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = timeout_seconds
	request.accept_gzip = false
	# Oyun duraklatılmış olsa da (sonuç sayfası vb.) denetim sürmeli.
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	_host.add_child(request)
	var started: Error = request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if started != OK:
		request.queue_free()
		return false
	var reply: Array = await request.request_completed
	request.queue_free()
	return int(reply[0]) == HTTPRequest.RESULT_SUCCESS and int(reply[1]) == expected_status
