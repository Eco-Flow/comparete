#!/usr/bin/env nextflow

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

include { DOWNLOAD_NCBI } from './modules/local/download_ncbi.nf'
include { DOWNLOAD_NCBI as DOWNLOAD_NCBI_2 } from './modules/local/download_ncbi.nf'
include { GFFREAD as GFFREAD_2} from './modules/local/gffread.nf'
include { GFFREAD } from './modules/local/gffread.nf'
include { ORTHOFINDER } from './modules/nf-core/orthofinder/main.nf'
include { EARLGREY } from './modules/local/earlgrey.nf'
include { HITE } from './modules/local/hite.nf'

include { validateParameters; paramsHelp; paramsSummaryLog } from 'plugin/nf-validation'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'


workflow {

   if (params.help) {
      log.info paramsHelp("nextflow run main.nf --input input_file.csv")
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

   // Validate input parameters --- ##need to add with nf-core schema build. !
   //validateParameters()

   // Print summary of supplied parameters
   log.info paramsSummaryLog(workflow)

   DOWNLOAD_NCBI ( refseqids )
   ch_versions = ch_versions.mix(DOWNLOAD_NCBI.out.versions.first())

    //Checks if paths are S3 objects if not ensures absolute paths are used for user inputted fasta and gff files
    input_type.path.map{ name, fasta , gff -> if (fasta =~ /^s3/ ) { full_fasta = fasta } \
    else { full_fasta = new File(fasta).getAbsolutePath()}; \
    if (gff =~ /^s3/) { full_gff = gff } \
    else { full_gff = new File(gff).getAbsolutePath()}; \
    [name, full_fasta, full_gff] }.set{ local_full_tuple }

    //Split channel into 2, keep tuple the same for gffread and take just sample id and fasta for fastavalidator
    DOWNLOAD_NCBI.out.genome.mix(local_full_tuple)
         .multiMap { it ->
             gffread: it
             tuple: [[ id: it[0]], it[1]]
          }
          .set { fasta_inputs }

   GFFREAD ( DOWNLOAD_NCBI.out.genome.mix(input_type.path) )
   ch_versions = ch_versions.mix(GFFREAD.out.versions.first())

   merge_ch = GFFREAD.out.longest.collect()

   merge_ch.subscribe { files ->
      println "Collected files: ${files}"
   }

   meta_id = [id: 'orthofinder']

   meta_files_ch = merge_ch.map { files ->
      tuple(meta_id, files)
   }

   if (params.orthofinder){

      if (params.ortho_resume){

            //Check if input is provided
         in_file_ortho = params.ortho_new_input != null ? Channel.fromPath(params.ortho_new_input) : errorMessage()

         in_file_ortho
            .splitCsv()
            .branch {
               ncbi: it.size() == 2
               path: it.size() == 3
            }
            .set { input_type_o }

         twocol_o = input_type_o.ncbi

         // Separate files into FASTA files and other files
         genomeonly_o = twocol_o.filter { row ->
            def filePath = row[1]  // assuming the file path is the second column
            fastaExtensions.any { filePath.endsWith(it) }
         }

         refseqids_o = twocol_o.filter { row ->
            def filePath = row[1]  // assuming the file path is the second column
            !fastaExtensions.any { filePath.endsWith(it) }
         }

         DOWNLOAD_NCBI_2 ( refseqids_o )

         //Checks if paths are S3 objects if not ensures absolute paths are used for user inputted fasta and gff files
         input_type_o.path.map{ name, fasta , gff -> if (fasta =~ /^s3/ ) { full_fasta = fasta } \
         else { full_fasta = new File(fasta).getAbsolutePath()}; \
         if (gff =~ /^s3/) { full_gff = gff } \
         else { full_gff = new File(gff).getAbsolutePath()}; \
         [name, full_fasta, full_gff] }.set{ local_full_tuple_o }

         //Split channel into 2, keep tuple the same for gffread and take just sample id and fasta for fastavalidator
         DOWNLOAD_NCBI_2.out.genome.mix(local_full_tuple_o)
               .multiMap { it ->
                  gffread: it
                  tuple: [[ id: it[0]], it[1]]
               }
               .set { fasta_inputs_o }

         GFFREAD_2 ( DOWNLOAD_NCBI_2.out.genome.mix(input_type_o.path) )
         ch_versions = ch_versions.mix(GFFREAD_2.out.versions.first())

         merge_ch_o = GFFREAD_2.out.longest.collect()

         meta_id_o = [id: 'orthofinder_2']

         meta_files_ch_o = merge_ch_o.map { files ->
            tuple(meta_id, files)
         }

         continue_ch = channel.of(file(params.ortho_resume))
         ORTHOFINDER ( meta_files_ch_o , continue_ch )

      }
      else{

         ORTHOFINDER ( meta_files_ch , [] )

      }

   }

   //Only takes NCBI genomes, but later we need to add locally input genomes.
   if (params.earlgrey){
      EARLGREY (GFFREAD.out.just_genome.mix(genomeonly))
   }

   if (params.hite){
      HITE (GFFREAD.out.just_genome.mix(genomeonly))
   }
   
}
