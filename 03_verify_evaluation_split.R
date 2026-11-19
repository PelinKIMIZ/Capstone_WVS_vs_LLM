# Recreate the original evaluation split
# 86 tuning runs and 22 testing runs
# Original random sampling procedure was not recovered.

# Load the preserved run assignments
run_split <- dget("evaluation_run_split_assignments.R")

# Verify the assignments
stopifnot(
  length(run_split$tuning_run_ids) == 86,
  length(run_split$testing_run_ids) == 22,
  length(intersect(
    run_split$tuning_run_ids,
    run_split$testing_run_ids
  )) == 0
)

# Recreate the RDS file used by the model
saveRDS(run_split, "evaluation_run_split.rds")

cat("Evaluation split recreated successfully!\n")