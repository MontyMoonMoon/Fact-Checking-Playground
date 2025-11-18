extends Node
class_name Lyra

# Enemy AI that performs sabotage actions against the player
# Actions intensify as time runs out

# References
var game_timer: GameTimer = null
var game_manager: GameManager = null
var emails_controller: Node = null
var laptop: Node = null

# Sabotage intensity (0.0 to 1.0, increases as time runs out)
var intensity: float = 0.0
var base_aggression: float = 20.0  # Base chance to perform sabotage (0-100)
var max_aggression: float = 80.0   # Max chance as time runs out

# Timing
var last_sabotage_time: float = 0.0
var base_cooldown: float = 45.0    # Base cooldown between sabotages (seconds)
var min_cooldown: float = 15.0     # Minimum cooldown when time is almost up

# Sabotage types
enum SabotageType {
	SPAM_EMAILS,
	TIME_DEDUCTION,
	INTEGRITY_REDUCTION,
	LAPTOP_CRASH
}

# Spam email data
var spam_email_templates: Array = [
	{
		"subject": "URGENT: Click here now!",
		"body": "This is a time-sensitive offer you cannot miss! Act immediately!",
		"from": "spam@fake-news.com"
	},
	{
		"subject": "Breaking: You won't believe this!",
		"body": "Shocking news that will change everything! Read more inside!",
		"from": "clickbait@disinfo.net"
	},
	{
		"subject": "Important Update Required",
		"body": "Your account needs immediate attention. Please verify your information.",
		"from": "noreply@suspicious-site.org"
	},
	{
		"subject": "Limited Time Offer - Act Fast!",
		"body": "Exclusive deal available for the next 5 minutes only! Don't miss out!",
		"from": "deals@spam-mail.com"
	},
	{
		"subject": "Re: Your Recent Inquiry",
		"body": "Regarding your previous message, we need additional information to proceed.",
		"from": "support@phishing-scam.net"
	}
]

# Laptop crash effects
var crash_effects_active: bool = false
var crash_duration: float = 0.0

func _ready():
	print("Lyra AI initialized - Ready to sabotage!")

func _process(delta):
	# Don't run if game is paused
	if get_tree().paused:
		return
	
	if not game_timer or not game_timer.is_running:
		return
	
	# Update intensity based on time remaining
	_update_intensity()
	
	# Check if it's time for sabotage
	if _should_perform_sabotage():
		_perform_random_sabotage()
	
	# Handle active crash effects
	if crash_effects_active:
		crash_duration -= delta
		if crash_duration <= 0.0:
			_end_crash_effects()

func set_game_timer(timer: GameTimer):
	game_timer = timer

func set_game_manager(manager: GameManager):
	game_manager = manager

func set_emails_controller(controller: Node):
	emails_controller = controller

func set_laptop(laptop_node: Node):
	laptop = laptop_node

func _update_intensity():
	"""Calculate intensity based on time remaining (0.0 = start, 1.0 = almost out of time)"""
	if not game_timer:
		intensity = 0.0
		return
	
	var time_remaining = game_timer.get_time_remaining()
	var time_limit = game_timer.time_limit
	
	if time_limit <= 0.0:
		intensity = 0.0
		return
	
	# Intensity increases as time runs out
	# At 50% time left: intensity = 0.5
	# At 10% time left: intensity = 0.9
	# At 0% time left: intensity = 1.0
	intensity = 1.0 - (time_remaining / time_limit)
	intensity = clamp(intensity, 0.0, 1.0)

func _should_perform_sabotage() -> bool:
	"""Check if it's time to perform a sabotage"""
	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - last_sabotage_time
	
	# Calculate cooldown based on intensity (shorter cooldown as time runs out)
	var current_cooldown = lerp(base_cooldown, min_cooldown, intensity)
	
	if time_since_last < current_cooldown:
		return false
	
	# Calculate aggression based on intensity
	var current_aggression = lerp(base_aggression, max_aggression, intensity)
	var roll = randf() * 100.0
	
	return roll <= current_aggression

func _perform_random_sabotage():
	"""Perform a random sabotage action"""
	var current_time = Time.get_unix_time_from_system()
	last_sabotage_time = current_time
	
	# Weighted random selection based on intensity
	# Early game: more spam emails
	# Late game: more severe actions (time deduction, integrity reduction, crashes)
	var weights = {
		SabotageType.SPAM_EMAILS: lerp(40.0, 15.0, intensity),  # Decreases over time (reduced from 60)
		SabotageType.TIME_DEDUCTION: lerp(20.0, 30.0, intensity),  # Increases
		SabotageType.INTEGRITY_REDUCTION: lerp(25.0, 35.0, intensity),  # Increases
		SabotageType.LAPTOP_CRASH: lerp(15.0, 20.0, intensity)  # Increases significantly
	}
	
	# Select sabotage type
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var roll = randf() * total_weight
	var selected_type = SabotageType.SPAM_EMAILS
	var accumulated = 0.0
	
	for type in SabotageType.values():
		accumulated += weights[type]
		if roll <= accumulated:
			selected_type = type
			break
	
	# Execute sabotage
	var type_names = {
		SabotageType.SPAM_EMAILS: "SPAM_EMAILS",
		SabotageType.TIME_DEDUCTION: "TIME_DEDUCTION",
		SabotageType.INTEGRITY_REDUCTION: "INTEGRITY_REDUCTION",
		SabotageType.LAPTOP_CRASH: "LAPTOP_CRASH"
	}
	print("Lyra: Executing sabotage - %s (intensity: %.2f)" % [type_names.get(selected_type, "UNKNOWN"), intensity])
	
	match selected_type:
		SabotageType.SPAM_EMAILS:
			_execute_spam_emails()
		SabotageType.TIME_DEDUCTION:
			_execute_time_deduction()
		SabotageType.INTEGRITY_REDUCTION:
			_execute_integrity_reduction()
		SabotageType.LAPTOP_CRASH:
			_execute_laptop_crash()

