# CompareTE
A pipeline to compare TE content across genomes using various platforms.


# Input

Input should be a csv file (ending in `.csv`). 

It should contain either:

```
name,refseqID
name,/full/path/to/genome.fa 
name,/full/path/to/genome.fa,/full/path/to/annotation.gff
```

**!! Do not use relative paths !!**

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
`nextflow run main.nf -profile docker,test_bacteria -resume`

To run with HITE:

`nextflow run main.nf -profile docker,test_bacteria -resume --hite`

To run with EARL GREY:

`nextflow run main.nf -profile docker,test_bacteria -resume --earlgrey`

To run orthofinder on your input species:

`nextflow run main.nf -profile docker,test_bacteria -resume --orthofinder`

# Test a docker container:
`docker run -it --volume $PWD:$PWD <container> bash`
