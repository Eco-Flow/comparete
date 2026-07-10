#!/usr/bin/env Rscript

# combine_te.R
# Merge the per-species Earl Grey vs HiTE comparison tables (produced by
# compare_te.R) into a single combined table and overview figure across all
# species. Reads every staged *_te_comparison.tsv and *_te_comparison_by_class.tsv
# in the working directory (each already carries a `species` column).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

totals_files  <- list.files(pattern = "_te_comparison\\.tsv$")
byclass_files <- list.files(pattern = "_te_comparison_by_class\\.tsv$")

if (length(totals_files) == 0) stop("combine_te.R: no per-species totals tables found")

totals <- bind_rows(lapply(totals_files, read_tsv, show_col_types = FALSE)) %>%
  arrange(species, tool)
write_tsv(totals, "combined_te_totals.tsv")

byclass <- bind_rows(lapply(byclass_files, read_tsv, show_col_types = FALSE))
write_tsv(byclass, "combined_te_by_class.tsv")

# ---- figures ----------------------------------------------------------------
tool_cols <- c(EarlGrey = "#4C72B0", HiTE = "#DD8452")

# Overview: total TE content per species, grouped by tool
p_tot <- ggplot(totals, aes(species, pct_genome, fill = tool)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = tool_cols) +
  labs(title = "Total TE content: Earl Grey vs HiTE",
       x = NULL, y = "% genome covered", fill = "Tool") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))

# Per-class overview, faceted by species (pivot the wide pct_genome_* columns)
all_classes <- c("DNA", "RC/Helitron", "LTR", "LINE", "SINE", "Penelope",
                 "Other/Simple", "Unclassified")
byclass_long <- byclass %>%
  select(species, class, starts_with("pct_genome_")) %>%
  pivot_longer(cols = starts_with("pct_genome_"),
               names_to = "tool", names_prefix = "pct_genome_",
               values_to = "pct_genome") %>%
  mutate(class = factor(class, levels = all_classes))

p_cls <- ggplot(byclass_long, aes(class, pct_genome, fill = tool)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = tool_cols) +
  facet_wrap(~ species, scales = "free_y") +
  labs(title = "TE content by class: Earl Grey vs HiTE",
       x = NULL, y = "% genome covered", fill = "Tool") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

pdf("combined_te_comparison.pdf", width = 10, height = 7)
print(p_tot)
print(p_cls)
invisible(dev.off())

message("combine_te.R: wrote combined tables and overview figure for ",
        length(unique(totals$species)), " species")
