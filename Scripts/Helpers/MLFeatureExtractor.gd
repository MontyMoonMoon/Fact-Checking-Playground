extends RefCounted
class_name MLFeatureExtractor

# Helper class to extract ML features from article data
# Reduces bloat in ai_analysis_controller.gd

static func extract_features(article_data: Dictionary, article_text: String, nlp_data: Dictionary = {}) -> Dictionary:
	var news_data = article_data.get("news_data", {})
	var sender = article_data.get("sender", "")
	var tip_text = news_data.get("tip_text", "")
	var facts = news_data.get("facts", [])
	var stance = news_data.get("stance", "Neutral")
	var integrity_score = news_data.get("integrity_score", 0.5)
	
	# 1. Evidence Count
	var evidence_count = _count_evidence(facts)
	
	# 2. Sentiment Score
	var sentiment_score = _calculate_sentiment_score(article_text, stance, nlp_data)
	
	# 3. Contradiction Score
	var contradiction_score = _calculate_contradiction_score(article_text, tip_text, facts, nlp_data)
	
	# 4. Date Validation Score
	var date_validation_score = _get_date_validation_score(nlp_data)
	
	# 5. Propaganda Pattern Score
	var propaganda_score = _calculate_propaganda_score(article_text, stance, sender, integrity_score, date_validation_score)
	
	# 6. Source Type
	var source_type = _infer_source_type(sender, stance)
	
	# 7. Topic
	var topic = _detect_topic(article_text, sender)
	
	return {
		"text": article_text,
		"sentiment_score": sentiment_score,
		"evidence_count": evidence_count,
		"contradiction_score": contradiction_score,
		"propaganda_pattern_score": propaganda_score,
		"source_type": source_type,
		"topic": topic
	}

static func _count_evidence(facts: Array) -> int:
	var evidence_count = 0
	for fact in facts:
		if fact.get("source", "") == "Article":
			evidence_count += 1
	if evidence_count == 0 and facts.size() > 0:
		evidence_count = facts.size()
	if evidence_count == 0:
		evidence_count = 1  # Default minimum
	return evidence_count

static func _calculate_sentiment_score(text: String, stance: String, nlp_data: Dictionary) -> float:
	var base_score = 0.5  # Neutral
	
	match stance:
		"Pro-Government", "Pro-Celebrity":
			base_score = 0.7
		"Critical", "Skeptical", "Investigative":
			base_score = 0.3
		"Neutral", "Concerned", "Suspicious":
			base_score = 0.5
	
	if nlp_data.has("article_nlp"):
		var article_nlp = nlp_data.get("article_nlp", {})
		if article_nlp.has("classification"):
			var classification = article_nlp.get("classification", "Unverified")
			if classification == "True":
				base_score += 0.1
			elif classification == "False":
				base_score -= 0.1
	
	return clamp(base_score, 0.0, 1.0)

static func _calculate_contradiction_score(article_text: String, tip_text: String, facts: Array, nlp_data: Dictionary) -> float:
	if tip_text == "" or tip_text.begins_with("Tip: "):
		return 0.3
	
	var contradiction_count = 0
	var total_facts = facts.size()
	
	if total_facts == 0:
		if nlp_data.has("article_nlp") and nlp_data.has("tip_nlp"):
			var article_nlp = nlp_data.get("article_nlp", {})
			var tip_nlp = nlp_data.get("tip_nlp", {})
			if not article_nlp.is_empty() and not tip_nlp.is_empty():
				var article_class = article_nlp.get("classification", "Unknown")
				var tip_class = tip_nlp.get("classification", "Unknown")
				if article_class != tip_class:
					return 0.7
		return 0.3
	
	for fact in facts:
		var source = fact.get("source", "")
		if source == "Tip":
			var category = fact.get("category", "")
			if category in ["Warning", "Pressure", "Anomaly", "Contradiction", "Conflict"]:
				contradiction_count += 1
	
	var contradiction_ratio = float(contradiction_count) / float(max(total_facts, 1))
	return clamp(contradiction_ratio, 0.0, 1.0)

static func _get_date_validation_score(nlp_data: Dictionary) -> float:
	if nlp_data.has("date_validation_score"):
		return nlp_data.get("date_validation_score", 1.0)
	return 1.0

static func _calculate_propaganda_score(text: String, stance: String, sender: String, integrity_score: float, date_validation_score: float = 1.0) -> float:
	var score = 0.5
	
	if stance == "Pro-Government":
		score = 0.8
	elif sender.contains("Government") or sender.contains("Ministry") or sender.contains("Press Office"):
		score = 0.7
	elif sender.contains("SyndiNet"):
		score = 0.75
	
	if integrity_score < 0.5:
		score += 0.2
	
	if date_validation_score < 1.0:
		score += 0.15
	
	var lower_text = text.to_lower()
	var propaganda_keywords = ["unprecedented", "record-breaking", "overwhelming support", "historic levels", "all-time high", "redacted"]
	for keyword in propaganda_keywords:
		if lower_text.contains(keyword):
			score += 0.1
	
	return clamp(score, 0.0, 1.0)

static func _infer_source_type(sender: String, stance: String) -> String:
	var lower_sender = sender.to_lower()
	
	if lower_sender.contains("government") or lower_sender.contains("ministry") or lower_sender.contains("press office") or lower_sender.contains("sovereign council"):
		return "state_media"
	elif lower_sender.contains("syndinet"):
		return "state_media"
	elif lower_sender.contains("anonymous") or lower_sender.contains("whistleblower") or lower_sender.contains("source"):
		return "anonymous_tip"
	elif lower_sender.contains("foreign") or lower_sender.contains("international"):
		return "foreign_press"
	else:
		return "independent"

static func _detect_topic(text: String, sender: String) -> String:
	var lower_text = text.to_lower()
	var lower_sender = sender.to_lower()
	
	if lower_text.contains("celebrity") or lower_text.contains("entertainment") or lower_sender.contains("entertainment"):
		return "celebrity"
	elif lower_text.contains("senate") or lower_text.contains("government") or lower_text.contains("political") or lower_text.contains("corruption"):
		return "politics"
	elif lower_text.contains("military") or lower_text.contains("defense") or lower_text.contains("war"):
		return "military"
	elif lower_text.contains("economy") or lower_text.contains("economic") or lower_text.contains("supply") or lower_text.contains("shortage"):
		return "economy"
	elif lower_text.contains("protest") or lower_text.contains("demonstration") or lower_text.contains("rally"):
		return "protest"
	elif lower_text.contains("health") or lower_text.contains("hospital") or lower_text.contains("medical"):
		return "health"
	else:
		return "politics"

