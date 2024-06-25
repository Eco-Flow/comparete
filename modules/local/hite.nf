process HITE {
    label 'process_single'
    label 'process_long'
    tag "$species"
    container = 'kanghu/hite:3.2.0'
    //containerOptions '-v `pwd`:`pwd`'
    
    input:
    tuple val(species), path(genome)

    output:
    path("${species}_hite_results") , emit: hite_results
    path("versions.yml"), emit: versions

    script:
    """
    if [ -f *.gz ]; then
       gunzip *.gz
    fi

    # Capture the current working directory
    mydir=`pwd`

    # Create the output directory
    mkdir -p \${mydir}/${species}_hite_results

    cd /HiTE

    python main.py --genome /HiTE/demo/genome.fa --outdir \${mydir}/${species}_hite_results
    """
}
