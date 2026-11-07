library(arrow)
library(dplyr)
library(readr)

# Load statement metadata
statements_meta <- read_parquet("statements_meta.parquet")

# Load LLM simulation decisions
decisions <- read_parquet("decisions_from_json.parquet")

# Load World Values Survey data
wvs_data <- read_csv(
  "WVS_Cross-National_Wave_7_csv_v6_0.csv"
)

# Inspect the datasets
dim(statements_meta)
dim(decisions)
dim(wvs_data)

# Inspect statement metadata
glimpse(statements_meta)
# STEP 2: Identify relevant WVS questions

# Extract unique question IDs
target_questions <- statements_meta %>%
  distinct(Question_ID) %>%
  pull(Question_ID)

# Count unique WVS questions
length(target_questions)

# Display the questions
print(target_questions)

# Check which questions exist in WVS data
available_questions <- intersect(
  target_questions,
  names(wvs_data)
)

# Identify missing questions
missing_questions <- setdiff(
  target_questions,
  names(wvs_data)
)

# Display results
length(available_questions)

# STEP 3: Create WVS dataframe

wvs_selected <- wvs_data %>%
  select(any_of(available_questions))

# Check dimensions
dim(wvs_selected)

# Preview data
head(wvs_selected)

# Inspect structure
glimpse(wvs_selected)


# STEP 4: Clean missing values

# Replace negative WVS missing-value codes with NA
wvs_clean <- wvs_selected %>%
  mutate(across(
    everything(),
    ~ replace(.x, .x < 0, NA_real_)
  ))

# Check dimensions
dim(wvs_clean)

# Count missing values for each question
missing_summary <- wvs_clean %>%
  summarise(across(
    everything(),
    ~ sum(is.na(.x))
  ))

# Display missing-value counts
print(missing_summary)

# Calculate percentage of missing values
missing_percent <- wvs_clean %>%
  summarise(across(
    everything(),
    ~ round(mean(is.na(.x)) * 100, 2)
  ))

print(missing_percent)


# STEP 5: Missing-data summary

missing_table <- data.frame(
  Question_ID = names(wvs_clean),
  Missing_Percent = sapply(
    wvs_clean,
    function(x) round(mean(is.na(x)) * 100, 2)
  )
)

# Sort from highest to lowest missing percentage
missing_table <- missing_table %>%
  arrange(desc(Missing_Percent))

# Display the 10 questions with most missing data
head(missing_table, 10)


# STEP 6: Inspect response ranges

response_ranges <- data.frame(
  Question_ID = names(wvs_clean),
  
  Min = sapply(
    wvs_clean,
    function(x) if (all(is.na(x))) NA_real_
    else min(x, na.rm = TRUE)
  ),
  
  Max = sapply(
    wvs_clean,
    function(x) if (all(is.na(x))) NA_real_
    else max(x, na.rm = TRUE)
  ),
  
  Unique_Values = sapply(
    wvs_clean,
    function(x) length(unique(na.omit(x)))
  )
)

# Display first 20 questions
head(response_ranges, 20)

# Open complete table
View(response_ranges)


# STEP 7: Inspect statement approval rules

approval_mapping <- statements_meta %>%
  select(
    S_id,
    Question_ID,
    Worldview_Statement,
    min_approval,
    max_approval,
    special_midpoint_value,
    Answer_Categories
  ) %>%
  arrange(Question_ID, S_id)

# View the complete mapping
View(approval_mapping)

# Check questions with multiple statements
multiple_statements <- statements_meta %>%
  count(Question_ID, name = "Number_of_Statements") %>%
  filter(Number_of_Statements > 1) %>%
  arrange(desc(Number_of_Statements))

print(multiple_statements)

# Inspect the first 10 statement mappings
head(approval_mapping, 10)


# STEP 8: Test statement-level normalization

q106_test <- wvs_clean %>%
  select(Q106) %>%
  mutate(
    Q106_1 = (Q106 - 1) / 9,
    Q106_2 = (10 - Q106) / 9
  )

# Display the first 10 rows
head(q106_test, 10)

# Check score ranges
summary(q106_test)


# STEP 9: Reusable approval normalization

normalize_approval <- function(x, min_approval, max_approval) {
  
  # Check approval endpoints
  if (is.na(min_approval) || is.na(max_approval)) {
    return(rep(NA_real_, length(x)))
  }
  
  # Avoid division by zero
  if (min_approval == max_approval) {
    return(rep(NA_real_, length(x)))
  }
  
  # Calculate normalized approval
  score <- (x - min_approval) /
    (max_approval - min_approval)
  
  # Values outside the specified scale are invalid
  score[score < 0 | score > 1] <- NA_real_
  
  return(score)
}

