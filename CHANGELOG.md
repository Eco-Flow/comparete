# comparete: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.2 - [2026-07-11]

### Fixed

- `COMPARE_TE` failed with `genome: unbound variable` under `set -u`. The genome filename is a Nextflow variable, not a bash one, so the gzip check now assigns it to a bash variable before parameter expansion.

## v1.1.1 - [2026-07-10]

### Added

- New `COMBINE_TE` module that merges the per-species Earl Grey vs HiTE comparisons into combined tables (`combined_te_totals.tsv`, `combined_te_by_class.tsv`) and a cross-species overview figure (`combined_te_comparison.pdf`).

## v1.1.0 - [2026-07-10]

### Added

- New `COMPARE_TE` module that combines Earl Grey and HiTE annotations per species when both `--earlgrey` and `--hite` are set. Parses Earl Grey's `filteredRepeats.gff` and HiTE's RepeatMasker `.out`, maps both to common high-level TE classes, and writes a totals table, a per-class table, and a comparison figure to `results/compare_te/`.
- `EARLGREY` and `HITE` now emit species-keyed tuples so their outputs can be joined.

## v1.0.6 - [2026-07-10]

### Added

- Set `OPENBLAS_NUM_THREADS=1` in the Earl Grey process to prevent `blas_thread_init: pthread_create failed` crashes on HPC nodes with tight ulimits, which the Earl Grey README notes can silently corrupt repeat percentages.

## v1.0.5 - [2026-07-10]

### Fixed

- Earl Grey no longer fails spuriously with exit status 141. `yes | earlGrey` gives `yes` a SIGPIPE once Earl Grey stops reading stdin, which `set -o pipefail` turned into a task failure even on success; the module now checks Earl Grey's own exit status.
- Earl Grey output now emits the `<species>_earl_results` directory that the process actually produces, instead of a non-existent `earlgreyresults.tsv` (which caused a missing-output error).

## v1.0.4 - [2026-07-10]

### Changed

- Earl Grey now runs from `tobybaril/earlgrey_dfam3.7` (augmented by Wave), which ships a fully-configured RepeatMasker with Dfam 3.7. The previous `earlgrey_bc` Wave container lacked the RepeatMasker libraries, causing RepeatModeler/RepeatClassifier to fail with `Missing RepeatMasker.lib.nsq`.
- `--famdb` is now an optional override of the bundled Dfam database rather than a requirement; running `--earlgrey` without it uses the container's built-in Dfam 3.7.

## v1.0.3 - [2026-07-10]

### Fixed

- Declare `config_profile_description`/`config_profile_contact`/`config_profile_url` as hidden schema params so institutional profiles no longer trigger nf-schema "invalid input" warnings.

## v1.0.2 - [2026-07-10]

### Added

- `--famdb` parameter to supply a Dfam famdb directory for Earl Grey / RepeatMasker. It is bind-mounted into the Earl Grey container at `/opt/conda/share/RepeatMasker/Libraries/famdb`, since the container does not ship the full Dfam partitions.
- Early error in `main.nf` when `--earlgrey` is used without `--famdb`.
- Earl Grey now runs from the `community.wave.seqera.io` Wave container.

## v1.0.1 - [2026-07-10]

### Added

- `ucl_myriad` profile (UCL Myriad, SGE) bundled in `conf/ucl_myriad.config`.
- `cambridge` profile (University of Cambridge CSD3, SLURM) in `conf/cambridge.config`.
- README section documenting the available HPC cluster profiles.

### Fixed

- Institutional configs now use the `env('...')` helper instead of `${HOME}`/`System.getenv(...)`, which the Nextflow 26 strict config parser rejects.

## v1.0.0 - [2026-07-10]

Initial release of comparete, a Nextflow pipeline for transposable element comparative analysis.

### Features

- Genome input via a CSV samplesheet, supporting NCBI accessions, local/S3 FASTA files, and FASTA+GFF pairs.
- Optional downstream analyses: OrthoFinder orthology inference, Earl Grey and HiTE transposable element annotation.
- Full nf-core-style `nextflow_schema.json` with grouped, documented parameters and runtime validation via `nf-schema`.
- CO2 footprint reporting (`nf-co2footprint`) and execution reporting (timeline, report, trace, DAG).
- Docker, Singularity, Apptainer, and AWS Batch profiles, plus bundled test profiles.
