from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import pandas as pd
import numpy as np
from scipy.sparse import hstack
import sys, os


app = FastAPI()

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    base_path = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)

#Load trained components
vectorizer = joblib.load(resource_path("vectorizer.pkl"))
scaler = joblib.load(resource_path("scaler.pkl"))
rf_model = joblib.load(resource_path("rf_model.pkl"))
log_model = joblib.load(resource_path("log_model.pkl"))

# Get scaler feature names 
try:
    SCALER_FEATURES = list(scaler.feature_names_in_)
except AttributeError:
    SCALER_FEATURES = None 


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)


#Input schema
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

    #Vector Text
    text_vec = vectorizer.transform([article.text])

    #Features
    numeric_cols = ["sentiment_score", "evidence_count", "contradiction_score", "propaganda_pattern_score"]
    source_types = ["state_media", "independent", "foreign_press", "anonymous_tip"]
    topic_types = ["celebrity", "politics", "military", "economy", "protest", "health"]

    source_cols = [f"source_type_{s}" for s in source_types[1:]]  # drop_first=True
    topic_cols = [f"topic_{t}" for t in topic_types[1:]]
    all_cols = numeric_cols + source_cols + topic_cols

    source_encoded = [1 if article.source_type == s else 0 for s in source_types[1:]]
    topic_encoded = [1 if article.topic == t else 0 for t in topic_types[1:]]

    features = [
        article.sentiment_score,
        article.evidence_count,
        article.contradiction_score,
        article.propaganda_pattern_score
    ] + source_encoded + topic_encoded

    structured_df = pd.DataFrame([features], columns=all_cols)

    # Align columns to scaler’s expected set toavoid mismatch
    if SCALER_FEATURES:
        for col in SCALER_FEATURES:
            if col not in structured_df.columns:
                structured_df[col] = 0  # missing column → 0
        structured_df = structured_df[SCALER_FEATURES]  # reorder + drop extras

    structured_scaled = scaler.transform(structured_df)

    #Combine text and structure
    X_input = hstack([text_vec, structured_scaled])

    #Model Predictions
    rf_probs = rf_model.predict_proba(X_input)
    log_probs = log_model.predict_proba(X_input)

    # Extract real class probability (index 1), scaled to 0–10 as opposed to 0-1

    rf_score = float(rf_probs[0][1]) * 10
    log_score = float(log_probs[0][1]) * 10

    avg_score = (rf_score + log_score) / 2

    # Verdict threshold || changeable with accordance to the requirements
    # adjusted threshold for 7 for likeability
    
    verdict = "Likely Real" if avg_score >= 7.0 else "Likely Fake"

    return {
        "random_forest_score": round(rf_score, 3),
        "logistic_regression_score": round(log_score, 3),
        "average_score": round(avg_score, 3),
        "result": verdict
    }
