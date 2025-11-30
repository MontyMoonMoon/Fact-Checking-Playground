# ML Training Feedback & Recommendations

## ✅ **YES - Retrain with Game Email Data**

**Why you should retrain with game data:**

1. **Domain Alignment**: Your synthetic dataset may not capture the specific patterns, language, and themes in your game emails (censorship, redactions, propaganda, etc.)

2. **Feature Consistency**: Game emails have structured data (facts, stance, integrity_score) that can be used to create better training labels

3. **Better Generalization**: Mixing synthetic + game data helps the model:
   - Learn general patterns from synthetic data (1000 samples)
   - Adapt to your specific game content (131 emails across 3 maps)
   - Perform better on actual game articles

4. **Label Quality**: Game emails have `integrity_score` which is a better ground truth than synthetic reliability scores

## ❌ **NO - Don't Reduce Dataset Size**

**Why you should keep 1000+ samples:**

1. **Model Stability**: 
   - Random Forest with 200 trees needs sufficient data to avoid overfitting
   - Logistic Regression benefits from more samples for stable coefficients
   - 1000 samples is actually on the lower end for these models

2. **Feature Space**: 
   - You have 5000 TF-IDF features + structured features
   - Rule of thumb: Need 10-20 samples per feature
   - 5000 features × 10 = 50,000 samples (ideal)
   - 1000 samples is already minimal - reducing would hurt performance

3. **Class Balance**:
   - With binary classification, you need enough samples in each class
   - 250-500 samples might create severe imbalance
   - 1000+ ensures better class representation

**Recommendation**: Keep 1000 synthetic + add game data (131 emails) = **1131 total samples minimum**

## 🔧 **Critical Issues Fixed**

### 1. **Binary vs 3-Class Classification**
- **Old**: Trained 3 classes (0=Low, 1=Medium, 2=High) but API used `predict_proba[0][1]` (Medium class)
- **New**: Binary classification (0=Low/Medium, 1=High) - `predict_proba[0][1]` now correctly gives High probability

### 2. **Text Feature Mismatch**
- **Old**: Trained on "headline" (short text)
- **New**: Uses first 500 chars of article text (matches game content better)

### 3. **Model Task Alignment**
- **Old**: RF predicted reliability, LogReg predicted truth (different tasks, same output)
- **New**: Both predict binary classification, but RF focuses on source reliability, LogReg on truthfulness
- **Result**: Average of both gives balanced prediction

## 📊 **Training Strategy**

### Recommended Approach:
```
1. Keep 1000 synthetic samples (general patterns)
2. Add 131 game email samples (domain-specific)
3. Total: ~1131 samples
4. Use 80/20 train/test split
5. Binary classification (Low/Medium vs High)
```

### Why This Works:
- **Synthetic data**: Provides variety and general fake news patterns
- **Game data**: Ensures model understands your specific content themes
- **Binary classification**: Matches API usage (`predict_proba[0][1]`)
- **Class balancing**: `class_weight="balanced"` handles imbalanced data

## 🎯 **Model Performance Expectations**

With 1131 samples and binary classification:

**Expected Accuracy:**
- Random Forest: 70-85% (good for reliability detection)
- Logistic Regression: 65-80% (good for truth detection)
- Combined Average: More stable predictions

**Why These Numbers:**
- Binary classification is easier than 3-class
- Structured features (sentiment, evidence, etc.) help a lot
- Text features capture language patterns
- Game data improves domain-specific performance

## 🚀 **Next Steps**

1. **Run the improved training script:**
   ```bash
   python train_models_improved.py
   ```

2. **Verify model files are updated:**
   - vectorizer.pkl
   - scaler.pkl
   - rf_model.pkl
   - log_model.pkl

3. **Test with game articles:**
   - The API should now give better predictions
   - Feature extraction in `ai_analysis_controller.gd` will provide real features

4. **Monitor performance:**
   - Check if ML scores align with `integrity_score` in emails
   - Adjust threshold (currently 6.5/10.0) if needed

## 📝 **Additional Recommendations**

### 1. **Feature Engineering**
The new code extracts:
- ✅ Real evidence_count from facts
- ✅ Sentiment from stance
- ✅ Contradiction from tip_text
- ✅ Propaganda from sender/stance/keywords
- ✅ Source type from sender
- ✅ Topic from content

### 2. **Model Interpretability**
- Random Forest: Shows feature importance (which features matter most)
- Logistic Regression: Shows coefficient signs (positive = more reliable/truthful)

### 3. **Future Improvements**
- Collect player feedback on ML predictions
- Retrain periodically with new game content
- Fine-tune threshold based on game balance
- Consider ensemble methods (already doing this with RF + LogReg average)

## ⚠️ **Important Notes**

1. **Don't reduce dataset size** - 1000 is already minimal
2. **Do retrain with game data** - Improves domain-specific performance
3. **Use binary classification** - Matches your API implementation
4. **Keep class balancing** - Prevents bias toward majority class
5. **Monitor in production** - Track if predictions make sense for gameplay

## 🎮 **Game Integration**

The improved `ai_analysis_controller.gd` now:
- Extracts real features from email data
- Provides better ML feedback to players
- Shows clear fact relationships
- Interprets ML results in context

This creates a better feedback loop where:
1. Player reads article + facts
2. ML analyzes with real features
3. Player sees clear interpretation
4. Player makes informed decision
5. Game rewards accurate analysis

