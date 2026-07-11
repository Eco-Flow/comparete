//
// RepeatMasker / RepeatModeler TE annotation subworkflow.
//
// Ported and trimmed from genomeqc's FASTA_ANNOTATE_TE (the `repeatmasker` branch).
// Differences here:
//   - The Dfam library is taken from a pre-staged famdb (--famdb), so there is no
//     download step (RM_DOWNLOAD_DB is not used).
//   - HITE is handled separately in the main workflow and is not part of this SW.
//
// Channels use nf-core meta maps ([id: species]); the main workflow wraps
// comparete's (species, genome) tuples before calling this.

include { FAMDB_PY_EMBL               } from '../../modules/local/famdb_py_embl/main'
include { REPEATMODELER_BUILDDATABASE } from '../../modules/nf-core/repeatmodeler/builddatabase/main'
include { REPEATMODELER_REPEATMODELER } from '../../modules/nf-core/repeatmodeler/repeatmodeler/main'
include { CAT_CAT                     } from '../../modules/nf-core/cat/cat/main'
include { CDHIT_CDHITEST              } from '../../modules/nf-core/cdhit/cdhitest/main'
include { MMSEQS_EASYCLUSTER          } from '../../modules/nf-core/mmseqs/easycluster/main'
include { MMSEQS_EASYLINCLUST         } from '../../modules/local/mmseqs_easylinclust/main'
include { REPEATMASKER_REPEATMASKER   } from '../../modules/nf-core/repeatmasker/repeatmasker/main'
include { TE_TBL_2_TABLE              } from '../../modules/local/te_tbl_2_table/main'


workflow REPEATMASKERSUB {

    take:
    ch_fasta              // channel: [ val(meta), path(fasta) ]
    ch_famdb_lib          // channel: [ val(meta), [ path(h5), ... ] ]
    val_famdb_lineage     // val: lineage for famdb extraction (e.g. 'hymenoptera'), or 'root'
    val_run_repeatmodeler // val: boolean – run de novo RepeatModeler (slow)
    val_te_clusterer      // val: 'linclust' (default), 'mmseqs', or 'cdhit'

    main:
    def ch_clustered_lib = channel.empty()

    // MODULE: FAMDB_PY_EMBL
    // Extract the repeat library from the famdb h5 partitions for the given lineage.
    FAMDB_PY_EMBL (
        ch_famdb_lib,
        val_famdb_lineage
    )

    if (val_run_repeatmodeler) {
        // Per-genome path: RepeatModeler builds a genome-specific de novo library,
        // merged with the shared famdb library before clustering.
        REPEATMODELER_BUILDDATABASE ( ch_fasta )
        REPEATMODELER_REPEATMODELER ( REPEATMODELER_BUILDDATABASE.out.db )
        ch_modeler_fasta = REPEATMODELER_REPEATMODELER.out.fasta

        ch_famdb_fasta = FAMDB_PY_EMBL.out.famdb_lib | map { _meta, fasta -> fasta }

        // Genomes where RepeatModeler succeeded: pair [famdb, modeler].
        ch_famdb_with_modeler = ch_modeler_fasta
                              | combine(ch_famdb_fasta)
                              | map { meta, modeler, famdb -> tuple(meta, [famdb, modeler]) }

        // RepeatModeler emits nothing when it finds no families, so build a
        // famdb-only fallback for every genome to avoid dropping any.
        ch_famb_without_modeler = ch_fasta
                               | combine(ch_famdb_fasta)
                               | map { meta, _fasta, famdb -> tuple(meta, [famdb]) }

        ch_combined_libs = ch_famb_without_modeler
                         | join(ch_famdb_with_modeler, by: 0, remainder: true)
                         | map { meta, famdb_list, both_list ->
                             tuple(meta, both_list ?: famdb_list)
                         }

        // MODULE: CAT_CAT — concatenate famdb and de novo libraries (per genome)
        CAT_CAT ( ch_combined_libs )

        if (val_te_clusterer == 'cdhit') {
            CDHIT_CDHITEST ( CAT_CAT.out.file_out )
            ch_clustered_lib = CDHIT_CDHITEST.out.fasta
        } else if (val_te_clusterer == 'mmseqs') {
            MMSEQS_EASYCLUSTER ( CAT_CAT.out.file_out )
            ch_clustered_lib = MMSEQS_EASYCLUSTER.out.representatives
        } else {
            MMSEQS_EASYLINCLUST ( CAT_CAT.out.file_out )
            ch_clustered_lib = MMSEQS_EASYLINCLUST.out.representatives
        }

    } else {
        // Shared path: cluster the famdb library once, then broadcast to every genome.
        if (val_te_clusterer == 'cdhit') {
            CDHIT_CDHITEST ( FAMDB_PY_EMBL.out.famdb_lib )
            ch_shared_lib = CDHIT_CDHITEST.out.fasta | map { _meta, fasta -> fasta }
        } else if (val_te_clusterer == 'mmseqs') {
            MMSEQS_EASYCLUSTER ( FAMDB_PY_EMBL.out.famdb_lib )
            ch_shared_lib = MMSEQS_EASYCLUSTER.out.representatives | map { _meta, fasta -> fasta }
        } else {
            MMSEQS_EASYLINCLUST ( FAMDB_PY_EMBL.out.famdb_lib )
            ch_shared_lib = MMSEQS_EASYLINCLUST.out.representatives | map { _meta, fasta -> fasta }
        }

        ch_clustered_lib = ch_fasta
                         | map { meta, _fasta -> meta }
                         | combine(ch_shared_lib)
                         | map { meta, lib -> tuple(meta, lib) }
    }

    // MODULE: REPEATMASKER_REPEATMASKER
    // Soft-mask each genome using its paired repeat library.
    REPEATMASKER_REPEATMASKER (
        ch_fasta,
        ch_clustered_lib
    )

    // Parse all .tbl files into a single TSV (one row per genome).
    ch_te_tbl_collect = REPEATMASKER_REPEATMASKER.out.tbl.map { _meta, f -> f }.collect()
    TE_TBL_2_TABLE (
        ch_te_tbl_collect.map { f -> tuple([id: 'te_table'], f) }
    )

    emit:
    masked         = REPEATMASKER_REPEATMASKER.out.masked // [ val(meta), path(masked) ]
    out            = REPEATMASKER_REPEATMASKER.out.out    // [ val(meta), path(out) ]
    tbl            = REPEATMASKER_REPEATMASKER.out.tbl     // [ val(meta), path(tbl) ]
    gff            = REPEATMASKER_REPEATMASKER.out.gff     // [ val(meta), path(gff) ]
    tbl_tsv        = TE_TBL_2_TABLE.out.table             // [ val(meta), path(tsv) ]
    repeat_library = ch_clustered_lib                     // [ val(meta), path(fasta) ]
}
