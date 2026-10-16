class_name SimulationBridge
extends Node

signal state_received(state: Dictionary)
signal connection_error(message: String)

var peer := StreamPeerTCP.new()
var process_id := -1
var auth_token := ""
var handshake_path := ""
var receive_buffer := PackedByteArray()
var connected := false
var elapsed := 0.0
var connecting := false

func _ready() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var node_path := root.path_join("runtime/node.exe")
	var server_path := root.path_join("backend/server.cjs")
	auth_token = "%s_%s" % [Time.get_ticks_usec(), randi()]
	handshake_path = OS.get_user_data_dir().path_join("session_%s.json" % auth_token)
	var qa := OS.get_cmdline_user_args().has("--qa")
	var save_path := OS.get_user_data_dir().path_join("qa-save.json" if qa else "league-save.json")
	if not FileAccess.file_exists(node_path):
		connection_error.emit("缺少本地运行模块 runtime/node.exe")
		return
	process_id = OS.create_process(node_path, [server_path, handshake_path, auth_token, save_path], false)
	if process_id < 0:
		connection_error.emit("无法启动本地对局模块")

func _process(delta: float) -> void:
	elapsed += delta
	if not connected and not connecting and FileAccess.file_exists(handshake_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(handshake_path))
		if data is Dictionary and data.has("port"):
			peer.connect_to_host("127.0.0.1", int(data.port))
			connecting = true
	peer.poll()
	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if not connected:
			connected = true
			send_command("hello")
		var available := peer.get_available_bytes()
		if available > 0:
			var packet := peer.get_data(available)
			if packet[0] == OK:
				receive_buffer.append_array(packet[1])
		while receive_buffer.find(10) >= 0:
			var split_at := receive_buffer.find(10)
			var line := receive_buffer.slice(0, split_at).get_string_from_utf8()
			receive_buffer = receive_buffer.slice(split_at + 1)
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				if parsed.get("type") == "state":
					state_received.emit(parsed)
				elif parsed.get("type") == "error":
					connection_error.emit(str(parsed.get("message")))
	elif elapsed > 20.0 and not connected:
		connection_error.emit("本地对局模块连接超时，请重新启动游戏。")
		elapsed = -1000.0

func send_command(command: String, arguments: Dictionary = {}) -> void:
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var request := {"token": auth_token, "cmd": command, "args": arguments}
	peer.put_data((JSON.stringify(request) + "\n").to_utf8_buffer())

func _exit_tree() -> void:
	peer.disconnect_from_host()
	if process_id > 0 and OS.is_process_running(process_id):
		OS.kill(process_id)
	if not handshake_path.is_empty() and FileAccess.file_exists(handshake_path):
		DirAccess.remove_absolute(handshake_path)