# Test using Q106_1
test_1 <- normalize_approval(
  wvs_clean$Q106,
  min_approval = 1,
  max_approval = 10
)

# Test using Q106_2
test_2 <- normalize_approval(
  wvs_clean$Q106,
  min_approval = 10,
  max_approval = 1
)

# Compare results
head(data.frame(
  Original = wvs_clean$Q106,
  Q106_1 = test_1,
  Q106_2 = test_2
), 10)


# STEP 10: Identify statements for normalization

normalization_check <- statements_meta %>%
  mutate(
    Has_Endpoints = !is.na(min_approval) &
      !is.na(max_approval),
    
    Different_Endpoints = min_approval != max_approval,
    
    Eligible = Has_Endpoints &
      coalesce(Different_Endpoints, FALSE)
  ) %>%
  select(
    S_id,
    Question_ID,
    min_approval,
    max_approval,
    special_midpoint_value,
    Eligible
  )

# Count eligible and ineligible statements
normalization_check %>%
  count(Eligible)

# Show statements requiring further review
normalization_check %>%
  filter(!Eligible)


# STEP 11: Inspect categorical statements

categorical_statements <- statements_meta %>%
  filter(S_id %in%
           normalization_check$S_id[
             !normalization_check$Eligible
           ]) %>%
  select(
    S_id,
    Question_ID,
    Worldview_Statement,
    min_approval,
    max_approval,
    special_midpoint_value,
    Answer_Categories
  )

# Open the complete table
View(categorical_statements)

# Inspect response frequencies
for (question in unique(categorical_statements$Question_ID)) {
  
  cat("\nQuestion:", question, "\n")
  
  print(
    table(
      wvs_clean[[question]],
      useNA = "ifany"
    )
  )
}


# STEP 12: Create statement-level approval dataframe

# Create an empty dataframe with the same number of rows
statement_scores <- data.frame(
  row_id = seq_len(nrow(wvs_clean))
)

# Loop through the 100 statements
for (i in seq_len(nrow(statements_meta))) {
  
  statement <- statements_meta[i, ]
  
  question <- statement$Question_ID
  statement_id <- statement$S_id
  
  # Get original WVS responses
  x <- wvs_clean[[question]]
  
  # Numerical normalization when endpoints exist
  if (!is.na(statement$min_approval) &&
      !is.na(statement$max_approval) &&
      statement$min_approval != statement$max_approval) {
    
    score <- normalize_approval(
      x,
      statement$min_approval,
      statement$max_approval
    )
    
  } else if (
    is.na(statement$min_approval) &&
    !is.na(statement$max_approval)
  ) {
    
    # Categorical matching
    score <- ifelse(
      is.na(x),
      NA_real_,
      as.numeric(x == statement$max_approval)
    )
    
  } else {
    
    score <- rep(NA_real_, length(x))
  }
  
  # Add statement approval scores
  statement_scores[[statement_id]] <- score
}

# Inspect dataframe dimensions
dim(statement_scores)

# Preview the first rows and columns
head(statement_scores[, 1:8])

# Check score ranges
summary(statement_scores[, 2:8])


# STEP 13: Validate statement scores

# Remove row ID for validation
scores_only <- statement_scores %>%
  select(-row_id)

# Check whether all 100 statements exist
ncol(scores_only)

# Count scores outside the 0-1 range
invalid_scores <- sum(
  as.matrix(scores_only) < 0 |
    as.matrix(scores_only) > 1,
  na.rm = TRUE
)

print(invalid_scores)

# Summarize missing values for every statement
score_quality <- data.frame(
  S_id = names(scores_only),
  Missing_Percent = sapply(
    scores_only,
    function(x) round(mean(is.na(x)) * 100, 2)
  ),
  Unique_Scores = sapply(
    scores_only,
    function(x) length(unique(na.omit(x)))
  )
)

# Show statements with most missing data
score_quality %>%
  arrange(desc(Missing_Percent)) %>%
  head(10)


# STEP 14: Explore statement relationships

# Calculate pairwise correlations
cor_matrix <- cor(
  scores_only,
  use = "pairwise.complete.obs",
  method = "spearman"
)

# Create a statement-to-question lookup
question_lookup <- setNames(
  statements_meta$Question_ID,
  statements_meta$S_id
)

