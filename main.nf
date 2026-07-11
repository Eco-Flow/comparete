#!/usr/bin/env nextflow

include { DOWNLOAD_NCBI } from './modules/local/download_ncbi.nf'
include { GFFREAD } from './modules/local/gffread.nf'
include { ORTHOFINDER } from './modules/local/orthofinder.nf'
include { EARLGREY } from './modules/local/earlgrey.nf'
include { HITE } from './modules/local/hite.nf'
include { PARSE_TE } from './modules/local/parse_te.nf'
include { COMBINE_TE } from './modules/local/combine_te.nf'
include { REPEATMASKERSUB } from './subworkflows/local/repeatmaskersub.nf'

include { validateParameters; paramsHelp; paramsSummaryLog } from 'plugin/nf-schema'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'

def errorMessage() {
   log.error "Please provide an input CSV file with --input"
   exit 1
}

workflow {

   log.info """\
    =========================================

    COMPARE TE (v1.0)

    -----------------------------------------

    Authors:
      - Chris Wyatt <c.wyatt@ucl.ac.uk>
      - Rahia Mashoodh <>

    -----------------------------------------

    Copyright (c) 2024

    =========================================""".stripIndent()

   if (params.help) {
      log.info paramsHelp(command: "nextflow run main.nf --input input_file.csv")
      exit 0
   }

   //Check if input is provided
   in_file = params.input != null ? Channel.fromPath(params.input) : errorMessage()

   in_file
      .splitCsv()
      .branch {
         ncbi: it.size() == 2
         path: it.size() == 3
      }
      .set { input_type }

   twocol = input_type.ncbi

   def fastaExtensions = ['.fa', '.fasta', '.fna', '.fa.gz', '.fasta.gz', '.fna.gz']

   // Separate files into FASTA files and other files
   genomeonly = twocol.filter { row ->
      def filePath = row[1]  // assuming the file path is the second column
      fastaExtensions.any { filePath.endsWith(it) }
   }

   refseqids = twocol.filter { row ->
      def filePath = row[1]  // assuming the file path is the second column
      !fastaExtensions.any { filePath.endsWith(it) }
   }

   //Make a channel for version outputs:
   ch_versions = Channel.empty()

   // Validate input parameters against nextflow_schema.json
   validateParameters()

   // Print summary of supplied parameters
   log.info paramsSummaryLog(workflow)

   DOWNLOAD_NCBI ( refseqids )
    ch_versions = ch_versions.mix(DOWNLOAD_NCBI.out.versions.first())

    //Checks if paths are S3 objects if not ensures absolute paths are used for user inputted fasta and gff files
    input_type.path
       .map { name, fasta, gff ->
          def full_fasta = fasta =~ /^s3/ ? fasta : new File(fasta).getAbsolutePath()
          def full_gff   = gff =~ /^s3/ ? gff : new File(gff).getAbsolutePath()
          [name, full_fasta, full_gff]
       }
       .set { local_full_tuple }

    // Only run GFFREAD if orthofinder is enabled (requires GFF annotation)
    if (params.orthofinder) {
       GFFREAD ( DOWNLOAD_NCBI.out.genome.mix(input_type.path) )
       ch_versions = ch_versions.mix(GFFREAD.out.versions.first())

       merge_ch = GFFREAD.out.longest.collect()

       ORTHOFINDER ( merge_ch )
    }

    //Only takes NCBI genomes, but later we need to add locally input genomes.
    ch_te_genome = params.orthofinder ? GFFREAD.out.just_genome.mix(genomeonly) : DOWNLOAD_NCBI.out.genome.mix(input_type.path).map { n, f, g -> tuple(n, f) }.mix(genomeonly)

   // Each TE method emits, per species, a tagged (species, method, output) tuple.
   // These are mixed together so any subset of methods can be combined downstream.
   ch_te_annot = Channel.empty()

   if (params.earlgrey){
      EARLGREY (ch_te_genome)
      ch_te_annot = ch_te_annot.mix(
         EARLGREY.out.te_results.map { sp, d -> tuple(sp, 'earlgrey', d) }
      )
   }

   if (params.hite){
      HITE (ch_te_genome)
      ch_te_annot = ch_te_annot.mix(
         HITE.out.hite_results.map { sp, d -> tuple(sp, 'hite', d) }
      )
   }

   // RepeatMasker / RepeatModeler TE annotation subworkflow (optional).
   if (params.repeatmasker){
      if (params.famdb == null) {
         log.error "--repeatmasker requires a Dfam famdb. Provide one with --famdb /path/to/famdb (a directory containing the Dfam .h5 partitions)."
         exit 1
      }
      // Wrap comparete's (species, genome) tuples as nf-core meta maps, and collect
      // the famdb .h5 partitions into a single value channel for famdb.py.
      ch_rm_fasta = ch_te_genome.map { sp, g -> tuple([id: sp], g) }
      ch_famdb_h5 = Channel.fromPath("${params.famdb}/*.h5")
                       .collect()
                       .map { files -> tuple([id: 'famdb'], files) }

      REPEATMASKERSUB (
         ch_rm_fasta,
         ch_famdb_h5,
         params.famdb_lineage ?: 'root',
         params.run_repeatmodeler,
         params.te_clusterer
      )
      ch_te_annot = ch_te_annot.mix(
         REPEATMASKERSUB.out.out.map { meta, f -> tuple(meta.id, 'repeatmasker', f) }
      )
   }

   // Parse each method's output into a normalised per-(species, method) table,
   // then combine everything that ran into one table + figure. Works for any
   // subset of methods (one, two, or all three).
   if (params.earlgrey || params.hite || params.repeatmasker){
      PARSE_TE ( ch_te_annot.combine(ch_te_genome, by: 0) )
      COMBINE_TE ( PARSE_TE.out.table.map { sp, f -> f }.collect() )
   }

}
