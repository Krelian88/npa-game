## plugin.gd  —  Claude Bridge  (Godot 4.6)
## HTTP server on localhost:6400 so the Claude MCP server can control the editor.
@tool
extends EditorPlugin

const PORT         := 6400
const MAX_DEPTH    := 8
const MAX_LOG      := 200

var _server : TCPServer = null
var _clients : Array    = []
var _log     : Array    = []

# ── lifecycle ────────────────────────────────────────────────────────────────

func _enter_tree() -> void:
	_server = TCPServer.new()
	if _server.listen(PORT) != OK:
		push_error("[ClaudeBridge] Port %d busy." % PORT)
		return
	print("[ClaudeBridge] Listening on http://localhost:%d" % PORT)

func _exit_tree() -> void:
	if _server:
		_server.stop()
	_clients.clear()
	print("[ClaudeBridge] Stopped.")

# ── main loop ────────────────────────────────────────────────────────────────

func _process(_dt: float) -> void:
	if not _server or not _server.is_listening():
		return
	while _server.is_connection_available():
		_clients.append({ "p": _server.take_connection(), "b": "" })
	var dead : Array = []
	for c in _clients:
		var peer : StreamPeerTCP = c["p"]
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			var n := peer.get_available_bytes()
			if n > 0:
				var r := peer.get_data(n)
				if r[0] == OK:
					c["b"] += (r[1] as PackedByteArray).get_string_from_utf8()
			_handle(c)
		elif st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
			dead.append(c)
	for d in dead:
		_clients.erase(d)

# ── HTTP parsing ─────────────────────────────────────────────────────────────

func _handle(c: Dictionary) -> void:
	var buf : String = c["b"]
	var he := buf.find("\r\n\r\n")
	if he == -1:
		return
	var hdr   := buf.substr(0, he)
	var bs    := he + 4
	var lines := hdr.split("\r\n")
	if lines.size() == 0:
		return
	var rl := lines[0].split(" ")
	if rl.size() < 2:
		return
	var method : String = rl[0].to_upper()
	var rawp   : String = rl[1]
	var path   : String = rawp
	var query  : Dictionary = {}
	if "?" in rawp:
		var pq := rawp.split("?", true, 1)
		path = pq[0]
		for kv_str in pq[1].split("&"):
			var kv := kv_str.split("=", true, 1)
			query[kv[0]] = kv[1].uri_decode() if kv.size() == 2 else ""
	var clen := 0
	for ln in lines:
		if ln.to_lower().begins_with("content-length:"):
			clen = ln.substr(ln.find(":") + 1).strip_edges().to_int()
			break
	if buf.length() < bs + clen:
		return
	var body  : String = buf.substr(bs, clen)
	c["b"] = buf.substr(bs + clen)
	if method == "OPTIONS":
		_reply(c["p"], "")
		return
	_reply(c["p"], JSON.stringify(_route(method, path, query, body)))

func _reply(peer: StreamPeerTCP, body: String) -> void:
	var bb := body.to_utf8_buffer()
	var hdr : String = "HTTP/1.1 200 OK\r\n"
	hdr += "Content-Type: application/json; charset=utf-8\r\n"
	hdr += "Content-Length: " + str(bb.size()) + "\r\n"
	hdr += "Access-Control-Allow-Origin: *\r\n"
	hdr += "Connection: close\r\n"
	hdr += "\r\n"
	peer.put_data(hdr.to_utf8_buffer())
	peer.put_data(bb)

# ── router ───────────────────────────────────────────────────────────────────

func _route(method: String, path: String, query: Dictionary, body: String) -> Dictionary:
	if path == "/ping":
		return { "ok": true, "version": "1.1", "godot": Engine.get_version_info() }
	if path == "/project_info":
		return _project_info()
	if path == "/scene_tree":
		return _scene_tree()
	if path == "/selected_nodes":
		return _selected_nodes()
	if path == "/node_properties":
		return _node_props(query.get("path", ""))
	if path == "/output":
		var lim := clampi(int(query.get("limit", "100")), 1, MAX_LOG)
		return { "logs": _log.slice(maxi(0, _log.size() - lim)) }
	if path == "/files":
		return _list_files(query.get("path", "res://"))
	if path == "/scripts":
		var out : Array = []
		_find_gd("res://", out)
		return { "scripts": out }
	if path == "/file":
		if method == "GET":
			return _read_file(query.get("path", ""))
		if method == "POST":
			var d = JSON.parse_string(body)
			if d == null or typeof(d) != TYPE_DICTIONARY:
				return { "error": "bad json" }
			return _write_file(d.get("path", ""), d.get("content", ""))
	if path == "/open_scene":
		var d = JSON.parse_string(body) if body.length() > 2 else {}
		if d == null:
			d = {}
		return _open_scene(d.get("path", query.get("path", "")))
	if path == "/reload_scene":
		return _reload_scene()
	if path == "/save_scene":
		return _save_scene()
	if path == "/exec_expression":
		var d = JSON.parse_string(body)
		if d == null or typeof(d) != TYPE_DICTIONARY:
			return { "error": "bad json" }
		return _exec_expr(d.get("expression", ""), d.get("node", ""))
	if path == "/select_node":
		var d = JSON.parse_string(body)
		if d == null or typeof(d) != TYPE_DICTIONARY:
			return { "error": "bad json" }
		return _select_node(d.get("path", ""))
	return { "error": "unknown endpoint: " + path }

# ── handlers ─────────────────────────────────────────────────────────────────

