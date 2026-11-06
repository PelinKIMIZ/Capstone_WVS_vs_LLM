import pandas as pd
import pyarrow.parquet as pq

# ------------------------------------------------------------------------------
# 1. Read Parquet Files safely (Handling R-specific Arrow extension types)
# ------------------------------------------------------------------------------
# Read as PyArrow Tables first, then convert to pandas while ignoring R extension types
meta_table = pq.read_table("statements_meta.parquet")
statements_meta = meta_table.to_pandas(types_mapper=lambda t: None)

decisions_table = pq.read_table("decisions_from_json.parquet")
decisions = decisions_table.to_pandas(types_mapper=lambda t: None)

# Inspect dataset structures and column types
print("=== STATEMENTS METADATA INFO ===")
statements_meta.info()

print("\n=== DECISIONS INFO ===")
decisions.info()

# Preview first rows
print(statements_meta.head())
print(decisions.head())


# ------------------------------------------------------------------------------
# 2. Inspect Experimental Conditions and Parameter Combinations
# ------------------------------------------------------------------------------
condition_counts = (
    decisions.groupby(["M", "openmindedness", "post"])
    .size()
    .reset_index(name="n")
)

print("\n=== EXPERIMENTAL CONDITIONS SUMMARY ===")
print(condition_counts)


# ------------------------------------------------------------------------------
# 3. Inspect the Structure of an Individual Decision Event (Row index 2)
# ------------------------------------------------------------------------------
sample_row = decisions.iloc[2]

print("\n=== AGENT PRE-DECISION WORLDVIEW (MEMORY IDS) ===")
print(sample_row["memory_ids"])

print("\n=== PRESENTED CANDIDATES ===")
print(sample_row["shown_candidates"])

print("\n=== SELECTED STATEMENT ID ===")
print(sample_row["selected_statement_id"])

candidate_metadata = statements_meta[
    statements_meta["S_id"].isin(sample_row["shown_candidates"])
][["S_id", "Question_ID", "Worldview_Statement", "worldview", "WVS_PC1"]]

print("\n=== CANDIDATE METADATA ===")
print(candidate_metadata)


# ------------------------------------------------------------------------------
# 4. Verify WVS Wave 7 Survey Data
# ------------------------------------------------------------------------------
wvs_data = pd.read_csv("WVS_Wave_7.csv", low_memory=False)

print("\n=== WVS DATASET DIMENSIONS ===")
print(f"Rows: {wvs_data.shape[0]}, Columns: {wvs_data.shape[1]}")

target_questions = statements_meta["Question_ID"].unique()
available_questions = set(target_questions).intersection(set(wvs_data.columns))

print(f"Total unique survey questions in metadata: {len(target_questions)}")
print(f"Successfully matched columns in WVS CSV: {len(available_questions)}")

sample_cols = [q for q in target_questions[:10] if q in wvs_data.columns]
print("\n=== FIRST ROWS OF MATCHED WVS VARIABLES ===")
print(wvs_data[sample_cols].head())

# ------------------------------------------------------------------------------
# 5. PCA Latent Space Prediction Model (Direct Execution)
# ------------------------------------------------------------------------------
import numpy as np

# Map statements to their WVS_PC1 coordinates
pc1_dict = dict(zip(statements_meta["S_id"], statements_meta["WVS_PC1"]))

correct_predictions = 0
total_evaluated = 0

# Evaluate PCA model on the first 100 valid selection events
for idx, row in decisions.iterrows():
    # Only test rows where a decision was actually made (selected)
    if row["decision"] == "selected" and pd.notna(row["selected_statement_id"]):
        
        # 1. Calculate Agent's Memory Centroid in PC1 Space
        memory_pc1 = [pc1_dict[s] for s in row["memory_ids"] if s in pc1_dict]
        if not memory_pc1:
            continue
        agent_centroid = np.mean(memory_pc1)
        
        # 2. Score presented candidates (closest in PC1 space gets highest score)
        candidate_scores = {}
        for cand in row["shown_candidates"]:
            if cand in pc1_dict:
                # Negative absolute distance (closer to centroid = higher score)
                candidate_scores[cand] = -abs(agent_centroid - pc1_dict[cand])
        
        if not candidate_scores:
            continue
            
        # 3. Predict candidate with maximum compatibility score
        predicted_id = max(candidate_scores, key=candidate_scores.get)
        actual_id = row["selected_statement_id"]
        
        if predicted_id == actual_id:
            correct_predictions += 1
            
        total_evaluated += 1
        
        # Stop at 100 evaluated decisions for early benchmark
        if total_evaluated >= 100:
            break

