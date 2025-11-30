extends RefCounted
class_name NLPAnalyzer

# Named Entity Recognition patterns NLP1
var person_patterns = [
	"\\b[A-Z][a-z]+ [A-Z][a-z]+\\b",  # First Last
	"\\b(?:Mr|Mrs|Ms|Dr|Prof)\\.? [A-Z][a-z]+\\b",  # Titles
	"\\b[A-Z][a-z]+ (?:Jr|Sr|III|II|IV)\\.?\\b"  # Suffixes
]

var organization_patterns = [
	"\\b[A-Z][a-zA-Z]+ (?:Inc|Corp|LLC|Ltd|Company|Corporation|Foundation|Institute|University|College)\\b",
	"\\b(?:The|A) [A-Z][a-zA-Z]+ (?:of|for|in|at)\\b"
]

var location_patterns = [
	"\\b[A-Z][a-z]+(?:, [A-Z]{2})?\\b",  # City, State
	"\\b(?:New|Old|North|South|East|West) [A-Z][a-z]+\\b",  # Compound locations
	"\\b[A-Z][a-z]+ (?:Street|Avenue|Road|Boulevard|Drive|Lane)\\b"
]

var date_patterns = [
	"\\b(?:January|February|March|April|May|June|July|August|September|October|November|December) \\d{1,2},? \\d{4}\\b",
	"\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b",
	"\\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),? (?:January|February|March|April|May|June|July|August|September|October|November|December) \\d{1,2}\\b"
]

#Keyword Extraction NLP2
# Fake news keyword patterns
var fake_news_keywords = [
	"breaking news exclusive",
	"shocking truth",
	"they don't want you to know",
	"doctors hate this",
	"you won't believe",
	"this will shock you",
	"secret revealed",
	"hidden truth",
	"mainstream media won't tell you",
	"conspiracy",
	"cover-up",
	"exposed",
	"leaked documents",
	"insider reveals",
	"urgent warning",
	"act now",
	"limited time",
	"click here",
	"share this immediately"
]

# Classification keywords
var true_indicators = [
	"verified",
	"confirmed",
	"official statement",
	"according to sources",
	"peer-reviewed",
	"fact-checked",
	"multiple sources",
	"witnesses confirm",
	"documented evidence"
]

var false_indicators = [
	"unverified",
	"rumor",
	"allegedly",
	"unconfirmed reports",
	"speculation",
	"claims without evidence",
	"questionable source",
	"debunked",
	"hoax",
	"satire"
]

# Entity data structure
class Entity:
	var text: String
	var type: String  # PERSON, ORGANIZATION, LOCATION, DATE
	var start_pos: int
	var end_pos: int
	
	func _init(_text: String, _type: String, _start: int, _end: int):
		text = _text
		type = _type
		start_pos = _start
		end_pos = _end

# Analysis result structure
class AnalysisResult:
	var entities: Array = []  # Array of Entity
	var classification: String = "Unverified"  # True, False, Unverified
	var classification_confidence: float = 0.5
	var fake_news_keywords: Array = []
	var fake_news_score: float = 0.0
	var semantic_keywords: Array = []
	
	func _init():
		pass

# Main analysis function
static func analyze_text(text: String) -> AnalysisResult:
	var result = AnalysisResult.new()
	var analyzer = NLPAnalyzer.new()
	
	# Extract entities
	result.entities = analyzer._extract_entities(text)
	
	# Classify text
	var classification_data = analyzer._classify_text(text)
	result.classification = classification_data.classification
	result.classification_confidence = classification_data.confidence
	
	# Extract fake news keywords
	result.fake_news_keywords = analyzer._extract_fake_news_keywords(text)
	result.fake_news_score = analyzer._calculate_fake_news_score(text)
	
	# Extract semantic keywords (important terms)
	result.semantic_keywords = analyzer._extract_semantic_keywords(text)
	
	return result

