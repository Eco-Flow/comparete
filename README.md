# comparete
A pipeline to compare TE content across genomes

# Current test command:
`nextflow run main.nf -profile docker,test_bacteria -resume`

# To run with HITE:
`nextflow run main.nf -profile docker,test_bacteria -resume --hite`

# Test a docker container:

`docker run -it --volume $PWD:$PWD <container> bash`