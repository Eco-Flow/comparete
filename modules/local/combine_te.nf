process COMBINE_TE {
    label 'process_single'
    container 'rocker/tidyverse:latest'

    input:
    path(per_species_totals)
    path(per_species_by_class)

    output:
    path("combined_te_totals.tsv")     , emit: totals
    path("combined_te_by_class.tsv")   , emit: by_class
    path("combined_te_comparison.pdf") , emit: figure
    path("versions.yml")               , emit: versions

    script:
    """
    combine_te.R

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R version: \$(R --version | head -n 1 | sed 's/^R version //; s/ .*//')
    END_VERSIONS
    """
}
