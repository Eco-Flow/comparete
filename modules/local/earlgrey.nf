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
    path("versions.yml"), emit: versions

    script:
    """
    # Unzip the genome and make sure it does not have internal new line characters. 
    if [ -f *.gz ]; then
      gunzip -c "$genome" > myunzip.fa
      #myunzip.fa=\$(gunzip -c "$genome")
      awk '/^>/ { print (NR==1 ? "" : RS) \$0; next } { printf "%s", \$0 } END { printf RS }' myunzip.fa > genome_line_removal.fasta
    else
      awk '/^>/ { print (NR==1 ? "" : RS) \$0; next } { printf "%s", \$0 } END { printf RS }' $genome > genome_line_removal.fasta
    fi


    #Make sure earl grey scripts are in path
    PATH=$PATH:/opt/conda/envs/myenv/bin/

    # Capture the current working directory
    mydir=`pwd`

    # Create the output directory
    mkdir -p \${mydir}/${species}_earl_results

    # Run earl grey non-interactively.
    yes | earlGrey -g genome_line_removal.fasta -s $species -o \${mydir}/${species}_earl_results -t ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python version: \$(python --version | cut -f 2 -d " ")
        Earl Grey version: \$(earlGrey | grep version | cut -f 3 -d " ")
        Repeat Masker version: \$(RepeatMasker | grep version | cut -f 3 -d " ")
        Repeat Modeler version: \$(RepeatModeler | grep /usr/local/bin/RepeatModeler | cut -f 3 -d " ")
        LTRPipeline version: \$(LTRPipeline -version)
    END_VERSIONS
    """
}
