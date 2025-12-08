extends RefCounted
class_name FactComparator

# Helper class for comparing facts
# Reduces bloat in ai_analysis_controller.gd

static func compare_facts(fact_a_data: Dictionary, fact_b_data: Dictionary) -> Dictionary:
	var result = {
		"is_discrepancy": false,
		"reason": "",
		"truth_status": "",
		"entity_analysis": "",
		"classification_analysis": "",
		"keyword_analysis": "",
		"relationship": ""
	}
	
	var value_a = fact_a_data.get("value", "")
	var value_b = fact_b_data.get("value", "")
	var category_a = fact_a_data.get("category", "")
	var category_b = fact_b_data.get("category", "")
	var source_a = fact_a_data.get("source", "")
	var source_b = fact_b_data.get("source", "")
	
	# Determine relationship type
	var relationship_type = _determine_relationship(category_a, category_b, value_a, value_b, source_a, source_b)
	result.relationship = relationship_type
	
	# Perform NLP analysis
	var nlp_a = NLPAnalyzer.analyze_text(value_a)
	var nlp_b = NLPAnalyzer.analyze_text(value_b)
	
	var classification_a = nlp_a.classification
	var classification_b = nlp_b.classification
	var fake_score_a = nlp_a.fake_news_score
	var fake_score_b = nlp_b.fake_news_score
	
	var comparison = NLPAnalyzer.compare_analyses(nlp_a, nlp_b, value_a, value_b)
	
	nlp_a = null
	nlp_b = null
	
	# Convert entity_matches to dictionaries
	var entity_matches_dict = []
	if comparison.has("entity_matches"):
		for match_item in comparison.entity_matches:
			if typeof(match_item) == TYPE_DICTIONARY:
				entity_matches_dict.append(match_item)
			else:
				entity_matches_dict.append({
					"type": match_item.get("type", "") if match_item.has_method("get") else "",
					"entity_a": match_item.get("entity_a", "") if match_item.has_method("get") else "",
					"entity_b": match_item.get("entity_b", "") if match_item.has_method("get") else "",
					"similarity": match_item.get("similarity", 0.0) if match_item.has_method("get") else 0.0
				})
	
	# Build entity analysis
	var entity_info = []
	if entity_matches_dict.size() > 0:
		entity_info.append("Matching Entities:")
		for match in entity_matches_dict:
			entity_info.append("  • %s (%s): %.0f%% match" % [match.get("type", ""), match.get("entity_a", ""), match.get("similarity", 0.0) * 100])
		result.entity_analysis = "\n".join(entity_info)
	
	# Build classification analysis
	if comparison.classification_match:
		result.classification_analysis = "Classification: Both classified as %s" % classification_a
	else:
		result.classification_analysis = "Classification Mismatch: Article=%s, Tip=%s" % [classification_a, classification_b]
	
	# Build keyword analysis
	if comparison.keyword_overlap > 0.3:
		result.keyword_analysis = "Keyword Overlap: %.0f%% - High semantic similarity" % (comparison.keyword_overlap * 100)
	else:
		result.keyword_analysis = "Keyword Overlap: %.0f%% - Low semantic similarity" % (comparison.keyword_overlap * 100)
	
	# Determine discrepancy
	var overall_score = comparison.overall_match_score
	var semantic_similarity = comparison.semantic_similarity
	
	if overall_score < 0.4:
		result.is_discrepancy = true
		result.reason = "⚠ CONTRADICTION DETECTED (Match: %.0f%%)" % (overall_score * 100)
		
		if fake_score_a > 0.3 or fake_score_b > 0.3:
			result.truth_status = "🚨 WARNING: Fake news patterns detected!\nThese facts contradict each other - one may be false."
		else:
			result.truth_status = "❌ Facts contradict each other.\nThe article and tip provide conflicting information.\nVerify which source is reliable."
			
	elif overall_score >= 0.4 and overall_score < 0.7:
		result.is_discrepancy = false
		result.reason = "⚠ PARTIAL MATCH (Match: %.0f%%)" % (overall_score * 100)
		result.truth_status = "⚠ Facts are similar but not identical.\nReview details carefully - there may be subtle differences."
		
	else:
		result.is_discrepancy = false
		result.reason = "✓ HIGH MATCH (Match: %.0f%%)" % (overall_score * 100)
		result.truth_status = "✓ Facts are consistent!\nThe article and tip support each other.\nThis increases credibility."
	
	# Add detailed analysis
	var detailed_analysis = []
	if result.relationship != "":
		detailed_analysis.append(result.relationship)
	detailed_analysis.append(result.reason)
	if result.entity_analysis != "":
		detailed_analysis.append(result.entity_analysis)
	detailed_analysis.append(result.classification_analysis)
	detailed_analysis.append(result.keyword_analysis)
	
	result.reason = "\n".join(detailed_analysis)
	comparison.clear()
	
	return result

static func _determine_relationship(cat_a: String, cat_b: String, val_a: String, val_b: String, src_a: String, src_b: String) -> String:
	if cat_a == cat_b:
		return "Direct Comparison: Both facts about '%s'" % cat_a
	
	if (cat_a == "Event" and cat_b == "Timeline") or (cat_b == "Event" and cat_a == "Timeline"):
		return "Related: Event and its Timeline"
	if (cat_a == "Claim" and cat_b == "Evidence") or (cat_b == "Claim" and cat_a == "Evidence"):
		return "Related: Claim vs Evidence"
	if (cat_a == "Statement" and cat_b == "Contradiction") or (cat_b == "Statement" and cat_a == "Contradiction"):
		return "Contradictory: Statement vs Contradiction"
	
	if src_b == "Tip" and cat_b in ["Warning", "Contradiction", "Anomaly", "Pressure"]:
		return "Tip Contradicts: Tip reveals issues with article fact"
	if src_a == "Tip" and cat_a in ["Warning", "Contradiction", "Anomaly", "Pressure"]:
		return "Tip Contradicts: Tip reveals issues with article fact"
	
	return "Different Aspects: Facts cover different aspects of the story"

