# CompareTE
A pipeline to compare TE content across genomes using various platforms.

**Important!,**
If you use EarlGrey in your work, please use their reference.
If you use HiTE in your work, please use their reference.

# Input

Input should be a csv file (ending in `.csv`). 

It should contain either:

```
name,refseqID
name,/path/to/genome.fa 
name,/path/to/genome.fa,/path/to/annotation.gff
```

The genome must end with:

`'.fa', '.fasta', '.fna', '.fa.gz', '.fasta.gz', '.fna.gz'`

The annotation must end with:

`'.gff', '.gff3', '.gff.gz', '.gff3.gz'`

See examples in `conf/test` (various example in config files)

# Running the pipeline

To run the pipeline you need to make a csv input file as described above with either Refseq IDs (these always begin GCF_...), or with genomes, or genomes and annotation files.

To run with all the different TE programs on a input csv file called `input.csv`:

`nextflow run main.nf --orthofinder --hite --earlgrey --input input.csv`

**Though,** the above would require you to manually download all the prerequisites and programs, so the easier way is to set a container engine to pull all the programs you need:

`nextflow run main.nf --orthofinder --hite --earlgrey --input input.csv -profile docker/singularity/apptainer`

## Useful additional flags:

`-resume` : This allows the pipeline to resume from the last failed process (using the nextflow cache-ing mechanism)
`-bg`     : This allows nextflow to run in the background, so you can continue to use your terminal.

# Current test commands:
`nextflow run main.nf -profile docker,test_drosophila -resume`

To run test data with HITE:

`nextflow run main.nf -profile docker,test_drosophila -resume --hite --clean false`

To run test data with EARL GREY:

`nextflow run main.nf -profile docker,test_drosophila -resume --earlgrey --clean false`

To run orthofinder on your input species:

`nextflow run main.nf -profile docker,test_drosophila -resume --orthofinder`

# Test a docker container:
`docker run -it --volume $PWD:$PWD <container> bash`


# References

**EarlGrey:**

Baril, T., Galbraith, J.G., and Hayward, A., Earl Grey: A Fully Automated User-Friendly Transposable Element Annotation and Analysis Pipeline, Molecular Biology and Evolution, Volume 41, Issue 4, April 2024, msae068 doi:10.1093/molbev/msae068

Baril, Tobias., Galbraith, James., and Hayward, Alexander. (2023) Earl Grey. Zenodo doi:10.5281/zenodo.5654615

**HiTE:**

Hu, K., Ni, P., Xu, M. et al. HiTE: a fast and accurate dynamic boundary adjustment approach for full-length transposable element detection and annotation. Nat Commun 15, 5573 (2024).