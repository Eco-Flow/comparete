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
include { GFFREAD } from './modules/local/gffread.nf'
include { ORTHOFINDER } from './modules/local/orthofinder.nf'
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


   //Make a channel for version outputs:
   ch_versions = Channel.empty()

   // Validate input parameters --- ##need to add with nf-core schema build. !
   //validateParameters()

   // Print summary of supplied parameters
   log.info paramsSummaryLog(workflow)

   DOWNLOAD_NCBI ( input_type.ncbi )
    ch_versions = ch_versions.mix(DOWNLOAD_NCBI.out.versions.first())

    //Checks if paths are S3 objects if not ensures absolute paths are used for user inputted fasta and gff files
    input_type.path.map{ name, fasta , gff -> if (fasta =~ /^s3/ ) { full_fasta = fasta } else { full_fasta = new File(fasta).getAbsolutePath()}; if (gff =~ /^s3/) { full_gff = gff } else { full_gff = new File(gff).getAbsolutePath()}; [name, full_fasta, full_gff] }.set{ local_full_tuple }

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

   if (params.orthofinder){

      ORTHOFINDER ( merge_ch )

   }

   //Only takes NCBI genomes, but later we need to add locally input genomes.
   if (params.earlgrey){
      EARLGREY (GFFREAD.out.just_genome)
   }

   if (params.hite){
      HITE (DOWNLOAD_NCBI.out.genome_only)
   }

}