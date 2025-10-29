import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report
from scipy.sparse import hstack
import joblib
import numpy as np


# === Load dataset ===
df = pd.read_csv("synthetic_news_dataset.csv")

# --- Define features ---
text_data = df["headline"]

numeric_features = [
    "sentiment_score",
    "evidence_count",
    "contradiction_score",
    "propaganda_pattern_score"
]

# One-hot encode categorical columns
df_encoded = pd.get_dummies(df[["source_type", "topic"]], drop_first=True)

# Combine all structured features
X_structured = pd.concat([df[numeric_features], df_encoded], axis=1)

# === Convert continuous targets to discrete classes ===
# 3 reliability levels (low, medium, high)
df["reliability_class"] = pd.cut(df["source_reliability"], bins=[0, 0.33, 0.66, 1.0], labels=[0, 1, 2])
df["truth_class"] = pd.cut(df["truth_probability"], bins=[0, 0.33, 0.66, 1.0], labels=[0, 1, 2])

# Drop rows with NaN values in the target columns
df.dropna(subset=["reliability_class", "truth_class"], inplace=True)

# Apply the same row filtering to features
text_data_filtered = df["headline"]
X_structured_filtered = pd.concat([df[numeric_features], df_encoded.loc[df.index]], axis=1)


y_rf = df["reliability_class"].astype(int)
y_log = df["truth_class"].astype(int)

# === Train-test split ===
X_train_text, X_test_text, X_train_struct, X_test_struct, y_train_rf, y_test_rf, y_train_log, y_test_log = train_test_split(
    text_data_filtered, X_structured_filtered, y_rf, y_log, test_size=0.2, random_state=42
)

# === Text Vectorization ===
vectorizer = TfidfVectorizer(stop_words="english", max_features=3000)
X_train_text_vec = vectorizer.fit_transform(X_train_text)
X_test_text_vec = vectorizer.transform(X_test_text)

# === Scale structured features ===
scaler = StandardScaler()
X_train_struct_scaled = scaler.fit_transform(X_train_struct)
X_test_struct_scaled = scaler.transform(X_test_struct)

# === Combine features ===
X_train_combined = hstack([X_train_text_vec, X_train_struct_scaled])
X_test_combined = hstack([X_test_text_vec, X_test_struct_scaled])

# === Train Random Forest ===
rf_model = RandomForestClassifier(n_estimators=200, random_state=42)
rf_model.fit(X_train_combined, y_train_rf)

# === Train Logistic Regression ===
log_reg_model = LogisticRegression(max_iter=1000, multi_class="auto")
log_reg_model.fit(X_train_combined, y_train_log)

# === Evaluate Models ===
rf_preds = rf_model.predict(X_test_combined)
log_preds = log_reg_model.predict(X_test_combined)

print("\n=== Random Forest Classifier (Source Reliability) ===")
print("Accuracy:", round(accuracy_score(y_test_rf, rf_preds), 3))
print(classification_report(y_test_rf, rf_preds, target_names=["Low", "Medium", "High"]))

print("\n=== Logistic Regression (Truth Probability) ===")
print("Accuracy:", round(accuracy_score(y_test_log, log_preds), 3))
print(classification_report(y_test_log, log_preds, target_names=["Low", "Medium", "High"]))

# === Save trained components ===
joblib.dump(vectorizer, "vectorizer.pkl")
joblib.dump(scaler, "scaler.pkl")
joblib.dump(rf_model, "rf_model.pkl")
joblib.dump(log_reg_model, "log_model.pkl")

print("\n✅ Models trained, evaluated, and saved successfully.")