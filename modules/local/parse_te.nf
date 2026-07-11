process PARSE_TE {
    label 'process_single'
    tag "${species}:${method}"
    container 'rocker/tidyverse:latest'

    input:
    tuple val(species), val(method), path(te_output), path(genome)

    output:
    tuple val(species), path("${species}_${method}_te.tsv"), emit: table
    path("versions.yml")                                   , emit: versions

    script:
    """
    # Genome size (bp), streaming the FASTA and handling optional gzip.
    genome_file="${genome}"
    if [ "\${genome_file}" != "\${genome_file%.gz}" ]; then
        genome_size=\$(zcat "\${genome_file}" | grep -v '^>' | tr -d '\\n' | wc -c)
    else
        genome_size=\$(grep -v '^>' "\${genome_file}" | tr -d '\\n' | wc -c)
    fi

    parse_te.R \\
        --species "${species}" \\
        --method "${method}" \\
        --input "${te_output}" \\
        --genome_size "\${genome_size}" \\
        --out "${species}_${method}_te.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R version: \$(R --version | head -n 1 | sed 's/^R version //; s/ .*//')
    END_VERSIONS
    """
}
