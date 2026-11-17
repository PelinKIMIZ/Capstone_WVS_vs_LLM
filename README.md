# Capstone: WVS vs LLM Validation

Collaborative repository for the MSc Data Science for Society and Business Capstone project evaluating LLM agent worldview decisions in the **LLM Filter Bubble Model** (Lorenz & Gunes) against empirical **World Values Survey (WVS) Wave 7** human survey data.

---

## 1. Important Note on Datasets (Do Not Push Raw Data!)
Raw data files are large and strictly excluded via `.gitignore`.  
Please create a local `data/` folder on your machine and place the following three files inside it before running the scripts:
- `statements_meta.parquet` (100 simulation statements mapped to 70 WVS Wave 7 questions)
- `decisions_from_json.parquet` (1,440,000 agent decision turns across 108 simulation runs)
- `WVS_Wave_7.csv` ($N = 97,220$ survey respondents)

---

## 2. Repository Structure
```text
Capstone_WVS_vs_LLM/
│
├── .gitignore                        # Ignores large data files (*.parquet, *.csv) and local caches
├── README.md                         # Project documentation and setup guide
│
├── 01_data_exploration.R             # WVS [0, 1] normalization, 100x100 Spearman matrix & initial validation
├── 02_model_comparison.R             # Run-independent split (86 tuning / 22 test runs), threshold tuning & evaluation
│
├── correlation_matrix.rds            # Exported 100x100 empirical WVS Spearman correlation matrix
├── evaluation_run_split.rds          # Serialized out-of-sample run-independent evaluation results
├── final_threshold_evaluation.rds    # Saved out-of-sample evaluation metrics (threshold = 0.04)
├── final_model_comparison.png        # Accuracy comparison: WVS Correlation (66.6%) vs. 1D PCA (53.8%)
└── final_confusion_matrix.png        # Out-of-sample confusion matrix (n = 1,000, threshold = 0.04)
```

---

## 3. Summary of Key Results (Run-Independent Out-of-Sample Evaluation)
All models are evaluated using strict simulation-run separation (**86 tuning runs** vs. **22 strictly unseen testing runs**, zero shared runs):

| Decision Rule | Evaluation Scope | Test Sample ($n$) | Exact Accuracy |
| :--- | :--- | :---: | :---: |
| **Random Baseline** | `selected` only | 1,000 | **35.7%** |
| **1D PCA Rule** | `selected` only (unseen runs) | 500 | **53.8%** (269 / 500) |
| **Pairwise Correlation Rule** | `selected` only (unseen runs) | 500 | **66.6%** (333 / 500) |
| **Threshold Correlation ($\tau = 0.04$)** | `selected` & `none_selected` (unseen runs) | 1,000 | **55.0%** exact / **67.3%** decision-type |

---

## 4. Team Members
- Limpo Shawa
- Morné Jeffrey Magerman
- Pelin Kimiz
- Rebeccah Chepkemoi Kapsekei
