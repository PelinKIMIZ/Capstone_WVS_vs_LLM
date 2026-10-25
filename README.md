# Capstone: WVS vs LLM Validation

Collaborative repository for the Capstone project evaluating LLM agent simulation decisions against World Values Survey (WVS) Wave 7 human survey data.

---

## 1. Important Note on Datasets (Do Not Push Data!)

Raw data files are large and strictly excluded via `.gitignore`. 

Please create a local `data/` folder on your machine and place the following three files inside it:
- `statements_meta.parquet` (100 statements mapped to 70 WVS questions)
- `decisions_from_json.parquet` (1.44M decision events from 108 simulation runs)
- `WVS_Wave_7.csv` (N=97,220 survey respondents)

---

## 2. Repository Structure

```text
Capstone_WVS_vs_LLM/
│
├── .gitignore          # Ignores data files (*.parquet, *.csv) and local caches
├── README.md           # Setup and project structure guide
│
├── data/               # Local folder for datasets (NOT tracked by Git)
│
├── scripts/            # Shared R and Python scripts
│   ├── read_data.py                    # Python data check (pandas, pyarrow)
│   └── work_read_data_and_first_look.r # R data check (arrow, dplyr, readr)
│
├── docs/               # Meeting notes, proposal drafts, papers
└── results/            # Generated figures, tables, and exported metrics
