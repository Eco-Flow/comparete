# comparete: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