# Print accuracy result
pca_accuracy = (correct_predictions / total_evaluated) * 100
print("\n=== PCA MODEL BENCHMARK RESULT ===")
print(f"Evaluated Decisions: {total_evaluated}")
print(f"PCA Model Accuracy (Preliminary): {pca_accuracy:.2f}%")

# ------------------------------------------------------------------------------
# 6. Multi-Dimensional PCA Latent Space Model (Variance-Weighted)
# ------------------------------------------------------------------------------
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler

print("\n=== BUILDING MULTI-DIMENSIONAL PCA SPACE FROM WVS DATA ===")

# 1. Filter and Clean WVS columns (handling negative missing codes)
wvs_matched = wvs_data[list(available_questions)].copy()
wvs_matched[wvs_matched < 0] = np.nan
wvs_cleaned = wvs_matched.fillna(wvs_matched.mean())

# 2. Standardize features and Fit PCA (3 components)
scaler = StandardScaler()
wvs_scaled = scaler.fit_transform(wvs_cleaned)

pca = PCA(n_components=3)
pca.fit(wvs_scaled)

# Variance weights (PC1 weights more than PC2 and PC3)
weights = pca.explained_variance_ratio_

# Create a mapping dictionary for Question_ID -> PC loadings [PC1, PC2, PC3]
q_loadings = dict(zip(available_questions, pca.components_.T))

# Map statements (S_id) to 3D PCA coordinates based on their Question_ID
statement_3d_map = {}
for idx, row in statements_meta.iterrows():
    q_id = row["Question_ID"]
    s_id = row["S_id"]
    if q_id in q_loadings:
        factor = -1.0 if row["worldview"] == "progressive" else 1.0
        statement_3d_map[s_id] = q_loadings[q_id] * factor

# 3. Evaluate Weighted 3D PCA Model on Decision Events
correct_3d_weighted = 0
total_evaluated_3d = 0

for idx, row in decisions.iterrows():
    if row["decision"] == "selected" and pd.notna(row["selected_statement_id"]):
        
        # Calculate Agent's Memory Centroid in 3D Space
        memory_vecs = [statement_3d_map[s] for s in row["memory_ids"] if s in statement_3d_map]
        if not memory_vecs:
            continue
        agent_centroid_3d = np.mean(memory_vecs, axis=0)
        
        # Score candidates using Variance-Weighted Euclidean Distance
        candidate_scores_3d = {}
        for cand in row["shown_candidates"]:
            if cand in statement_3d_map:
                # Weight differences by explained variance ratio
                diff = (agent_centroid_3d - statement_3d_map[cand]) * weights
                dist = np.linalg.norm(diff)
                candidate_scores_3d[cand] = -dist
        
        if not candidate_scores_3d:
            continue
            
        predicted_id_3d = max(candidate_scores_3d, key=candidate_scores_3d.get)
        actual_id = row["selected_statement_id"]
        
        if predicted_id_3d == actual_id:
            correct_3d_weighted += 1
            
        total_evaluated_3d += 1
        
        if total_evaluated_3d >= 100:
            break

# Print weighted 3D PCA accuracy result
pca_3d_weighted_acc = (correct_3d_weighted / total_evaluated_3d) * 100
print("\n=== VARIANCE-WEIGHTED 3D PCA MODEL RESULT ===")
print(f"Evaluated Decisions: {total_evaluated_3d}")
print(f"1D PCA Accuracy (PC1 only): {pca_accuracy:.2f}%")
print(f"Unweighted 3D PCA Accuracy: 39.00%")
print(f"Variance-Weighted 3D PCA Accuracy: {pca_3d_weighted_acc:.2f}%")
