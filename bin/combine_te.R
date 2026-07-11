#!/usr/bin/env Rscript

# combine_te.R
# Merge the normalised per-species, per-method TE tables (from parse_te.R) into
# combined tables and an overview figure. Works for any subset of methods
# (Earl Grey, HiTE, RepeatMasker) that were run. Reads every staged
# *_te.tsv in the working directory.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

files <- list.files(pattern = "_te\\.tsv$")
if (length(files) == 0) stop("combine_te.R: no per-method TE tables found")

dat <- bind_rows(lapply(files, read_tsv, show_col_types = FALSE))

all_classes <- c("DNA", "RC/Helitron", "LTR", "LINE", "SINE", "Penelope",
                 "Other/Simple", "Unclassified")
method_labels <- c(earlgrey = "Earl Grey", hite = "HiTE", repeatmasker = "RepeatMasker")
dat <- dat %>%
  mutate(method_label = dplyr::recode(method, !!!method_labels),
         class = factor(class, levels = all_classes))

# ---- combined tables --------------------------------------------------------
by_class <- dat %>%
  select(species, method, method_label, class, bp, copies, pct_genome) %>%
  arrange(species, method, class)
write_tsv(by_class, "combined_te_by_class.tsv")

totals <- dat %>%
  group_by(species, method, method_label, genome_size) %>%
  summarise(total_bp = sum(bp), total_copies = sum(copies), .groups = "drop") %>%
  mutate(pct_genome = 100 * total_bp / genome_size) %>%
  arrange(species, method)
write_tsv(totals, "combined_te_totals.tsv")

# ---- figures ----------------------------------------------------------------
# Distinct, colour-blind-friendly palette keyed by method label.
method_cols <- c("Earl Grey" = "#4C72B0", "HiTE" = "#DD8452", "RepeatMasker" = "#55A868")

p_tot <- ggplot(totals, aes(species, pct_genome, fill = method_label)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = method_cols, name = "Method") +
  labs(title = "Total TE content by method",
       x = NULL, y = "% genome covered") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))

p_cls <- ggplot(dat, aes(class, pct_genome, fill = method_label)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = method_cols, name = "Method") +
  facet_wrap(~ species, scales = "free_y") +
  labs(title = "TE content by class and method",
       x = NULL, y = "% genome covered") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

pdf("combined_te_comparison.pdf", width = 10, height = 7)
print(p_tot)
print(p_cls)
invisible(dev.off())

message("combine_te.R: combined ", length(unique(dat$method)), " method(s) across ",
        length(unique(dat$species)), " species")
