library(arrow)
library(dplyr)
library(readr)

# ==============================================================================
# 1. Read Simulation Parquet Files
# ==============================================================================

# Read statement metadata (100 statements mapped to WVS questions & PC1)
statements_meta <- read_parquet("statements_meta.parquet")

# Read simulation decisions (1.44M decision events across 108 runs)
decisions <- read_parquet("decisions_from_json.parquet")

# Inspect dataset structures and column types
glimpse(statements_meta)
glimpse(decisions)

# Preview first few rows
head(statements_meta)
head(decisions)


# ==============================================================================
# 2. Inspect Experimental Conditions and Parameter Combinations
# ==============================================================================

# Count decision events across memory size (M), openmindedness, and posting type
decisions %>% 
  count(M, openmindedness, post)


# ==============================================================================
# 3. Inspect Individual Decision Structure (Example: Row 3)
# ==============================================================================

# Active statements held in memory before the decision (agent's worldview)
decisions$memory_ids[[3]]

# Candidate statements presented to the agent (3 for 'feed', variable for 'social')
decisions$shown_candidates[[3]]

# Statement selected by the agent (NA if none_selected)
decisions$selected_statement_id[3]

# Dropped statement if memory capacity was reached
decisions$dropped_statement_id[3]

# Retrieve metadata for the presented candidate statements
statements_meta %>% 
  filter(S_id %in% decisions$shown_candidates[[3]]) %>% 
  select(S_id, Question_ID, Worldview_Statement, worldview, WVS_PC1)


# ==============================================================================
# 4. Read and Verify WVS Wave 7 Survey Data
# ==============================================================================

# Read the full WVS Wave 7 CSV dataset
wvs_data <- read_csv("WVS_Wave_7.csv", show_col_types = FALSE)

# Check dimensions (number of respondents and survey variables)
dim(wvs_data)

# Extract unique target question IDs from the simulation metadata (70 questions)
target_questions <- unique(statements_meta$Question_ID)

# Verify question overlap between simulation metadata and WVS CSV columns
available_questions <- intersect(target_questions, colnames(wvs_data))
cat("Total unique survey questions in metadata:", length(target_questions), "\n")
cat("Successfully matched columns in WVS CSV:", length(available_questions), "\n")

# Preview responses for a subset of the matched target survey items
wvs_data %>% 
  select(any_of(target_questions[1:10])) %>% 
  head()