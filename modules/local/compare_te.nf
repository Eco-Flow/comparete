process COMPARE_TE {
    label 'process_single'
    tag "$species"
    container 'rocker/tidyverse:latest'

    input:
    tuple val(species), path(earl_results), path(hite_results), path(genome)

    output:
    tuple val(species), path("${species}_te_comparison.tsv")        , emit: table
    tuple val(species), path("${species}_te_comparison_by_class.tsv"), emit: table_by_class
    tuple val(species), path("${species}_te_comparison.pdf")        , emit: figure
    path("versions.yml")                                            , emit: versions

    script:
    """
    # Compute genome size (bp) by streaming the FASTA, handling optional gzip.
    genome_file="${genome}"
    if [ "\${genome_file}" != "\${genome_file%.gz}" ]; then
        genome_size=\$(zcat "\${genome_file}" | grep -v '^>' | tr -d '\\n' | wc -c)
    else
        genome_size=\$(grep -v '^>' "\${genome_file}" | tr -d '\\n' | wc -c)
    fi

    compare_te.R \\
        --species "${species}" \\
        --earlgrey "${earl_results}" \\
        --hite "${hite_results}" \\
        --genome_size "\${genome_size}" \\
        --out_prefix "${species}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R version: \$(R --version | head -n 1 | sed 's/^R version //; s/ .*//')
    END_VERSIONS
    """
}
