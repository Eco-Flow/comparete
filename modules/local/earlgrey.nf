process EARLGREY {
    label 'process_medium'
    label 'process_long'
    tag "$species"
    //container = 'quay.io/biocontainers/earlgrey:4.2.4--h4ac6f70_0'
    container = 'tobybaril/earlgrey_dfam3.7:latest'
    //containerOptions '-v `pwd`:/data/'
    //stageInMode = 'copy'

    input:
    tuple val(species), path(genome)

    output:
    path("earlgreyresults.tsv"), emit: te_results
    //path("versions.yml"), emit: versions

    script:
    """
    #conda create -n earlgrey -c conda-forge -c bioconda earlgrey=4.2.4

    ls

    if [ -f *.gz ]; then
       gunzip $genome && mv genome.fna myunzip.fa
       awk '/^>/ { print (NR==1 ? "" : RS) \$0; next } { printf "%s", \$0 } END { printf RS }' myunzip.fa > genome_line_removal.fasta
       #rm myunzip.fa
    else
       awk '/^>/ { print (NR==1 ? "" : RS) \$0; next } { printf "%s", \$0 } END { printf RS }' $genome > genome_line_removal.fasta
       #rm $genome
    fi



    PATH=$PATH:/opt/conda/envs/myenv/bin/

    # Capture the current working directory
    mydir=`pwd`

    # Create the output directory
    mkdir -p \${mydir}/${species}_earl_results

    yes | earlGrey -g genome_line_removal.fasta -s $species -o \${mydir}/${species}_earl_results -t 4

    #cat <<-END_VERSIONS > versions.yml
    #"${task.process}":
    #    //Python version: \$(python --version | cut -f 2 -d " ")
    #    //Orthofinder version: \$(orthofinder | grep version | cut -f 3 -d " ")
    #END_VERSIONS
    """
}
