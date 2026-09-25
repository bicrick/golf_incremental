class_name WebBgmFetcher
extends Node
## Fetches one OGG BGM track at a time over HTTP (web export). Same-origin URLs only.

signal fetch_succeeded(path: String, stream: AudioStreamOggVorbis)
signal fetch_failed(path: String, message: String)

var _http: HTTPRequest
var _active_path: String = ""
var _request_id := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "WebBgmHttp"
	_http.timeout = 60.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_busy() -> bool:
	return not _active_path.is_empty()


func cancel() -> void:
	_request_id += 1
	_active_path = ""
	if _http != null:
		_http.cancel_request()


func request_track(relative_path: String) -> void:
	if relative_path.is_empty():
		fetch_failed.emit(relative_path, "empty path")
		return
	_request_id += 1
	var token := _request_id
	_active_path = relative_path
	_http.cancel_request()
	var url := _to_absolute_url(relative_path)
	var err := _http.request(url)
	if err != OK:
		if token == _request_id:
			_active_path = ""
		fetch_failed.emit(relative_path, "HTTPRequest.request failed (%s) url=%s" % [error_string(err), url])


func _to_absolute_url(path: String) -> String:
	if path.begins_with("http://") or path.begins_with("https://"):
		return path
	var normalized := path
	if normalized.begins_with("./"):
		normalized = normalized.substr(2)
	if not normalized.begins_with("/"):
		normalized = "/" + normalized
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if origin != null and str(origin) != "":
			return "%s%s" % [str(origin), normalized]
	return normalized


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var path := _active_path
	var completed_id := _request_id
	_active_path = ""
	# Stale completion after cancel() or a newer request_track().
	if path.is_empty():
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		fetch_failed.emit(path, "HTTP result %s" % result)
		return
	if response_code < 200 or response_code >= 300:
		fetch_failed.emit(path, "HTTP status %s" % response_code)
		return
	if body.is_empty():
		fetch_failed.emit(path, "empty body")
		return
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_buffer(body)
	if stream == null:
		fetch_failed.emit(path, "AudioStreamOggVorbis.load_from_buffer failed")
		return
	# Drop if a newer request superseded this one mid-callback.
	if completed_id != _request_id:
		return
	fetch_succeeded.emit(path, stream)
