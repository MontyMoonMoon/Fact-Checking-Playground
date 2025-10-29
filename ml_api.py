from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import pandas as pd
import numpy as np
from scipy.sparse import hstack

app = FastAPI()

# Load trained components
vectorizer = joblib.load("vectorizer.pkl")
scaler = joblib.load("scaler.pkl")
rf_model = joblib.load("rf_model.pkl")
log_model = joblib.load("log_model.pkl")

# Get scaler feature names (safe for later alignment)
try:
    SCALER_FEATURES = list(scaler.feature_names_in_)
except AttributeError:
    SCALER_FEATURES = None  # fallback if missing

class Article(BaseModel):
    text: str
    sentiment_score: float = 0.0
    evidence_count: int = 2
    contradiction_score: float = 0.5
    propaganda_pattern_score: float = 0.5
    source_type: str = "independent"
    topic: str = "politics"

@app.get("/")
def read_root():
    return {"message": "Welcome to the News Analysis API!"}

@app.post("/analyze")
def analyze(article: Article):
    # === TEXT VECTOR ===
    text_vec = vectorizer.transform([article.text])

    # === STRUCTURED FEATURES ===
    numeric_cols = ["sentiment_score", "evidence_count", "contradiction_score", "propaganda_pattern_score"]
    source_types = ["state_media", "independent", "foreign_press", "anonymous_tip"]
    topic_types = ["celebrity", "politics", "military", "economy", "protest", "health"]

    source_cols = [f"source_type_{s}" for s in source_types[1:]]  # drop_first=True
    topic_cols = [f"topic_{t}" for t in topic_types[1:]]
    all_cols = numeric_cols + source_cols + topic_cols

    source_encoded = [1 if article.source_type == s else 0 for s in source_types[1:]]
    topic_encoded = [1 if article.topic == t else 0 for t in topic_types[1:]]
    features = [article.sentiment_score, article.evidence_count,
                article.contradiction_score, article.propaganda_pattern_score] + source_encoded + topic_encoded

    structured_df = pd.DataFrame([features], columns=all_cols)

    # Align columns to scaler’s expected set (avoid mismatch)
    if SCALER_FEATURES:
        for col in SCALER_FEATURES:
            if col not in structured_df.columns:
                structured_df[col] = 0  # missing column → 0
        structured_df = structured_df[SCALER_FEATURES]  # reorder + drop extras

    structured_scaled = scaler.transform(structured_df)

    # === COMBINE TEXT + STRUCTURED ===
    X_input = hstack([text_vec, structured_scaled])

    # === MODEL PREDICTIONS ===
    rf_probs = rf_model.predict_proba(X_input)
    log_probs = log_model.predict_proba(X_input)

    rf_pred = float(np.argmax(rf_probs))
    log_pred = float(np.argmax(log_probs))
    avg_score = (rf_pred + log_pred) / 2
    verdict = "Likely Real" if avg_score >= 5.0 else "Likely Fake"

    return {
        "random_forest_probs": rf_probs.tolist(),
        "logistic_regression_probs": log_probs.tolist(),
        "predicted_reliability": int(rf_pred),
        "predicted_truth": int(log_pred),
        "average_score": round(avg_score, 3),
        "result": verdict
    }
