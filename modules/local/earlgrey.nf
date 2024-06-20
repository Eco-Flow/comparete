process EARLGREY {
    label 'process_medium'
    tag "$species"
    container = 'quay.io/biocontainers/earlgrey:4.2.4--h4ac6f70_0'
    
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

    earlGrey -g $genome -s $species -o earlgreyresults.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        //Python version: \$(python --version | cut -f 2 -d " ")
        //Orthofinder version: \$(orthofinder | grep version | cut -f 3 -d " ")
    END_VERSIONS
    """
}