func _project_info() -> Dictionary:
	return {
		"name"    : ProjectSettings.get_setting("application/config/name", ""),
		"version" : ProjectSettings.get_setting("application/config/version", ""),
		"main"    : ProjectSettings.get_setting("application/run/main_scene", ""),
		"path"    : ProjectSettings.globalize_path("res://"),
		"godot"   : Engine.get_version_info()
	}

func _scene_tree() -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return { "error": "no scene open" }
	return { "scene_path": root.scene_file_path, "root": _node_dict(root, 0) }

func _node_dict(node: Node, depth: int) -> Dictionary:
	var d : Dictionary = {
		"name": str(node.name),
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}
	if depth < MAX_DEPTH:
		for ch in node.get_children():
			d["children"].append(_node_dict(ch, depth + 1))
	elif node.get_child_count() > 0:
		d["children_hidden"] = node.get_child_count()
	return d

func _selected_nodes() -> Dictionary:
	var sel  := EditorInterface.get_selection()
	var out  : Array = []
	for n in sel.get_selected_nodes():
		out.append({ "name": str(n.name), "type": n.get_class(), "path": str(n.get_path()) })
	return { "nodes": out }

func _node_props(node_path: String) -> Dictionary:
	if node_path.is_empty():
		return { "error": "no path" }
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return { "error": "no scene open" }
	var node := root.get_node_or_null(NodePath(node_path))
	if node == null:
		return { "error": "node not found: " + node_path }
	var props : Array = []
	for p in node.get_property_list():
		if p["usage"] & PROPERTY_USAGE_EDITOR:
			props.append({ "name": p["name"], "type": type_string(p["type"]), "value": str(node.get(p["name"])) })
	return { "path": node_path, "type": node.get_class(), "properties": props }

func _read_file(fpath: String) -> Dictionary:
	if fpath.is_empty():
		return { "error": "no path" }
	if not FileAccess.file_exists(fpath):
		return { "error": "file not found: " + fpath }
	var f := FileAccess.open(fpath, FileAccess.READ)
	if f == null:
		return { "error": "cannot open: " + fpath }
	var txt := f.get_as_text()
	f.close()
	return { "path": fpath, "content": txt }

func _write_file(fpath: String, content: String) -> Dictionary:
	if fpath.is_empty():
		return { "error": "no path" }
	var abs_dir := ProjectSettings.globalize_path(fpath.get_base_dir())
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(fpath, FileAccess.WRITE)
	if f == null:
		return { "error": "cannot write: " + fpath }
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(fpath)
	return { "ok": true, "path": fpath, "bytes": content.to_utf8_buffer().size() }

func _list_files(dirpath: String) -> Dictionary:
	var da := DirAccess.open(dirpath)
	if da == null:
		return { "error": "cannot open: " + dirpath }
	var files : Array = []
	var dirs  : Array = []
	da.list_dir_begin()
	var nm := da.get_next()
	while nm != "":
		if not nm.begins_with("."):
			var fp := dirpath.path_join(nm)
			if da.current_is_dir():
				dirs.append({ "name": nm, "path": fp })
			else:
				files.append({ "name": nm, "path": fp, "ext": nm.get_extension() })
		nm = da.get_next()
	da.list_dir_end()
	return { "path": dirpath, "dirs": dirs, "files": files }

func _find_gd(dirpath: String, out: Array) -> void:
	var da := DirAccess.open(dirpath)
	if da == null:
		return
	da.list_dir_begin()
	var nm := da.get_next()
	while nm != "":
		if not nm.begins_with("."):
			var fp := dirpath.path_join(nm)
			if da.current_is_dir():
				_find_gd(fp, out)
			elif nm.get_extension() == "gd":
				out.append(fp)
		nm = da.get_next()
	da.list_dir_end()

func _open_scene(spath: String) -> Dictionary:
	if spath.is_empty():
		return { "error": "no path" }
	if not FileAccess.file_exists(spath):
		return { "error": "not found: " + spath }
	EditorInterface.open_scene_from_path(spath)
	return { "ok": true, "opened": spath }

func _reload_scene() -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return { "error": "no scene open" }
	var sp := root.scene_file_path
	if sp.is_empty():
		return { "error": "scene not saved" }
	EditorInterface.reload_scene_from_path(sp)
	return { "ok": true, "reloaded": sp }

func _save_scene() -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return { "error": "no scene open" }
	EditorInterface.save_scene()
	return { "ok": true, "saved": root.scene_file_path }

func _exec_expr(expr_str: String, ctx_path: String) -> Dictionary:
	if expr_str.is_empty():
		return { "error": "no expression" }
	var ex := Expression.new()
	if ex.parse(expr_str) != OK:
		return { "error": "parse: " + ex.get_error_text() }
	var ctx : Object = self
	if not ctx_path.is_empty():
		var root := EditorInterface.get_edited_scene_root()
		if root:
			var n := root.get_node_or_null(NodePath(ctx_path))
			if n:
				ctx = n
	var result = ex.execute([], ctx, true)
	if ex.has_execute_failed():
		return { "error": "exec: " + ex.get_error_text() }
	return { "result": str(result) }

func _select_node(node_path: String) -> Dictionary:
	if node_path.is_empty():
		return { "error": "no path" }
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return { "error": "no scene open" }
	var node := root.get_node_or_null(NodePath(node_path))
	if node == null:
		return { "error": "not found: " + node_path }
	var sel := EditorInterface.get_selection()
	sel.clear()
	sel.add_node(node)
	return { "ok": true, "selected": node_path }
