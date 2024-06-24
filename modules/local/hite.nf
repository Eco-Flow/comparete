process HITE {
    label 'process_medium'
    tag "$species"
    container = 'kanghu/hite:3.2.0'
    
    input:
    tuple val(species), path(genome)

    output:
    path("hite_results.tsv") , emit: hite_results
    path("versions.yml"), emit: versions

    script:
    """
    if [ -f *.gz ]; then
       gunzip *.gz
    fi

    ls

    python /HiTE/main.py --genome $genome --thread ${task.cpus} --plant 0 --outdir hite_results.tsv --annotate 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        //To be completed once module is set up.
        //Python version: \$(python --version | cut -f 2 -d " ")
        //Orthofinder version: \$(orthofinder | grep version | cut -f 3 -d " ")
    END_VERSIONS
    """
}