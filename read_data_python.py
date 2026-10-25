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