# Remove correlations between statements
# originating from the same WVS question
for (i in seq_len(ncol(cor_matrix))) {
  for (j in seq_len(ncol(cor_matrix))) {
    
    statement_i <- colnames(cor_matrix)[i]
    statement_j <- colnames(cor_matrix)[j]
    
    if (question_lookup[statement_i] ==
        question_lookup[statement_j]) {
      
      cor_matrix[i, j] <- NA_real_
    }
  }
}

# Convert correlation matrix to a table
cor_table <- as.data.frame(as.table(cor_matrix))

names(cor_table) <- c(
  "Statement_1",
  "Statement_2",
  "Correlation"
)

# Remove missing correlations and duplicate pairs
cor_table <- cor_table %>%
  filter(!is.na(Correlation)) %>%
  filter(as.character(Statement_1) <
           as.character(Statement_2)) %>%
  arrange(desc(abs(Correlation)))

# Display strongest relationships
head(cor_table, 10)


# STEP 15: Add statement descriptions

# Create statement lookup
statement_lookup <- statements_meta %>%
  select(
    S_id,
    Question_ID,
    Worldview_Statement
  )

# Add descriptions to both statements
cor_explained <- cor_table %>%
  left_join(
    statement_lookup,
    by = c("Statement_1" = "S_id")
  ) %>%
  rename(
    Question_1 = Question_ID,
    Description_1 = Worldview_Statement
  ) %>%
  left_join(
    statement_lookup,
    by = c("Statement_2" = "S_id")
  ) %>%
  rename(
    Question_2 = Question_ID,
    Description_2 = Worldview_Statement
  )

# Display the 10 strongest relationships
View(head(cor_explained, 10))



# STEP 16: Corrected sample-size calculation

# Create matrix of valid observations
valid_matrix <- !is.na(as.matrix(scores_only))

# Convert TRUE/FALSE to 1/0
valid_numeric <- valid_matrix * 1

# Calculate pairwise respondent counts
pair_counts <- crossprod(valid_numeric)

# Add statement names to rows and columns
rownames(pair_counts) <- colnames(scores_only)
colnames(pair_counts) <- colnames(scores_only)

# Add sample sizes to correlation results
cor_explained <- cor_explained %>%
  mutate(
    N_Respondents = mapply(
      function(s1, s2) {
        pair_counts[s1, s2]
      },
      as.character(Statement_1),
      as.character(Statement_2)
    )
  )

# Display the strongest relationships
cor_explained %>%
  select(
    Statement_1,
    Statement_2,
    Correlation,
    N_Respondents,
    Description_1,
    Description_2
  ) %>%
  head(10)


# STEP 17: First WVS-based compatibility function

predict_statement <- function(
    memory_ids,
    candidate_ids,
    relationship_matrix
) {
  
  # Ensure inputs are character vectors
  memory_ids <- as.character(memory_ids)
  candidate_ids <- as.character(candidate_ids)
  
  # Check statement IDs
  valid_ids <- colnames(relationship_matrix)
  
  memory_ids <- intersect(memory_ids, valid_ids)
  candidate_ids <- intersect(candidate_ids, valid_ids)
  
  if (length(candidate_ids) == 0) {
    stop("No valid candidate statements.")
  }
  
  # Calculate compatibility for each candidate
  scores <- sapply(candidate_ids, function(candidate) {
    
    if (length(memory_ids) == 0) {
      return(NA_real_)
    }
    
    relationships <- relationship_matrix[
      memory_ids,
      candidate,
      drop = TRUE
    ]
    
    if (all(is.na(relationships))) {
      return(NA_real_)
    }
    
    mean(relationships, na.rm = TRUE)
  })
  
  # Return candidate scores
  results <- data.frame(
    Candidate = candidate_ids,
    Compatibility = as.numeric(scores)
  )
  
  # Choose the highest-scoring candidate
  if (all(is.na(results$Compatibility))) {
    selected <- NA_character_
  } else {
    selected <- results$Candidate[
      which.max(replace(
        results$Compatibility,
        is.na(results$Compatibility),
        -Inf
      ))
    ]
  }
  
  return(list(
    predicted_selection = selected,
    candidate_scores = results
  ))
}

# Test with example statements
test_prediction <- predict_statement(
  memory_ids = c("Q182_2"),
  candidate_ids = c("Q186_2", "Q193_1", "Q183_1"),
  relationship_matrix = cor_matrix
)

print(test_prediction)



# STEP 18: Inspect all candidate predictions

# Display every candidate and its compatibility
print(test_prediction$candidate_scores)

# Sort candidates by compatibility
test_prediction$candidate_scores %>%
  arrange(desc(Compatibility))


# STEP 19: Test an actual simulation decision

