# Capstone: WVS vs LLM Validation

Collaborative repository for the MSc Data Science for Society and Business Capstone project evaluating LLM agent worldview decisions in the **LLM Filter Bubble Model** (Lorenz & Gunes) against empirical **World Values Survey (WVS) Wave 7** human survey data.

---

## 1. Datasets and Repository Files
Large raw data files (`WVS_Wave_7.csv` and `decisions_from_json.parquet`) are excluded from version control via `.gitignore`. Keep large source datasets locally when running the pipeline:
- `WVS_Wave_7.csv` ($N = 97,220$ survey respondents)
- `decisions_from_json.parquet` (approximately 1.44 million decision records across 108 simulation runs)
- `statements_meta.parquet` (100 simulation statements mapped to 70 WVS Wave 7 questions)

---

## 2. Repository Structure
```text
Capstone_WVS_vs_LLM/
│
├── .gitignore                          # Excludes large data files and local caches
├── README.md                           # Project documentation and overview
│
├── 01_data_exploration.R               # WVS [0, 1] normalization, 100x100 Spearman matrix & initial exploration
├── 02_model_comparison.R               # Run-separated evaluation, threshold tuning & model comparisons
├── 03_verify_evaluation_split.R        # Verifies 86 tuning / 22 testing runs and recreates evaluation_run_split.rds
├── evaluation_run_split_assignments.R  # Preserved run ID lists (86 tuning runs, 22 testing runs)
│
├── evaluation_run_split.rds            # Recreated run-split assignments (86 tuning / 22 testing runs)
├── correlation_matrix.rds              # Exported 100x100 empirical WVS Spearman correlation matrix
├── fair_model_predictions.rds          # Saved model prediction artifacts
├── final_threshold_evaluation.rds      # Earlier 973-case evaluation at threshold 0.03 (distinct from final 1,000-case test)
├── independent_testing_sample.rds      # Independent balanced 1,000-decision test sample (500 selected, 500 none_selected)
│
├── fair_model_comparison.csv           # Model comparison summary table
├── independent_test_results.csv        # Summary of independent test evaluation results
│
├── final_model_comparison.png          # Accuracy comparison: WVS Correlation (66.6%) vs. 1D PCA (53.8%) on n = 500
└── final_confusion_matrix.png          # Decision-type confusion matrix (n = 1,000, threshold = 0.04)
```

---

## 3. Summary of Key Results
Evaluations use run-level separation (**86 tuning runs** vs. **22 held-out testing runs**, with no overlapping runs). Note that evaluation cohorts differ across comparisons and should not be treated as a single matched sample:

| Decision Rule | Evaluation Scope | Sample ($n$) | Exact Accuracy | Notes |
| :--- | :--- | :---: | :---: | :--- |
| **Random Baseline** | `selected` only | 1,000 | **35.7%** | Separate sample; descriptive reference only |
| **1D PCA Rule** | `selected` only (unseen runs) | 500 | **53.8%** (269 / 500) | Matched head-to-head comparison with Pairwise Correlation |
| **Pairwise Correlation Rule** | `selected` only (unseen runs) | 500 | **66.6%** (333 / 500) | Matched head-to-head comparison with 1D PCA (+12.8 pp) |
| **Threshold Correlation ($\tau = 0.04$)** | `selected` & `none_selected` (unseen runs) | 1,000 | **55.0%** (550 / 1,000) | 68.4% abstention acc., 41.6% selected exact acc., 67.3% decision-type acc. |

---

## 4. Team Members
- Limpo Shawa
- Morné Jeffrey Magerman
- Pelin Kimiz
- Rebeccah Chepkemoi Kapsekei
