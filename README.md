# Capstone: WVS vs LLM Validation

Collaborative repository for the MSc Data Science for Society and Business Capstone project evaluating LLM agent worldview decisions in the **LLM Filter Bubble Model** (Lorenz & Gunes) against empirical **World Values Survey (WVS) Wave 7** human survey data.

## 1. Important Note on Datasets (Do Not Push Raw Data!)
Raw data files are large and strictly excluded via `.gitignore`.  
Create a local `data/` folder on your machine and place the following three files inside it before running the scripts:
- `statements_meta.parquet` (100 simulation statements mapped to 70 WVS Wave 7 questions)
- `decisions_from_json.parquet` (1,440,000 agent decision turns across 108 simulation runs)
- `WVS_Wave_7.csv` ($N = 97,220$ survey respondents)

## 2. Repository Structure
```text
Capstone_WVS_vs_LLM/
│
├── .gitignore                        # Ignores large data files (*.parquet, *.csv) and caches
├── README.md                         # Project documentation and setup guide
│
├── 01_data_exploration.R             # WVS [0, 1] normalization, 100x100 Spearman matrix & initial validation
├── 02_model_comparison.R             # Run-independent split (86 tuning / 22 test runs), threshold tuning & evaluation
│
├── correlation_matrix.rds            # Exported 100x100 empirical WVS Spearman correlation matrix
├── final_threshold_evaluation.rds    # Saved out-of-sample evaluation metrics (threshold = 0.04)
├── final_model_comparison.png        # Accuracy comparison: WVS Correlation (66.6%) vs. 1D PCA (53.8%)
└── final_confusion_matrix.png        # Out-of-sample confusion matrix (n = 1,000, threshold = 0.04)
