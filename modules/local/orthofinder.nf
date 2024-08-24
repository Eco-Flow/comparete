process ORTHOFINDER {
    label 'process_medium'
    label 'process_long'
    container = 'quay.io/ecoflowucl/orthofinder:2.5.5'
    
    input:
    path '*'

    output:
    path("result")                                            , emit: full_ortho
    path("versions.yml")                                      , emit: versions

    script:
    """
    if [ -f *.gz ]; then
       gunzip *.gz
    fi

    orthofinder -f . -o My_result
    
    #Remove Dated folder system that prevents unit testing
    mkdir result
    mv My_result/*/* ./result

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python version: \$(python --version | cut -f 2 -d " ")
        Orthofinder version: \$(orthofinder | grep version | cut -f 3 -d " ")
    END_VERSIONS
    """
}
