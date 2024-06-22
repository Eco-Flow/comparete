process EARLGREY {
    label 'process_medium'
    tag "$species"
    container = 'quay.io/ecoflowucl/earlgrey:v1.2'
    //containerOptions '-v `pwd`:/workspace'
    input:
    tuple val(species), path(genome)

    output:
    path("earlgreyresults.tsv"), emit: te_results
    path("versions.yml"), emit: versions

    script:
    """
    #conda create -n earlgrey -c conda-forge -c bioconda earlgrey=4.2.4

    if [ -f *.gz ]; then
       gunzip *.gz
    fi

    awk '/^>/ { print (NR==1 ? "" : RS) \$0; next } { printf "%s", \$0 } END { printf RS }' $genome > genome_line_removal.fasta

    #ls /opt/conda/envs/myenv/bin/

    PATH=$PATH:/opt/conda/envs/myenv/bin/

    earlGrey -g genome_line_removal.fasta -s $species -o earlgreyresults.tsv -t 4

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        //Python version: \$(python --version | cut -f 2 -d " ")
        //Orthofinder version: \$(orthofinder | grep version | cut -f 3 -d " ")
    END_VERSIONS
    """
}
