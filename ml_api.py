from fastapi import FastAPI
from pydantic import BaseModel
import joblib

app = FastAPI()

# Load trained components
vectorizer = joblib.load("vectorizer.pkl")
rf_model = joblib.load("rf_model.pkl")
log_model = joblib.load("log_model.pkl")

class Article(BaseModel):
    text: str

@app.post("/analyze")
def analyze(article: Article):
    text_vec = vectorizer.transform([article.text])

    rf_pred = rf_model.predict_proba(text_vec)[0][1]  # Probability of real news
    log_pred = log_model.predict_proba(text_vec)[0][1]

    avg_score = (rf_pred + log_pred) / 2

    return {
        "random_forest_score": round(rf_pred, 3),
        "logistic_regression_score": round(log_pred, 3),
        "average_score": round(avg_score, 3),
        "result": "Likely Real" if avg_score > 0.5 else "Likely Fake"
    }
