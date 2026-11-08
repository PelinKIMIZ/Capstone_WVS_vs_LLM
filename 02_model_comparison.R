
# STEP 2: Check the data available for model comparison

# Check which objects are currently loaded
print(ls())

# Check whether our LLM decisions dataset is available
print(exists("decisions"))

# Check whether our correlation matrix is available
print(exists("cor_matrix"))


# STEP 3: Load LLM decisions

library(arrow)

decisions <- read_parquet("decisions_from_json.parquet")

# Check the dataset
dim(decisions)
names(decisions)


# STEP 6: Load our saved correlation matrix

cor_matrix <- readRDS("correlation_matrix.rds")

# Check the dimensions
dim(cor_matrix)

# Check the first few statement IDs
head(colnames(cor_matrix))


# STEP 7: Prepare the same decisions for both models

# Select the first 100 decisions where the LLM
# actually selected a statement

selected_rows <- which(
  decisions$decision == "selected" &
    !is.na(decisions$selected_statement_id)
)

evaluation_data <- decisions[
  head(selected_rows, 100),
]

# Check the dataset
dim(evaluation_data)

# Check the actual selections
head(evaluation_data$selected_statement_id)


# STEP 8: Inspect the shared evaluation data

# Look at the first agent's existing worldview
print(evaluation_data$memory_ids[[1]])

# Look at the candidates shown to the agent
print(evaluation_data$shown_candidates[[1]])

# Look at the statement the LLM actually selected
print(evaluation_data$selected_statement_id[1])


# STEP 9: Check our correlation prediction function

exists("predict_statement")

# STEP 10: Correlation-based prediction function