#Text Classification NLP3
func _extract_entities(text: String) -> Array:
	var entities = []
	var regex = RegEx.new()
	
	# Extract persons
	for pattern in person_patterns:
		regex.compile(pattern)
		var results = regex.search_all(text)
		for match in results:
			var entity = Entity.new(match.get_string(), "PERSON", match.get_start(), match.get_end())
			entities.append(entity)
	
	# Extract organizations
	for pattern in organization_patterns:
		regex.compile(pattern)
		var results = regex.search_all(text)
		for match in results:
			var entity = Entity.new(match.get_string(), "ORGANIZATION", match.get_start(), match.get_end())
			entities.append(entity)
	
	# Extract locations
	for pattern in location_patterns:
		regex.compile(pattern)
		var results = regex.search_all(text)
		for match in results:
			var entity = Entity.new(match.get_string(), "LOCATION", match.get_start(), match.get_end())
			entities.append(entity)
	
	# Extract dates
	for pattern in date_patterns:
		regex.compile(pattern)
		var results = regex.search_all(text)
		for match in results:
			var entity = Entity.new(match.get_string(), "DATE", match.get_start(), match.get_end())
			entities.append(entity)
	
	# Remove duplicates
	var unique_entities = []
	var seen_texts = {}
	for entity in entities:
		if not seen_texts.has(entity.text):
			seen_texts[entity.text] = true
			unique_entities.append(entity)
	
	return unique_entities

func _classify_text(text: String) -> Dictionary:
	var lower_text = text.to_lower()
	var true_score = 0.0
	var false_score = 0.0
	
	# Count true indicators
	for indicator in true_indicators:
		if lower_text.contains(indicator.to_lower()):
			true_score += 1.0
	
	# Count false indicators
	for indicator in false_indicators:
		if lower_text.contains(indicator.to_lower()):
			false_score += 1.0
	
	# Calculate confidence
	var total_indicators = true_score + false_score
	var confidence = 0.5
	
	if total_indicators > 0:
		confidence = max(true_score, false_score) / total_indicators
		confidence = clamp(confidence, 0.3, 0.9)
	
	# Determine classification
	var classification = "Unverified"
	if true_score > false_score and true_score > 0:
		classification = "True"
		confidence = max(confidence, 0.6)
	elif false_score > true_score and false_score > 0:
		classification = "False"
		confidence = max(confidence, 0.6)
	
	return {
		"classification": classification,
		"confidence": confidence,
		"true_score": true_score,
		"false_score": false_score
	}

func _extract_fake_news_keywords(text: String) -> Array:
	var found_keywords = []
	var lower_text = text.to_lower()
	
	for keyword in fake_news_keywords:
		if lower_text.contains(keyword.to_lower()):
			found_keywords.append(keyword)
	
	return found_keywords

func _calculate_fake_news_score(text: String) -> float:
	var found_keywords = _extract_fake_news_keywords(text)
	var score = float(found_keywords.size()) / float(fake_news_keywords.size())
	return clamp(score, 0.0, 1.0)

func _extract_semantic_keywords(text: String) -> Array:
	# Extract important words (nouns, capitalized words, numbers)
	# First normalize the text - split on common delimiters
	var normalized_text = text.replace(":", " ").replace(";", " ").replace(",", " ").replace(".", " ").replace("!", " ").replace("?", " ")
	var words = normalized_text.split(" ", false)
	var keywords = []
	var stop_words = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can"]
	var seen_keywords = {}  # Use dictionary for faster lookup
	
	for word in words:
		var clean_word = word.strip_edges().to_lower()
		
		# Remove any remaining punctuation
		clean_word = clean_word.replace(".", "").replace(",", "").replace("!", "").replace("?", "").replace(":", "").replace(";", "").replace("-", "").replace("_", "")
		
		# Skip stop words and short words
		if clean_word.length() < 2 or stop_words.has(clean_word):
			continue
		
		# Include all meaningful words (not just capitalized ones)
		# This ensures "dusk" and "Dusk" both become "dusk"
		if not seen_keywords.has(clean_word):
			keywords.append(clean_word)
			seen_keywords[clean_word] = true
	
	# Limit to top 15 keywords (increased to capture more relevant terms)
	if keywords.size() > 15:
		keywords = keywords.slice(0, 15)
	
	return keywords