# Select one simulation decision
decision_number <- 3

# Extract the agent's existing worldview
real_memory <- decisions$memory_ids[[decision_number]]

# Extract the candidate statements
real_candidates <- decisions$shown_candidates[[decision_number]]

# Extract the actual LLM selection
actual_selection <- decisions$selected_statement_id[
  decision_number
]

# Display the inputs
print(real_memory)
print(real_candidates)
print(actual_selection)

# Predict using WVS relationships
real_prediction <- predict_statement(
  memory_ids = real_memory,
  candidate_ids = real_candidates,
  relationship_matrix = cor_matrix
)

# Display predicted selection
print(real_prediction)


# =====================================================
# STEP 20: Evaluate WVS prediction on 100 LLM decisions
# =====================================================

library(dplyr)

# 1. Updated prediction function
predict_statement <- function(
    memory_ids,
    candidate_ids,
    relationship_matrix
) {
  
  valid_ids <- colnames(relationship_matrix)
  
  memory_ids <- intersect(
    as.character(memory_ids),
    valid_ids
  )
  
  candidate_ids <- intersect(
    as.character(candidate_ids),
    valid_ids
  )
  
  # Handle empty candidate lists
  if (length(candidate_ids) == 0) {
    return(list(
      predicted_selection = NA_character_,
      candidate_scores = data.frame(
        Candidate = character(),
        Compatibility = numeric()
      )
    ))
  }
  
  # Calculate compatibility scores
  scores <- sapply(candidate_ids, function(candidate) {
    
    if (length(memory_ids) == 0) {
      return(NA_real_)
    }
    
    relationships <- relationship_matrix[
      memory_ids,
      candidate,
      drop = TRUE
    ]
    
    if (all(is.na(relationships))) {
      return(NA_real_)
    }
    
    mean(relationships, na.rm = TRUE)
  })
  
  results <- data.frame(
    Candidate = candidate_ids,
    Compatibility = as.numeric(scores)
  )
  
  # Select highest-scoring candidate
  if (all(is.na(results$Compatibility))) {
    
    selected <- NA_character_
    
  } else {
    
    valid_scores <- replace(
      results$Compatibility,
      is.na(results$Compatibility),
      -Inf
    )
    
    selected <- results$Candidate[
      which.max(valid_scores)
    ]
  }
  
  return(list(
    predicted_selection = selected,
    candidate_scores = results
  ))
}


# 2. Select first 100 simulation decisions
n_test <- min(100, nrow(decisions))

evaluation <- data.frame(
  Decision = seq_len(n_test),
  Actual = rep(NA_character_, n_test),
  Predicted = rep(NA_character_, n_test)
)


# 3. Run predictions
for (i in seq_len(n_test)) {
  
  memory <- decisions$memory_ids[[i]]
  
  candidates <- decisions$shown_candidates[[i]]
  
  actual <- decisions$selected_statement_id[[i]]
  
  prediction <- predict_statement(
    memory_ids = memory,
    candidate_ids = candidates,
    relationship_matrix = cor_matrix
  )
  
  evaluation$Actual[i] <- if (length(actual) == 0) {
    NA_character_
  } else {
    as.character(actual[1])
  }
  
  evaluation$Predicted[i] <-
    prediction$predicted_selection
}


# 4. Display first 10 predictions
print(head(evaluation, 10))


# 5. Count actual selections
cat(
  "Actual selections:",
  sum(!is.na(evaluation$Actual)),
  "\n"
)


# 6. Count missing predictions
cat(
  "Missing predictions:",
  sum(is.na(evaluation$Predicted)),
  "\n"
)


# 7. Evaluate decisions with actual selections
evaluation_selected <- evaluation %>%
  filter(!is.na(Actual))


# 8. Calculate prediction accuracy
# Missing predictions count as incorrect
accuracy <- mean(
  !is.na(evaluation_selected$Predicted) &
    evaluation_selected$Actual ==
    evaluation_selected$Predicted
)

cat(
  "Prediction accuracy:",
  round(accuracy * 100, 2),
  "%\n"
)


# 9. Calculate prediction coverage
coverage <- mean(
  !is.na(evaluation_selected$Predicted)
)

cat(
  "Prediction coverage:",
  round(coverage * 100, 2),
  "%\n"
)


# 10. Count correct predictions
correct_predictions <- sum(
  !is.na(evaluation_selected$Predicted) &
    evaluation_selected$Actual ==
    evaluation_selected$Predicted
)

cat(
  "Correct predictions:",
  correct_predictions,
  "out of",
  nrow(evaluation_selected),
  "\n"
)


