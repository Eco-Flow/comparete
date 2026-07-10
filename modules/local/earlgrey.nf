process EARLGREY {
    label 'process_high_memory'
    tag "$species"
    //container = 'quay.io/biocontainers/earlgrey:4.2.4--h4ac6f70_0'
    // The official Earl Grey image ships a fully-configured RepeatMasker (Dfam 3.7 +
    // built RepeatMasker.lib). Wave (enabled globally) augments this Docker image into
    // a pullable, Singularity-ready container without stripping its bundled databases.
    container 'tobybaril/earlgrey_dfam3.7:latest'
    // Optional: bind-mount a newer Dfam famdb over the bundled one. Leave --famdb unset
    // to use the container's built-in Dfam 3.7 (recommended, keeps library consistency).
    containerOptions { params.famdb ? "-B ${params.famdb}:/opt/conda/share/RepeatMasker/Libraries/famdb" : '' }
    //stageInMode = 'copy'

    input:
    tuple val(species), path(genome)

    output:
    path("${species}_earl_results"), emit: te_results
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
    PATH=\$PATH:/opt/conda/envs/myenv/bin/

    # Initialize PERL5LIB if not already set
    : \${PERL5LIB:=}

    #Make sure perl modules are visible
    export PERL5LIB=\$PERL5LIB:/usr/local/lib/perl5/vendor_perl/File/
    export PERL5LIB=\$PERL5LIB:/usr/local/lib/perl5/vendor_perl/

    # Capture the current working directory
    mydir=`pwd`

    # Create the output directory
    mkdir -p \${mydir}/${species}_earl_results

    # Run earl grey non-interactively. `yes` feeds prompt answers and gets SIGPIPE
    # (exit 141) once Earl Grey stops reading stdin; under `set -o pipefail` that would
    # fail the task even on success, so use Earl Grey's own exit status instead.
    set +e
    yes | earlGrey -g genome_line_removal.fasta -s $species -o \${mydir}/${species}_earl_results -t ${task.cpus}
    earlgrey_status=\${PIPESTATUS[1]}
    set -e
    if [ "\${earlgrey_status}" -ne 0 ]; then
        echo "Earl Grey failed with exit status \${earlgrey_status}" >&2
        exit \${earlgrey_status}
    fi

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