# Compare two analysis results
static func compare_analyses(analysis_a: AnalysisResult, analysis_b: AnalysisResult, text_a: String, text_b: String) -> Dictionary:
	var result = {
		"entity_overlap": 0.0,
		"entity_matches": [],
		"classification_match": false,
		"keyword_overlap": 0.0,
		"semantic_similarity": 0.0,
		"overall_match_score": 0.0
	}
	
	# Compare entities
	var entity_matches = []
	var total_entities = max(analysis_a.entities.size(), analysis_b.entities.size(), 1)
	
	for entity_a in analysis_a.entities:
		for entity_b in analysis_b.entities:
			if entity_a.type == entity_b.type:
				# Check if entities are similar (same type and similar text)
				var similarity = _calculate_text_similarity(entity_a.text, entity_b.text)
				if similarity > 0.7:  # 70% similarity threshold
					entity_matches.append({
						"entity_a": entity_a.text,
						"entity_b": entity_b.text,
						"type": entity_a.type,
						"similarity": similarity
					})
	
	result.entity_overlap = float(entity_matches.size()) / float(total_entities)
	result.entity_matches = entity_matches
	
	# Compare classification
	result.classification_match = (analysis_a.classification == analysis_b.classification)
	
	# Compare keywords with improved matching
	var keywords_a = analysis_a.semantic_keywords
	var keywords_b = analysis_b.semantic_keywords
	var common_keywords = []
	var matched_b = {}  # Track which keywords_b have been matched
	
	# First pass: exact matches (case-insensitive, already normalized)
	for keyword_a in keywords_a:
		var found_match = false
		for keyword_b in keywords_b:
			if keyword_a == keyword_b:
				if not matched_b.has(keyword_b):
					common_keywords.append(keyword_a)
					matched_b[keyword_b] = true
					found_match = true
					break
		
		# Second pass: fuzzy matching for similar keywords (handles minor variations)
		if not found_match:
			for keyword_b in keywords_b:
				if matched_b.has(keyword_b):
					continue
				# Check if keywords are similar (e.g., "dusk" vs "dusk", or "time" vs "time")
				var similarity = _calculate_keyword_similarity(keyword_a, keyword_b)
				if similarity >= 0.9:  # 90% similarity threshold for fuzzy matching
					common_keywords.append(keyword_a)
					matched_b[keyword_b] = true
					break
	
	var total_keywords = max(keywords_a.size(), keywords_b.size(), 1)
	result.keyword_overlap = float(common_keywords.size()) / float(total_keywords)
	
	# Calculate semantic similarity (Jaccard similarity on words)
	result.semantic_similarity = _calculate_semantic_similarity(text_a, text_b)
	
	# Calculate overall match score (weighted average)
	result.overall_match_score = (
		result.entity_overlap * 0.3 +
		(result.classification_match as float) * 0.2 +
		result.keyword_overlap * 0.2 +
		result.semantic_similarity * 0.3
	)
	
	return result

static func _calculate_text_similarity(text_a: String, text_b: String) -> float:
	# Simple word-based similarity
	var words_a = text_a.to_lower().split(" ")
	var words_b = text_b.to_lower().split(" ")
	
	var common = 0
	var total = max(words_a.size(), words_b.size(), 1)
	
	for word in words_a:
		if words_b.has(word):
			common += 1
	
	return float(common) / float(total)

static func _calculate_keyword_similarity(keyword_a: String, keyword_b: String) -> float:
	"""Calculate similarity between two keywords (0.0 to 1.0)"""
	# Normalize both to lowercase
	var a = keyword_a.to_lower().strip_edges()
	var b = keyword_b.to_lower().strip_edges()
	
	# Exact match
	if a == b:
		return 1.0
	
	# Check if one contains the other (for compound words)
	if a.length() > 0 and b.length() > 0:
		if a.contains(b) or b.contains(a):
			var min_len = min(a.length(), b.length())
			var max_len = max(a.length(), b.length())
			return float(min_len) / float(max_len)
	
	# Calculate character-based similarity (Levenshtein-like)
	var max_len = max(a.length(), b.length())
	if max_len == 0:
		return 0.0
	
	var common_chars = 0
	var min_len = min(a.length(), b.length())
	for i in range(min_len):
		if a[i] == b[i]:
			common_chars += 1
	
	# Simple similarity based on common prefix and length
	var similarity = float(common_chars) / float(max_len)
	return similarity

static func _calculate_semantic_similarity(text_a: String, text_b: String) -> float:
	# Jaccard similarity on word sets
	var words_a = text_a.to_lower().split(" ")
	var words_b = text_b.to_lower().split(" ")
	
	# Remove duplicates
	var set_a = {}
	var set_b = {}
	for word in words_a:
		var clean = word.strip_edges().replace(".", "").replace(",", "").replace("!", "").replace("?", "")
		if clean.length() > 2:
			set_a[clean] = true
	for word in words_b:
		var clean = word.strip_edges().replace(".", "").replace(",", "").replace("!", "").replace("?", "")
		if clean.length() > 2:
			set_b[clean] = true
	
	# Calculate intersection and union
	var intersection = 0
	var union = set_a.size()
	
	for word in set_b.keys():
		if set_a.has(word):
			intersection += 1
		else:
			union += 1
	
	if union == 0:
		return 0.0
	
	return float(intersection) / float(union)







