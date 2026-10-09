extends Node
## Autoload: turns the controller's UDP packets into Left / Up / Right key presses.
##
## Packets are 3 ASCII characters, '1' = held, in the order A, B, C - e.g. "010" =
## Up. They come from the ESP32 (main.cpp) or bridge.py, as a Wi-Fi broadcast or
## sent straight to this PC.
##
## The status line in the top-left corner shows what is arriving (F9 hides it):
##   "listening, nothing received yet" -> packets aren't reaching this PC:
##       same Wi-Fi as the bridge? Windows Firewall allowing UDP 4242?
##   "port busy"                       -> another copy of the game is running
##   "010 from 10.150.134.171"         -> working

const PORT := 4242                           # must match GAME_PORT in main.cpp / bridge.py
const TIMEOUT_MS := 500                      # no packet this long = let go of everything
const KEYS := [KEY_LEFT, KEY_UP, KEY_RIGHT]  # button A, B, C
const SHOW_STATUS := true                    # status line visible at start (F9 toggles)

var udp := PacketPeerUDP.new()
var listening := false
var last_bind_try_ms := 0
var held := [false, false, false]
var last_packet_ms := -1
var last_sender := ""
var last_msg := ""
var status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep reading packets while the game is paused
	_make_status_line()
	_listen()


func _exit_tree() -> void:
	udp.close()


func _listen() -> void:
	last_bind_try_ms = Time.get_ticks_msec()
	udp.close()
	var err := udp.bind(PORT, "0.0.0.0")  # IPv4 on every network adapter
	listening = err == OK
	if listening:
		print("ControllerInput: listening on UDP %d" % PORT)
	else:
		push_warning("ControllerInput: UDP port %d is busy (error %d), retrying every second" % [PORT, err])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if not listening and now - last_bind_try_ms > 1000:
		_listen()
	while listening and udp.get_available_packet_count() > 0:
		var msg := udp.get_packet().get_string_from_utf8().strip_edges()
		var sender := udp.get_packet_ip()
		if msg.length() != 3:
			continue
		if sender != last_sender:
			print("ControllerInput: receiving from %s" % sender)
		last_sender = sender
		last_msg = msg
		last_packet_ms = now
		for i in 3:
			_set_key(i, msg[i] == "1")
	if last_packet_ms < 0 or now - last_packet_ms > TIMEOUT_MS:
		for i in 3:
			_set_key(i, false)
	_update_status_line(now)


func _set_key(i: int, down: bool) -> void:
	if held[i] == down:
		return
	held[i] = down
	var event := InputEventKey.new()
	event.keycode = KEYS[i]
	event.physical_keycode = KEYS[i]
	event.pressed = down
	Input.parse_input_event(event)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F9:
		status.visible = not status.visible


func _make_status_line() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128  # above the game
	status = Label.new()
	status.position = Vector2(8, 4)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 4)
	status.visible = SHOW_STATUS
	layer.add_child(status)
	add_child(layer)


func _update_status_line(now: int) -> void:
	if not status.visible:
		return
	var text := "UDP %d: " % PORT
	if not listening:
		text += "port busy - is another copy of the game running?"
	elif last_packet_ms < 0:
		text += "listening, nothing received yet (same Wi-Fi as the bridge? firewall?)"
	elif now - last_packet_ms > 2000:
		text += "nothing for %d s (last from %s)" % [int((now - last_packet_ms) / 1000.0), last_sender]
	else:
		text += "%s from %s" % [last_msg, last_sender]
	status.text = text
