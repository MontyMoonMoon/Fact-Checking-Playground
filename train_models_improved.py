"""
Improved ML Training Script
Combines synthetic dataset with game email data for better model performance
Uses binary classification (Low/Medium vs High) to match API usage
"""
import pandas as pd
import json
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from scipy.sparse import hstack
import joblib
import numpy as np

print("=" * 60)
print("IMPROVED ML MODEL TRAINING")
print("=" * 60)

# ========== LOAD SYNTHETIC DATASET ==========
print("\n[1/5] Loading synthetic dataset...")
try:
    df_synthetic = pd.read_csv("final_news_dataset.csv")
    print(f"✓ Loaded {len(df_synthetic)} synthetic articles")
except FileNotFoundError:
    print("⚠ Warning: synthetic_news_dataset.csv not found. Using game data only.")
    df_synthetic = pd.DataFrame()

# ========== LOAD GAME EMAIL DATA ==========
print("\n[2/5] Loading game email data...")
def load_game_emails():
    """Extract articles from game email JSON and convert to training format"""
    try:
        with open("JSONs/email_news.json", "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print("⚠ Warning: email_news.json not found.")
        return pd.DataFrame()
    
    game_articles = []
    
    for map_key in ["map_01", "map_02", "map_03"]:
        if map_key in data:
            for email in data[map_key]:
                news_data = email.get("news_data", {})
                article_text = news_data.get("article_text", "")
                
                if not article_text or article_text.strip() == "":
                    continue
                
                # Extract features from email structure
                facts = news_data.get("facts", [])
                evidence_count = len([f for f in facts if f.get("source") == "Article"])
                if evidence_count == 0:
                    evidence_count = len(facts)  # Fallback to total facts
                if evidence_count == 0:
                    evidence_count = 1  # Minimum
                
                # Use integrity_score as truth probability
                integrity_score = news_data.get("integrity_score", 0.5)
                truth_probability = integrity_score
                
                # Infer reliability from sender and stance
                sender = email.get("sender", "")
                stance = news_data.get("stance", "Neutral")
                tip_text = news_data.get("tip_text", "")
                
                # Source reliability based on sender and stance
                if "Government" in sender or "Ministry" in sender or "SyndiNet" in sender:
                    if stance == "Pro-Government":
                        source_reliability = 0.3  # Low - propaganda
                    else:
                        source_reliability = 0.5  # Medium
                elif "Anonymous" in sender or "Whistleblower" in sender or "Source" in sender:
                    source_reliability = 0.4  # Medium-low
                elif "Investigative" in sender or "Reporter" in sender:
                    source_reliability = 0.7  # Medium-high
                else:
                    if stance in ["Investigative", "Neutral", "Skeptical"]:
                        source_reliability = 0.7
                    else:
                        source_reliability = 0.5
                
                # Calculate sentiment from stance
                if stance in ["Pro-Government", "Pro-Celebrity"]:
                    sentiment_score = 0.7
                elif stance in ["Critical", "Skeptical", "Investigative"]:
                    sentiment_score = 0.3
                else:
                    sentiment_score = 0.5
                
                # Calculate contradiction score from tip
                contradiction_score = 0.3  # Default low
                if tip_text:
                    # Count contradiction indicators in tip
                    contradiction_keywords = ["contradict", "warning", "anomaly", "pressure", "conflict"]
                    tip_lower = tip_text.lower()
                    contradiction_count = sum(1 for kw in contradiction_keywords if kw in tip_lower)
                    if contradiction_count > 0:
                        contradiction_score = min(0.3 + (contradiction_count * 0.2), 1.0)
                
                # Calculate propaganda score
                propaganda_score = 0.5
                if stance == "Pro-Government":
                    propaganda_score = 0.8
                elif "Government" in sender or "Ministry" in sender:
                    propaganda_score = 0.7
                elif "SyndiNet" in sender:
                    propaganda_score = 0.75
                
                if integrity_score < 0.5:
                    propaganda_score = min(propaganda_score + 0.2, 1.0)
                
                # Check for propaganda keywords
                article_lower = article_text.lower()
                propaganda_keywords = ["unprecedented", "record-breaking", "overwhelming support", 
                                      "historic levels", "all-time high", "redacted"]
                for keyword in propaganda_keywords:
                    if keyword in article_lower:
                        propaganda_score = min(propaganda_score + 0.1, 1.0)
                
                # Infer source_type
                sender_lower = sender.lower()
                if "government" in sender_lower or "ministry" in sender_lower or "press office" in sender_lower or "sovereign council" in sender_lower:
                    source_type = "state_media"
                elif "syndinet" in sender_lower:
                    source_type = "state_media"
                elif "anonymous" in sender_lower or "whistleblower" in sender_lower or "source" in sender_lower:
                    source_type = "anonymous_tip"
                elif "foreign" in sender_lower or "international" in sender_lower:
                    source_type = "foreign_press"
                else:
                    source_type = "independent"
                
                # Detect topic
                article_lower = article_text.lower()
                if "celebrity" in article_lower or "entertainment" in sender_lower:
                    topic = "celebrity"
                elif "senate" in article_lower or "government" in article_lower or "political" in article_lower or "corruption" in article_lower:
                    topic = "politics"
                elif "military" in article_lower or "defense" in article_lower or "war" in article_lower:
                    topic = "military"
                elif "economy" in article_lower or "economic" in article_lower or "supply" in article_lower or "shortage" in article_lower:
                    topic = "economy"
                elif "protest" in article_lower or "demonstration" in article_lower or "rally" in article_lower:
                    topic = "protest"
                elif "health" in article_lower or "hospital" in article_lower or "medical" in article_lower:
                    topic = "health"
                else:
                    topic = "politics"
                
                # Use first 500 chars as "headline" for consistency with training
                headline = article_text[:500] if len(article_text) > 500 else article_text
                
                game_articles.append({
                    "headline": headline,
                    "sentiment_score": sentiment_score,
                    "evidence_count": evidence_count,
                    "contradiction_score": contradiction_score,
                    "propaganda_pattern_score": propaganda_score,
                    "source_type": source_type,
                    "topic": topic,
                    "source_reliability": source_reliability,
                    "truth_probability": truth_probability
                })
    
    return pd.DataFrame(game_articles)

df_game = load_game_emails()
print(f"✓ Loaded {len(df_game)} game articles")

# ========== COMBINE DATASETS ==========
print("\n[3/5] Combining datasets...")
if len(df_synthetic) > 0 and len(df_game) > 0:
    # Use 70% synthetic, 30% game for balanced training
    # This ensures model sees both synthetic patterns and real game content
    df_combined = pd.concat([df_synthetic, df_game], ignore_index=True)
    print(f"✓ Combined dataset: {len(df_combined)} articles ({len(df_synthetic)} synthetic + {len(df_game)} game)")
elif len(df_synthetic) > 0:
    df_combined = df_synthetic
    print(f"✓ Using synthetic dataset only: {len(df_combined)} articles")
elif len(df_game) > 0:
    df_combined = df_game
    print(f"✓ Using game dataset only: {len(df_combined)} articles")
else:
    raise ValueError("No data available! Need either synthetic_news_dataset.csv or email_news.json")

# ========== PREPARE FEATURES ==========
print("\n[4/5] Preparing features...")

# Use article text (first 500 chars for consistency)
df_combined["text_for_analysis"] = df_combined["headline"].str[:500]

# Define features
text_data = df_combined["text_for_analysis"]
numeric_features = [
    "sentiment_score",
    "evidence_count",
    "contradiction_score",
    "propaganda_pattern_score"
]

# Encode categorical columns
df_encoded = pd.get_dummies(df_combined[["source_type", "topic"]], drop_first=True)
X_structured = pd.concat([df_combined[numeric_features], df_encoded], axis=1)

# Convert to binary classification (Low/Medium vs High)
# This matches your API usage: predict_proba[0][1] = probability of High class
df_combined["is_reliable"] = (df_combined["source_reliability"] >= 0.66).astype(int)
df_combined["is_truthful"] = (df_combined["truth_probability"] >= 0.66).astype(int)

# Filter NaN
df_combined.dropna(subset=["is_reliable", "is_truthful"], inplace=True)
text_data_filtered = df_combined["text_for_analysis"]
X_structured_filtered = X_structured.loc[df_combined.index]

y_rf = df_combined["is_reliable"].astype(int)
y_log = df_combined["is_truthful"].astype(int)

print(f"✓ Binary classification:")
print(f"  - Reliability: {y_rf.sum()} High, {len(y_rf) - y_rf.sum()} Low/Medium")
print(f"  - Truthfulness: {y_log.sum()} High, {len(y_log) - y_log.sum()} Low/Medium")

# ========== TRAIN-TEST SPLIT ==========
X_train_text, X_test_text, X_train_struct, X_test_struct, y_train_rf, y_test_rf, y_train_log, y_test_log = train_test_split(
    text_data_filtered, X_structured_filtered, y_rf, y_log, test_size=0.2, random_state=42
)

print(f"✓ Train set: {len(X_train_text)} articles")
print(f"✓ Test set: {len(X_test_text)} articles")

# ========== TEXT VECTORIZATION ==========
print("\n[5/5] Training models...")
# Increased max_features for full articles, added n-grams for phrase detection
vectorizer = TfidfVectorizer(stop_words="english", max_features=5000, ngram_range=(1, 2))
X_train_text_vec = vectorizer.fit_transform(X_train_text)
X_test_text_vec = vectorizer.transform(X_test_text)

# ========== SCALE STRUCTURED FEATURES ==========
scaler = StandardScaler()
X_train_struct_scaled = scaler.fit_transform(X_train_struct)
X_test_struct_scaled = scaler.transform(X_test_struct)

# ========== COMBINE FEATURES ==========
X_train_combined = hstack([X_train_text_vec, X_train_struct_scaled])
X_test_combined = hstack([X_test_text_vec, X_test_struct_scaled])

# ========== TRAIN MODELS ==========
# Random Forest for source reliability
rf_model = RandomForestClassifier(
    n_estimators=200, 
    random_state=42, 
    class_weight="balanced",  # Handle imbalanced data
    max_depth=20,
    min_samples_split=5
)
rf_model.fit(X_train_combined, y_train_rf)

# Logistic Regression for truth probability
log_reg_model = LogisticRegression(
    max_iter=1000, 
    class_weight="balanced",  # Handle imbalanced data
    C=1.0,
    solver="lbfgs"
)
log_reg_model.fit(X_train_combined, y_train_log)

# ========== EVALUATE MODELS ==========
print("\n" + "=" * 60)
print("MODEL EVALUATION")
print("=" * 60)

rf_preds = rf_model.predict(X_test_combined)
log_preds = log_reg_model.predict(X_test_combined)

print("\n=== Random Forest Classifier (Source Reliability - Binary) ===")
print(f"Accuracy: {accuracy_score(y_test_rf, rf_preds):.3f}")
print("\nClassification Report:")
print(classification_report(y_test_rf, rf_preds, target_names=["Low/Medium", "High"]))
print("\nConfusion Matrix:")
print(confusion_matrix(y_test_rf, rf_preds))

print("\n=== Logistic Regression (Truth Probability - Binary) ===")
print(f"Accuracy: {accuracy_score(y_test_log, log_preds):.3f}")
print("\nClassification Report:")
print(classification_report(y_test_log, log_preds, target_names=["Low/Medium", "High"]))
print("\nConfusion Matrix:")
print(confusion_matrix(y_test_log, log_preds))

# ========== EXPORT MODELS ==========
print("\n" + "=" * 60)
print("EXPORTING MODELS")
print("=" * 60)

joblib.dump(vectorizer, "vectorizer.pkl")
joblib.dump(scaler, "scaler.pkl")
joblib.dump(rf_model, "rf_model.pkl")
joblib.dump(log_reg_model, "log_model.pkl")

print("\n✓ Models trained, evaluated, and exported!")
print("✓ Files saved:")
print("  - vectorizer.pkl")
print("  - scaler.pkl")
print("  - rf_model.pkl")
print("  - log_model.pkl")
print("\n✓ Model Details:")
print(f"  - RF predicts reliability (class 1 = High reliability)")
print(f"  - LogReg predicts truthfulness (class 1 = High truth)")
print(f"  - API will use predict_proba[0][1] correctly for binary classification")
print(f"  - Training data: {len(df_combined)} articles")
print(f"  - Text features: 5000 TF-IDF features with n-grams (1,2)")

