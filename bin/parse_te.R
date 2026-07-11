#!/usr/bin/env Rscript

# parse_te.R
# Parse one TE-annotation method's output for one species into a normalised
# long table: species, method, class, bp, copies, pct_genome, genome_size.
#
#   --method earlgrey     -> <input>/**/summaryFiles/*.filteredRepeats.gff
#   --method hite         -> <input>/*_HiTE.out          (RepeatMasker .out)
#   --method repeatmasker -> <input>                     (a RepeatMasker .out file, or a dir containing *.out)
#
# All three ultimately use RepeatMasker-style class/family labels, so a single
# high-level class mapping applies. Coverage is the summed length of annotated
# features; percentages are relative to the supplied genome size.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NA) {
  hit <- which(args == flag)
  if (length(hit) == 1 && hit < length(args)) args[hit + 1] else default
}
species     <- get_arg("--species")
method      <- get_arg("--method")
input       <- get_arg("--input")
genome_size <- suppressWarnings(as.numeric(get_arg("--genome_size")))
out         <- get_arg("--out", paste0(species, "_", method, "_te.tsv"))

if (is.na(species) || is.na(method) || is.na(input) || is.na(genome_size) || genome_size <= 0) {
  stop("Usage: parse_te.R --method M --input PATH --species S --genome_size N [--out FILE]")
}

all_classes <- c("DNA", "RC/Helitron", "LTR", "LINE", "SINE", "Penelope",
                 "Other/Simple", "Unclassified")

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

parse_gff <- function(path) {
  g <- read_tsv(path, comment = "#", col_names = FALSE, show_col_types = FALSE,
                col_types = cols(.default = col_character()))
  if (nrow(g) == 0) return(empty_annot())
  tibble(class = high_level_class(g$X3),
         bp    = as.numeric(g$X5) - as.numeric(g$X4) + 1)
}

parse_rmout <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[str_detect(lines, "^\\s*\\d")]        # data rows start with SW score
  if (length(lines) == 0) return(empty_annot())
  f     <- str_split(str_trim(lines), "\\s+")
  begin <- suppressWarnings(as.numeric(vapply(f, `[`, "", 6)))
  end   <- suppressWarnings(as.numeric(vapply(f, `[`, "", 7)))
  cf    <- vapply(f, `[`, "", 11)
  keep  <- !is.na(begin) & !is.na(end)
  tibble(class = high_level_class(cf[keep]), bp = end[keep] - begin[keep] + 1)
}

find_one <- function(dir, pattern) {
  hits <- list.files(dir, pattern = pattern, recursive = TRUE, full.names = TRUE)
  if (length(hits) == 0) NA_character_ else hits[1]
}

annot <- if (method == "earlgrey") {
  f <- find_one(input, "\\.filteredRepeats\\.gff$")
  if (is.na(f)) empty_annot() else parse_gff(f)
} else if (method == "hite") {
  f <- find_one(input, "_HiTE\\.out$")
  if (is.na(f)) empty_annot() else parse_rmout(f)
} else if (method == "repeatmasker") {
  f <- if (dir.exists(input)) find_one(input, "\\.out$") else input
  if (is.na(f) || !file.exists(f)) empty_annot() else parse_rmout(f)
} else {
  stop("Unknown --method: ", method)
}

if (nrow(annot) == 0) {
  message("parse_te.R: no annotations parsed for ", species, " / ", method)
}

per_class <- annot %>%
  group_by(class) %>%
  summarise(bp = sum(bp), copies = n(), .groups = "drop") %>%
  complete(class = all_classes, fill = list(bp = 0, copies = 0)) %>%
  mutate(species     = species,
         method      = method,
         genome_size = genome_size,
         pct_genome  = 100 * bp / genome_size) %>%
  select(species, method, class, bp, copies, pct_genome, genome_size) %>%
  arrange(match(class, all_classes))

write_tsv(per_class, out)
message("parse_te.R: wrote ", out)
