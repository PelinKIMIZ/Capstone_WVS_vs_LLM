# ==============================================================================
# 03_visualize_results.R
# Purpose: Visualization of Model Comparison and Threshold Performance
# ==============================================================================

library(ggplot2)
library(dplyr)

# ------------------------------------------------------------------------------
# 1. Model Performance Bar Chart
# ------------------------------------------------------------------------------

# Load pre-calculated model comparison summary
model_summary <- read.csv("final_model_comparison.csv")

# Set factor levels for consistent plot ordering
model_summary$Model <- factor(
  model_summary$Model,
  levels = c(
    "Random baseline",
    "Correlation",
    "1D PCA",
    "Correlation with threshold"
  )
)

# Create bar chart
p1 <- ggplot(model_summary, aes(x = Model, y = Accuracy_Percent, fill = Model)) +
  geom_col(width = 0.55, color = "black", alpha = 0.85) +
  geom_hline(
    yintercept = 35.7,
    linetype = "dashed",
    color = "gray40",
    linewidth = 0.8
  ) +
  geom_text(
    aes(label = paste0(Accuracy_Percent, "%")),
    vjust = -0.5,
    fontface = "bold",
    size = 4.5
  ) +
  scale_fill_manual(
    values = c("#888888", "#D95F02", "#7570B3", "#1B9E77")
  ) +
  scale_y_continuous(limits = c(0, 80), expand = c(0, 0)) +
  labs(
    title = "Model Performance Comparison Across Evaluation Tasks",
    y = "Accuracy (%)",
    x = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    axis.text.x = element_text(face = "bold", size = 10),
    axis.title.y = element_text(face = "bold")
  )

# Save high-resolution bar chart
ggsave(
  "model_comparison_plot.png",
  plot = p1,
  width = 8,
  height = 5,
  dpi = 300
)

# ------------------------------------------------------------------------------
# 2. Confusion Matrix Heatmap (Threshold Correlation Model)
# ------------------------------------------------------------------------------

# Construct confusion matrix dataset
confusion_data <- data.frame(
  Actual = factor(
    c("None", "None", "Selected", "Selected"),
    levels = c("Selected", "None")
  ),
  Predicted = factor(
    c("None", "Selected", "None", "Selected"),
    levels = c("None", "Selected")
  ),
  Count = c(637, 363, 296, 704)
)

# Create heatmap visualization
p2 <- ggplot(confusion_data, aes(x = Predicted, y = Actual, fill = Count)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = Count), fontface = "bold", color = "white", size = 6) +
  scale_fill_gradient(low = "#6BAED6", high = "#08519C") +
  labs(
    title = "Confusion Matrix: Threshold Correlation Model",
    subtitle = "Detection of 'Selected' vs 'None Selected' Decisions",
    x = "Predicted Decision",
    y = "Actual Decision"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, size = 11),
    axis.title = element_text(face = "bold")
  )

# Save high-resolution heatmap
ggsave(
  "confusion_matrix_plot.png",
  plot = p2,
  width = 6,
  height = 5,
  dpi = 300
)

cat("Visualizations saved successfully as PNG files!\n")