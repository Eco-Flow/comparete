#!/usr/bin/env Rscript

# compare_te.R
# Combine the transposable-element annotations from Earl Grey and HiTE for a
# single species into comparison tables and a figure.
#
# Earl Grey  -> <earlgrey>/**/summaryFiles/*.filteredRepeats.gff (overlap-resolved GFF)
# HiTE       -> <hite>/*_HiTE.out  (standard RepeatMasker .out; absent if no TEs found)
#
# Both tools use RepeatMasker-style "class/family" labels, so a single mapping to
# high-level TE classes works for both. Coverage is the summed length of
# annotated features; percentages are relative to the supplied genome size.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(stringr)
})

# ---- argument parsing (base R, no optparse dependency) ----------------------
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NA) {
  hit <- which(args == flag)
  if (length(hit) == 1 && hit < length(args)) args[hit + 1] else default
}
species     <- get_arg("--species")
earl_dir    <- get_arg("--earlgrey")
hite_dir    <- get_arg("--hite")
genome_size <- suppressWarnings(as.numeric(get_arg("--genome_size")))
out_prefix  <- get_arg("--out_prefix", species)

if (is.na(species) || is.na(earl_dir) || is.na(hite_dir) || is.na(genome_size) || genome_size <= 0) {
  stop("Usage: compare_te.R --species S --earlgrey DIR --hite DIR --genome_size N [--out_prefix P]")
}

# ---- map a RepeatMasker class/family string to a high-level TE class ---------
high_level_class <- function(x) {
  x <- toupper(trimws(x))
  dplyr::case_when(
    x == "" | is.na(x)                                              ~ "Unclassified",
    str_detect(x, "^UNKNOWN|^UNSPECIFIED|^UNCLASSIFIED")            ~ "Unclassified",
    str_detect(x, "^DNA")                                           ~ "DNA",
    str_detect(x, "^RC|HELITRON|ROLLING")                           ~ "RC/Helitron",
    str_detect(x, "^LTR")                                           ~ "LTR",
    str_detect(x, "^LINE")                                          ~ "LINE",
    str_detect(x, "^SINE")                                          ~ "SINE",
    str_detect(x, "PENELOPE|^PLE")                                  ~ "Penelope",
    str_detect(x, "SATELLITE|SIMPLE|LOW_COMPLEXITY|TRNA|RRNA|SNRNA|SRNA|BUFFER") ~ "Other/Simple",
    TRUE                                                            ~ "Other/Simple"
  )
}

empty_annot <- function() tibble(class = character(), bp = numeric())

# ---- Earl Grey: parse filteredRepeats.gff -----------------------------------
parse_earlgrey <- function(dir) {
  gff <- list.files(dir, pattern = "\\.filteredRepeats\\.gff$",
                    recursive = TRUE, full.names = TRUE)
  if (length(gff) == 0) {
    message("No Earl Grey filteredRepeats.gff found under ", dir)
    return(empty_annot())
  }
  g <- read_tsv(gff[1], comment = "#", col_names = FALSE, show_col_types = FALSE,
                col_types = cols(.default = col_character()))
  if (nrow(g) == 0) return(empty_annot())
  tibble(
    class = high_level_class(g$X3),
    bp    = as.numeric(g$X5) - as.numeric(g$X4) + 1
  )
}

# ---- HiTE: parse RepeatMasker .out ------------------------------------------
parse_hite <- function(dir) {
  out <- list.files(dir, pattern = "_HiTE\\.out$", recursive = TRUE, full.names = TRUE)
  if (length(out) == 0) {
    message("No HiTE .out found under ", dir, " (HiTE likely found no TEs)")
    return(empty_annot())
  }
  lines <- readLines(out[1], warn = FALSE)
  # keep data rows: those starting with optional whitespace then a number (SW score)
  lines <- lines[str_detect(lines, "^\\s*\\d")]
  if (length(lines) == 0) return(empty_annot())
  f <- str_split(str_trim(lines), "\\s+")
  begin <- suppressWarnings(as.numeric(vapply(f, `[`, "", 6)))
  end   <- suppressWarnings(as.numeric(vapply(f, `[`, "", 7)))
  cf    <- vapply(f, `[`, "", 11)
  keep  <- !is.na(begin) & !is.na(end)
  tibble(
    class = high_level_class(cf[keep]),
    bp    = end[keep] - begin[keep] + 1
  )
}

summarise_tool <- function(annot, tool) {
  if (nrow(annot) == 0) {
    return(tibble(tool = tool, class = character(), bp = numeric(), copies = integer()))
  }
  annot %>%
    group_by(class) %>%
    summarise(bp = sum(bp), copies = n(), .groups = "drop") %>%
    mutate(tool = tool)
}

eg <- summarise_tool(parse_earlgrey(earl_dir), "EarlGrey")
ht <- summarise_tool(parse_hite(hite_dir),    "HiTE")

per_class <- bind_rows(eg, ht) %>%
  mutate(species = species,
         pct_genome = 100 * bp / genome_size)

# ---- totals table -----------------------------------------------------------
totals <- per_class %>%
  group_by(species, tool) %>%
  summarise(total_bp = sum(bp), total_copies = sum(copies), .groups = "drop") %>%
  complete(species, tool = c("EarlGrey", "HiTE"),
           fill = list(total_bp = 0, total_copies = 0)) %>%
  mutate(genome_size = genome_size,
         pct_genome  = 100 * total_bp / genome_size)

write_tsv(totals, paste0(out_prefix, "_te_comparison.tsv"))

# ---- by-class table (wide: one row per class, one column set per tool) -------
all_classes <- c("DNA", "RC/Helitron", "LTR", "LINE", "SINE", "Penelope",
                 "Other/Simple", "Unclassified")
by_class_wide <- per_class %>%
  select(class, tool, bp, copies, pct_genome) %>%
  complete(class = all_classes, tool = c("EarlGrey", "HiTE"),
           fill = list(bp = 0, copies = 0, pct_genome = 0)) %>%
  pivot_wider(names_from = tool,
              values_from = c(bp, copies, pct_genome),
              values_fill = 0) %>%
  mutate(species = species) %>%
  relocate(species) %>%
  arrange(match(class, all_classes))

write_tsv(by_class_wide, paste0(out_prefix, "_te_comparison_by_class.tsv"))

# ---- figure -----------------------------------------------------------------
tool_cols <- c(EarlGrey = "#4C72B0", HiTE = "#DD8452")

p_tot <- ggplot(totals, aes(tool, pct_genome, fill = tool)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.2f%%", pct_genome)), vjust = -0.4, size = 3.5) +
  scale_fill_manual(values = tool_cols, guide = "none") +
  labs(title = paste0(species, ": total TE content"),
       x = NULL, y = "% genome covered") +
  theme_minimal(base_size = 12)

by_class_long <- per_class %>%
  complete(class = all_classes, tool = c("EarlGrey", "HiTE"),
           fill = list(pct_genome = 0, bp = 0, copies = 0)) %>%
  mutate(class = factor(class, levels = all_classes))

p_cls <- ggplot(by_class_long, aes(class, pct_genome, fill = tool)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = tool_cols) +
  labs(title = paste0(species, ": TE content by class"),
       x = NULL, y = "% genome covered", fill = "Tool") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))

# Two-page PDF via the base device, avoiding extra layout-package dependencies.
pdf(paste0(out_prefix, "_te_comparison.pdf"), width = 8, height = 6)
print(p_tot)
print(p_cls)
invisible(dev.off())

message("compare_te.R: wrote comparison tables and figure for ", species)
