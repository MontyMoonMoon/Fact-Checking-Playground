extends Node
class_name TimeDateManager

# Time Values
static var start_time: int
static var end_time: int

# Date Values
static var day1: String
static var day14: String
static var day26:  String

static func load_days() -> void:
	day1 = "Aug/20/1995"
	day14 = "Sep/3/1995"
	day26 = "Sep/15/1995"

static func load_time() -> void:
	pass
	
static func timer_start() -> void:
	pass