predict_statement <- function(
    memory_ids,
    candidate_ids,
    relationship_matrix
) {
  
  memory_ids <- as.character(memory_ids)
  candidate_ids <- as.character(candidate_ids)
  
  valid_ids <- colnames(relationship_matrix)
  
  memory_ids <- intersect(memory_ids, valid_ids)
  candidate_ids <- intersect(candidate_ids, valid_ids)
  
  if (length(candidate_ids) == 0) {
    stop("No valid candidate statements.")
  }
  
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

# STEP 11: Confirm function is loaded
print(exists("predict_statement"))


# STEP 12: Test correlation prediction on the first decision

first_prediction <- predict_statement(
  memory_ids = evaluation_data$memory_ids[[1]],
  candidate_ids = evaluation_data$shown_candidates[[1]],
  relationship_matrix = cor_matrix
)

# Show our model's prediction
print(first_prediction$predicted_selection)

# Show what the LLM actually selected
print(evaluation_data$selected_statement_id[1])

# Check whether our prediction is correct
print(
  first_prediction$predicted_selection ==
    evaluation_data$selected_statement_id[1]
)


# STEP 13: Evaluate correlation model on 100 decisions

predictions <- sapply(
  seq_len(nrow(evaluation_data)),
  function(i) {
    
    result <- tryCatch(
      predict_statement(
        memory_ids = evaluation_data$memory_ids[[i]],
        candidate_ids = evaluation_data$shown_candidates[[i]],
        relationship_matrix = cor_matrix
      )$predicted_selection,
      error = function(e) NA_character_
    )
    
    result
  }
)

# Compare predictions with actual LLM selections
correct <- predictions == evaluation_data$selected_statement_id

# Calculate accuracy across all 100 decisions
accuracy <- mean(correct, na.rm = TRUE) * 100

# Count decisions without a prediction
missing_predictions <- sum(is.na(predictions))

# Display results
print(paste("Correlation accuracy:", round(accuracy, 2), "%"))
print(paste("Missing predictions:", missing_predictions))

# STEP 14: Save shared evaluation data and predictions

evaluation_data$correlation_prediction <- predictions

# Save the exact 100 decisions for both models
saveRDS(evaluation_data, "shared_evaluation_100.rds")

# Confirm the file was saved
file.exists("shared_evaluation_100.rds")

# STEP 15: Check for PCA files

list.files(
  pattern = "pca|PCA",
  ignore.case = TRUE
)

# STEP 16: Check PCA information in statement metadata

statements_meta <- arrow::read_parquet(
  "statements_meta.parquet"
)

# Check whether PCA coordinates are available
print(c("S_id", "Question_ID", "WVS_PC1", "worldview") %in%
        names(statements_meta))

# Check the first few PCA coordinates
print(head(statements_meta[
  , c("S_id", "WVS_PC1", "worldview")
]))

# STEP 17: Evaluate 1D PCA on the same 100 decisions

# Map each statement ID to its PCA coordinate
pc1_map <- setNames(
  statements_meta$WVS_PC1,
  statements_meta$S_id
)

predict_pca <- function(memory_ids, candidate_ids) {
  
  memory_values <- pc1_map[as.character(memory_ids)]
  memory_values <- memory_values[is.finite(memory_values)]
  
  if (length(memory_values) == 0) {
    return(NA_character_)
  }
  
  centroid <- mean(memory_values)
  
  candidates <- as.character(candidate_ids)
  candidate_values <- pc1_map[candidates]
  
  valid <- is.finite(candidate_values)
  
  if (!any(valid)) {
    return(NA_character_)
  }
  
  candidates <- candidates[valid]
  candidate_values <- candidate_values[valid]
  
  distances <- abs(candidate_values - centroid)
  
  candidates[which.min(distances)]
}

# Predict the same 100 LLM decisions
pca_predictions <- vapply(
  seq_len(nrow(evaluation_data)),
  function(i) {
    predict_pca(
      evaluation_data$memory_ids[[i]],
      evaluation_data$shown_candidates[[i]]
    )
  },
  character(1)
)

# Calculate accuracy across all 100 decisions
pca_correct <- !is.na(pca_predictions) &
  pca_predictions == evaluation_data$selected_statement_id

pca_accuracy <- mean(pca_correct) * 100

cat("PCA accuracy:", round(pca_accuracy, 2), "%\n")
cat("Missing PCA predictions:", sum(is.na(pca_predictions)), "\n")
cat("Correlation accuracy:", accuracy, "%\n")


# STEP 18: Test PCA on the same 100 decisions

pca_predictions <- vapply(
  seq_len(nrow(evaluation_data)),
  function(i) {
    predict_pca(
      evaluation_data$memory_ids[[i]],
      evaluation_data$shown_candidates[[i]]
    )
  },
  character(1)
)

# Check accuracy
pca_correct <- !is.na(pca_predictions) &
  pca_predictions == evaluation_data$selected_statement_id

pca_accuracy <- mean(pca_correct) * 100

# Display results
cat("PCA accuracy:", round(pca_accuracy, 2), "%\n")
cat("Missing predictions:", sum(is.na(pca_predictions)), "\n")
cat("Correlation accuracy:", accuracy, "%\n")


# STEP 19: Save model comparison results

evaluation_data$pca_prediction <- pca_predictions

comparison_results <- data.frame(
  Model = c("Correlation", "1D PCA"),
  Accuracy = c(accuracy, pca_accuracy),
  Missing_Predictions = c(
    sum(is.na(predictions)),
    sum(is.na(pca_predictions))
  )
)

print(comparison_results)

write.csv(
  comparison_results,
  "model_comparison_results.csv",
  row.names = FALSE
)

saveRDS(
  evaluation_data,
  "shared_evaluation_100.rds"
)

file.exists("model_comparison_results.csv")


# STEP 20: Understand the full LLM decision dataset

# Count each decision type
table(decisions$decision, useNA = "ifany")

# Count records with and without a selected statement
table(
  is.na(decisions$selected_statement_id)
)

# STEP 21: Verify the full LLM dataset

cat("Total decisions:", nrow(decisions), "\n")

cat(
  "Total across decision types:",
  sum(table(decisions$decision)),
  "\n"
)

cat(
  "Selected decisions:",
  sum(decisions$decision == "selected", na.rm = TRUE),
  "\n"
)

# STEP 22: Create a larger evaluation sample

# Select decisions where the LLM chose a statement
selected_data <- decisions[
  decisions$decision == "selected" &
    !is.na(decisions$selected_statement_id),
]

# Set seed so results can be reproduced
set.seed(123)

# Randomly select 1,000 decisions
evaluation_1000 <- selected_data[
  sample(seq_len(nrow(selected_data)), 1000),
]

# Check sample size
dim(evaluation_1000)

# Check actual selections
head(evaluation_1000$selected_statement_id)


# STEP 23: Test correlation model on 1,000 decisions

cor_predictions_1000 <- vapply(
  seq_len(nrow(evaluation_1000)),
  function(i) {
    tryCatch(
      predict_statement(
        memory_ids = evaluation_1000$memory_ids[[i]],
        candidate_ids = evaluation_1000$shown_candidates[[i]],
        relationship_matrix = cor_matrix
      )$predicted_selection,
      error = function(e) NA_character_
    )
  },
  character(1)
)

# Count correct predictions
cor_correct_1000 <- !is.na(cor_predictions_1000) &
  cor_predictions_1000 == evaluation_1000$selected_statement_id

# Calculate accuracy
cor_accuracy_1000 <- mean(cor_correct_1000) * 100

# Display results
cat("Correlation accuracy (1,000):",
    round(cor_accuracy_1000, 2), "%\n")

cat("Correct predictions:",
    sum(cor_correct_1000), "\n")

cat("Missing predictions:",
    sum(is.na(cor_predictions_1000)), "\n")


# STEP 24: Compare PCA with correlation on 1,000 decisions

pca_predictions_1000 <- vapply(
  seq_len(nrow(evaluation_1000)),
  function(i) {
    predict_pca(
      evaluation_1000$memory_ids[[i]],
      evaluation_1000$shown_candidates[[i]]
    )
  },
  character(1)
)

pca_correct_1000 <- !is.na(pca_predictions_1000) &
  pca_predictions_1000 == evaluation_1000$selected_statement_id

pca_accuracy_1000 <- mean(pca_correct_1000) * 100

cat("Correlation accuracy:", cor_accuracy_1000, "%\n")
cat("PCA accuracy:", pca_accuracy_1000, "%\n")
cat("Missing PCA predictions:",
    sum(is.na(pca_predictions_1000)), "\n")


# STEP 25: Save the 1,000-decision model comparison

evaluation_1000$correlation_prediction <- cor_predictions_1000
evaluation_1000$pca_prediction <- pca_predictions_1000

comparison_1000 <- data.frame(
  Model = c("Correlation", "1D PCA"),
  Accuracy = c(cor_accuracy_1000, pca_accuracy_1000),
  Correct = c(
    sum(cor_correct_1000),
    sum(pca_correct_1000)
  )
)

print(comparison_1000)

saveRDS(evaluation_1000, "evaluation_1000.rds")

write.csv(
  comparison_1000,
  "model_comparison_1000.csv",
  row.names = FALSE
)

cat("Files saved successfully!\n")


# STEP 26: Random selection baseline

set.seed(123)

random_predictions_1000 <- vapply(
  seq_len(nrow(evaluation_1000)),
  function(i) {
    
    candidates <- evaluation_1000$shown_candidates[[i]]
    
    candidates <- as.character(candidates)
    candidates <- candidates[!is.na(candidates)]
    
    if (length(candidates) == 0) {
      return(NA_character_)
    }
    
    sample(candidates, size = 1)
  },
  character(1)
)

  # STEP 27: Inspect none_selected decisions
  
  # Extract decisions where the LLM selected nothing
  none_data <- decisions[
    decisions$decision == "none_selected",
  ]
  
  # Count these decisions
  cat("None-selected decisions:", nrow(none_data), "\n")
  
  # Inspect the first five examples
  for (i in 1:5) {
    cat("\nExample", i, "\n")
    cat("Memory:", none_data$memory_ids[[i]], "\n")
    cat("Candidates:", none_data$shown_candidates[[i]], "\n")
    cat("Selected:", none_data$selected_statement_id[i], "\n")
  }
  
  # Count candidates shown in each decision
  candidate_counts <- lengths(none_data$shown_candidates)
  
  summary(candidate_counts)
  
  # STEP 28: Examine compatibility in none_selected decisions
  
  set.seed(123)
  
  # Randomly sample 1,000 none_selected decisions
  none_sample <- none_data[
    sample(seq_len(nrow(none_data)), 1000),
  ]
  
  # Calculate highest compatibility for each decision
  none_max_scores <- vapply(
    seq_len(nrow(none_sample)),
    function(i) {
      
      result <- tryCatch(
        predict_statement(
          memory_ids = none_sample$memory_ids[[i]],
          candidate_ids = none_sample$shown_candidates[[i]],
          relationship_matrix = cor_matrix
        ),
        error = function(e) NULL
      )
      
      if (is.null(result)) return(NA_real_)
      
      scores <- result$candidate_scores$Compatibility
      scores <- scores[is.finite(scores)]
      
      if (length(scores) == 0) return(NA_real_)
      
      max(scores)
    },
    numeric(1)
  )
  
  # Display distribution
  summary(none_max_scores)
  
  # Count missing compatibility scores
  sum(is.na(none_max_scores))
  
  

# Calculate random baseline accuracy
random_correct_1000 <- !is.na(random_predictions_1000) &
  random_predictions_1000 == evaluation_1000$selected_statement_id

random_accuracy_1000 <- mean(random_correct_1000) * 100

# Compare all three models
baseline_comparison <- data.frame(
  Model = c("Random", "Correlation", "1D PCA"),
  Accuracy = c(
    random_accuracy_1000,
    cor_accuracy_1000,
    pca_accuracy_1000
  )
)

print(baseline_comparison)


# STEP 29: Compare selected vs none_selected compatibility

# Calculate maximum compatibility for 1,000 selected decisions
selected_max_scores <- vapply(
  seq_len(nrow(evaluation_1000)),
  function(i) {
    
    result <- tryCatch(
      predict_statement(
        memory_ids = evaluation_1000$memory_ids[[i]],
        candidate_ids = evaluation_1000$shown_candidates[[i]],
        relationship_matrix = cor_matrix
      ),
      error = function(e) NULL
    )
    
    if (is.null(result)) return(NA_real_)
    
    scores <- result$candidate_scores$Compatibility
    scores <- scores[is.finite(scores)]
    
    if (length(scores) == 0) return(NA_real_)
    
    max(scores)
  },
  numeric(1)
)

# Compare distributions
comparison_scores <- data.frame(
  Decision = c(
    rep("selected", length(selected_max_scores)),
    rep("none_selected", length(none_max_scores))
  ),
  Max_Compatibility = c(
    selected_max_scores,
    none_max_scores
  )
)

aggregate(
  Max_Compatibility ~ Decision,
  data = comparison_scores,
  FUN = function(x) c(
    Mean = mean(x),
    Median = median(x),
    Min = min(x),
    Max = max(x)
  )
)

# Visualize the comparison
boxplot(
  Max_Compatibility ~ Decision,
  data = comparison_scores,
  main = "Compatibility by LLM Decision Type",
  ylab = "Maximum Compatibility Score",
  col = c("lightblue", "lightgreen")
)

# STEP 30: Test correlation thresholds

# Prepare scores and actual decision labels
scores <- c(selected_max_scores, none_max_scores)

actual <- c(
  rep("selected", length(selected_max_scores)),
  rep("none_selected", length(none_max_scores))
)

# Test different thresholds
thresholds <- seq(-0.10, 0.20, by = 0.01)

threshold_results <- data.frame(
  Threshold = thresholds,
  Accuracy = NA_real_,
  Balanced_Accuracy = NA_real_
)

for (i in seq_along(thresholds)) {

  predicted <- ifelse(
    scores >= thresholds[i],
    "selected",
    "none_selected"
  )

  threshold_results$Accuracy[i] <- mean(
    predicted == actual,
    na.rm = TRUE
  ) * 100

  sensitivity <- mean(
    predicted[actual == "selected"] == "selected",
    na.rm = TRUE
  )

  specificity <- mean(
    predicted[actual == "none_selected"] == "none_selected",
    na.rm = TRUE
  )

  threshold_results$Balanced_Accuracy[i] <-
    (sensitivity + specificity) / 2 * 100
}

# Show the best thresholds
threshold_results <- threshold_results[
  order(-threshold_results$Balanced_Accuracy),
]

head(threshold_results, 10)


# STEP 30: Test correlation thresholds

# Prepare scores and actual decision labels
scores <- c(selected_max_scores, none_max_scores)

actual <- c(
  rep("selected", length(selected_max_scores)),
  rep("none_selected", length(none_max_scores))
)

# Test different thresholds
thresholds <- seq(-0.10, 0.20, by = 0.01)

threshold_results <- data.frame(
  Threshold = thresholds,
  Accuracy = NA_real_,
  Balanced_Accuracy = NA_real_
)

for (i in seq_along(thresholds)) {
  
  predicted <- ifelse(
    scores >= thresholds[i],
    "selected",
    "none_selected"
  )
  
  threshold_results$Accuracy[i] <- mean(
    predicted == actual,
    na.rm = TRUE
  ) * 100
  
  sensitivity <- mean(
    predicted[actual == "selected"] == "selected",
    na.rm = TRUE
  )
  
  specificity <- mean(
    predicted[actual == "none_selected"] == "none_selected",
    na.rm = TRUE
  )
  
  threshold_results$Balanced_Accuracy[i] <-
    (sensitivity + specificity) / 2 * 100
}

# Show the best thresholds
threshold_results <- threshold_results[
  order(-threshold_results$Balanced_Accuracy),
]

head(threshold_results, 10)

# STEP 31: Threshold-based correlation model

predict_correlation_threshold <- function(
    memory_ids,
    candidate_ids,
    relationship_matrix,
    threshold = 0.03
) {
  
  result <- tryCatch(
    predict_statement(
      memory_ids,
      candidate_ids,
      relationship_matrix
    ),
    error = function(e) NULL
  )
  
  if (is.null(result)) return(NA_character_)
  
  scores <- result$candidate_scores$Compatibility
  scores <- scores[is.finite(scores)]
  
  if (length(scores) == 0) return(NA_character_)
  
  if (max(scores) < threshold) {
    return("none_selected")
  }
  
  return(result$predicted_selection)
}

# Test the function
test_none <- predict_correlation_threshold(
  none_sample$memory_ids[[1]],
  none_sample$shown_candidates[[1]],
  cor_matrix
)

cat("Prediction:", test_none, "\n")
cat("Actual: none_selected\n")


# STEP 32: Create helper function and extract independent test sample

# Helper function for unique decision keys
get_decision_keys <- function(df) {
  vapply(seq_len(nrow(df)), function(i) {
    paste(
      df$run_id_desc[i],
      df$N[i],
      df$M[i],
      df$agent_id[i],
      df$time_step[i],
      df$seed[i],
      df$source[i],
      sep = "|"
    )
  }, character(1))
}

# Identify tuning decision keys to prevent data leakage
used_keys <- unique(c(
  get_decision_keys(evaluation_1000),
  get_decision_keys(none_sample)
))

# Filter out tuning decisions from pools
selected_test_pool <- selected_data[
  !get_decision_keys(selected_data) %in% used_keys,
]

none_test_pool <- none_data[
  !get_decision_keys(none_data) %in% used_keys,
]

# Draw 1,000 NEW independent decisions for each category
set.seed(456)

selected_test <- selected_test_pool[
  sample(seq_len(nrow(selected_test_pool)), 1000),
]

none_test <- none_test_pool[
  sample(seq_len(nrow(none_test_pool)), 1000),
]

# Convert list columns to ordinary R lists
fix_columns <- function(df) {
  df <- as.data.frame(df)
  if ("memory_ids" %in% names(df)) {
    df$memory_ids <- lapply(df$memory_ids, as.character)
  }
  if ("shown_candidates" %in% names(df)) {
    df$shown_candidates <- lapply(df$shown_candidates, as.character)
  }
  df
}

selected_test_fixed <- fix_columns(selected_test)
none_test_fixed <- fix_columns(none_test)

# Combine into clean test dataset
test_data_clean <- dplyr::bind_rows(
  selected_test_fixed,
  none_test_fixed
)

cat("Final independent test decisions:", nrow(test_data_clean), "\n")
print(table(test_data_clean$decision))


# STEP 37: Evaluate threshold model on cleaned test data

threshold_predictions <- vapply(
  seq_len(nrow(test_data_clean)),
  function(i) {
    predict_correlation_threshold(
      memory_ids = test_data_clean$memory_ids[[i]],
      candidate_ids = test_data_clean$shown_candidates[[i]],
      relationship_matrix = cor_matrix,
      threshold = 0.03
    )
  },
  character(1)
)

# Define actual outcomes
actual_outcomes <- ifelse(
  test_data_clean$decision == "none_selected",
  "none_selected",
  test_data_clean$selected_statement_id
)

# Calculate accuracy, counting missing predictions as incorrect
correct_predictions <- !is.na(threshold_predictions) &
  threshold_predictions == actual_outcomes

threshold_accuracy <- mean(correct_predictions) * 100

# Display results
cat("Test decisions:", length(threshold_predictions), "\n")
cat("Correct predictions:", sum(correct_predictions), "\n")
cat("Threshold model accuracy:",
    round(threshold_accuracy, 2), "%\n")
cat("Missing predictions:",
    sum(is.na(threshold_predictions)), "\n")

# STEP 38: Evaluate accuracy by decision type

results_by_type <- data.frame(
  Actual_Type = test_data_clean$decision,
  Correct = correct_predictions
)

accuracy_by_type <- aggregate(
  Correct ~ Actual_Type,
  data = results_by_type,
  FUN = mean
)

accuracy_by_type$Accuracy_Percent <-
  round(accuracy_by_type$Correct * 100, 2)

print(accuracy_by_type)

# Show confusion matrix for decision types
predicted_type <- ifelse(
  threshold_predictions == "none_selected",
  "none_selected",
  "selected"
)

print(table(
  Actual = test_data_clean$decision,
  Predicted = predicted_type
))


# STEP 39: Exact accuracy by decision type

exact_accuracy_by_type <- aggregate(
  Correct ~ Actual_Type,
  data = results_by_type,
  FUN = function(x) round(mean(x) * 100, 2)
)

names(exact_accuracy_by_type)[2] <- "Exact_Accuracy_Percent"

print(exact_accuracy_by_type)

# Compare exact accuracy with decision-type accuracy
cat("Overall exact accuracy:",
    round(threshold_accuracy, 2), "%\n")



# STEP 40: Save threshold model evaluation

# Save predictions alongside actual decisions
test_data_clean$threshold_prediction <- threshold_predictions
test_data_clean$correct_prediction <- correct_predictions

# Save evaluation dataset
saveRDS(
  test_data_clean,
  "threshold_evaluation_996.rds"
)

# Save model performance summary
performance_summary <- data.frame(
  Metric = c(
    "Overall exact accuracy",
    "None-selected accuracy",
    "Selected exact accuracy",
    "Threshold"
  ),
  Value = c(55.62, 63.58, 47.70, 0.03)
)

write.csv(
  performance_summary,
  "threshold_performance_summary.csv",
  row.names = FALSE
)

cat("Evaluation results saved successfully!\n")

# STEP 41: Save final model comparison summary

model_summary <- data.frame(
  Model = c(
    "Random baseline",
    "Correlation",
    "1D PCA",
    "Correlation with threshold"
  ),
  Accuracy_Percent = c(
    random_accuracy_1000,
    cor_accuracy_1000,
    pca_accuracy_1000,
    round(threshold_accuracy, 2)
  ),
  Test_Decisions = c(1000, 1000, 1000, nrow(test_data_clean)),
  Evaluation_Type = c(
    "Selected only",
    "Selected only",
    "Selected only",
    "Selected and none"
  )
)

print(model_summary)

write.csv(
  model_summary,
  "final_model_comparison.csv",
  row.names = FALSE
)

cat("Final model comparison saved successfully!\n")