func _execute_spam_emails():
	"""Spam useless emails to the player"""
	if not emails_controller:
		print("Lyra: ERROR - Cannot spam emails - emails controller is null!")
		return
	
	print("Lyra: Spamming useless emails (emails_controller found: %s)..." % emails_controller.name)
	
	# Number of spam emails increases with intensity
	var spam_count = int(lerp(2, 5, intensity))
	
	for i in range(spam_count):
		# Create spam email
		var template = spam_email_templates[randi() % spam_email_templates.size()]
		var spam_email = {
			"subject": template.subject,
			"body": template.body,
			"from": template.from,
			"article_text": template.body,  # Useless content
			"tip_text": "This is spam - ignore it.",
			"facts": [],
			"stance": "spam",
			"integrity_score": 0.0
		}
		
		# Add spam email to emails controller
		if emails_controller.has_method("add_spam_email"):
			emails_controller.add_spam_email(spam_email)
			print("Lyra: Added spam email %d/%d: %s" % [i+1, spam_count, spam_email.subject])
		else:
			print("Lyra: ERROR - emails_controller doesn't have add_spam_email method!")
			# Fallback: try to add directly to email pool
			if emails_controller.has("email_news_pool"):
				emails_controller.email_news_pool.append(spam_email)
				print("Lyra: Added spam email via fallback method")
	
	print("Lyra: Sent %d spam emails total" % spam_count)

func _execute_time_deduction():
	"""Deduct time from the game timer"""
	if not game_timer:
		print("Lyra: Cannot deduct time - game timer not found")
		return
	
	# Amount of time deducted increases with intensity
	var time_deduction = lerp(5.0, 20.0, intensity)  # 5-20 seconds
	
	var current_time = game_timer.get_time_remaining()
	game_timer.time_remaining = max(0.0, current_time - time_deduction)
	
	print("Lyra: Deducted %.1f seconds from timer (intensity: %.2f)" % [time_deduction, intensity])

func _execute_integrity_reduction():
	"""Reduce player's integrity score"""
	if not game_manager:
		print("Lyra: Cannot reduce integrity - game manager not found")
		return
	
	# Amount of integrity reduction increases with intensity
	var integrity_loss = lerp(0.3, 1.5, intensity)
	
	if game_manager.has_method("add_integrity_score"):
		# Use negative value to reduce
		game_manager.add_integrity_score(-integrity_loss)
		print("Lyra: Reduced integrity by %.2f (intensity: %.2f)" % [integrity_loss, intensity])
	else:
		print("Lyra: Cannot reduce integrity - game manager missing method")

func _execute_laptop_crash():
	"""Cause laptop to crash or hang"""
	if not laptop:
		print("Lyra: Cannot crash laptop - laptop not found")
		return
	
	print("Lyra: Initiating laptop crash/hang...")
	
	# Crash duration increases with intensity
	crash_duration = lerp(2.0, 5.0, intensity)
	crash_effects_active = true
	
	# Apply crash effects
	if laptop.has_method("trigger_crash"):
		laptop.trigger_crash(crash_duration)
		print("Lyra: Laptop crash triggered for %.1f seconds" % crash_duration)
	else:
		print("Lyra: WARNING - Laptop doesn't have trigger_crash method, using fallback")
		# Fallback: freeze laptop UI
		_start_crash_effects()

func _start_crash_effects():
	"""Start visual/functional crash effects"""
	if not laptop:
		return
	
	# Make laptop unresponsive
	# Control nodes don't have process_mode, so we use the crash state methods
	if laptop.has_method("trigger_crash"):
		laptop.trigger_crash(crash_duration)
	
	# Add visual glitch effect if possible
	if laptop.has_method("add_glitch_effect"):
		laptop.add_glitch_effect(crash_duration)
	
	print("Lyra: Laptop crash effects active for %.1f seconds" % crash_duration)

func _end_crash_effects():
	"""End crash effects and restore laptop functionality"""
	if not laptop:
		return
	
	crash_effects_active = false
	
	# Restore laptop functionality
	# The laptop's trigger_crash method handles recovery automatically via timer
	# But we can also manually call recovery if needed
	if laptop.has_method("_on_crash_recover"):
		laptop._on_crash_recover()
	
	# Remove glitch effect if possible
	if laptop.has_method("remove_glitch_effect"):
		laptop.remove_glitch_effect()
	
	print("Lyra: Laptop crash effects ended - system restored")
