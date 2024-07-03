process HITE {
    label 'process_single'
    label 'process_long'
    tag "$species"
    container = 'kanghu/hite:3.2.0'
    stageInMode = 'copy'
    containerOptions = '-v `pwd`:`pwd`'
    
    input:
    tuple val(species), path(genome)

    output:
    path("${species}_hite_results") , emit: hite_results
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

    # Capture the current working directory
    mydir=`pwd`

    # Create the output directory
    mkdir -p \${mydir}/${species}_hite_results

    newpath=`realpath genome_line_removal.fasta`

    cd /HiTE


    python main.py --genome \${newpath} --outdir \${mydir}/${species}_hite_results --thread ${task.cpus}

    cd \${mydir}/${species}_hite_results/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      Python version: \$(python --version | cut -f 2 -d " ")
      HiTE version: 3.2.0
      Repeat Masker version: \$(RepeatMasker | grep version | cut -f 3 -d " ")
      Repeat Modeler version: \$(RepeatModeler | grep /opt/conda/envs/HiTE/share/RepeatModeler/RepeatModeler | cut -f 3 -d " ")
      LTRPipeline version: \$(LTRPipeline -version)
    END_VERSIONS
    """
}
