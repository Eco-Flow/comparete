process HITE {
    label 'process_medium'
    tag "$species"
    container = 'kanghu/hite:3.2.0'
    //containerOptions '-v `pwd`:`pwd`'
    
    input:
    tuple val(species), path(genome)

    output:
    path("${sample_id}_hite_results") , emit: hite_results
    path("versions.yml"), emit: versions

    script:
    """
    if [ -f *.gz ]; then
       gunzip *.gz
    fi

    # Capture the current working directory
    mydir=`pwd`

    # Create the output directory
    mkdir -p \${mydir}/${sample_id}_hite_results

    cd /HiTE

    python main.py --genome /HiTE/demo/genome.fa --outdir \${mydir}/${sample_id}_hite_results
    """
}