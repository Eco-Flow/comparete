process EARLGREY {
    label 'process_medium'
    tag "$species"
    container = 'tobybaril/earlgrey_dfam3.7:latest'
    containerOptions '-v `pwd`:/data/'
    //tobybaril/earlgrey_dfam3.7:latest
    input:
    tuple val(species), path(genome)

    output:
    path("earlgreyresults.tsv") , emit: te_results
    path("versions.yml"), emit: versions

    script:
    """
    if [ -f *.gz ]; then
       gunzip *.gz
    fi

    awk '/^>/ { print (NR==1 ? "" : RS) \$0; next } { printf "%s", \$0 } END { printf RS }' $genome > genome_line_removal.fasta

    earlGrey -g genome_line_removal.fasta -s $species -o earlgreyresults.tsv -t 4

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        //Python version: \$(python --version | cut -f 2 -d " ")
        //Orthofinder version: \$(orthofinder | grep version | cut -f 3 -d " ")
    END_VERSIONS
    """
}