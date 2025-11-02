extends Node

const API_URL = "http://127.0.0.1:8000/"

func _ready():
	
	print("Checking if backend is running...")
	_check_backend_ready()

func _check_backend_ready():
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_check_completed)
	request.request(API_URL)

func _on_check_completed(result, response_code, headers, body):
	if response_code == 200:
		print("API already running.")
	else:
		print("API not running, starting it now...")
		_start_backend()

func _start_backend():
	var os_name = OS.get_name()
	var api_path = ProjectSettings.globalize_path("res://ml_api.py")

	if os_name == "Windows":
		OS.execute("cmd", ["/c", "python", api_path],[], false)
	elif os_name == "Linux" or os_name == "macOS":
		OS.execute("bash", ["-c", "python3 " + api_path],[], false)
		
	

	print("API launched, waiting for it to initialize...")
	# Wait a few seconds before checking again
	_wait_for_backend_ready()

func _wait_for_backend_ready():
	# Give the API time to start before trying again
	await get_tree().create_timer(2.0).timeout
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_final_check)
	request.request(API_URL)
	



func _on_final_check(result, response_code, headers, body):
	if response_code == 200:
		print("API ready for connections.")
	else:
		print("Still can’t reach API. Check your Python path or ml_api.py.")
