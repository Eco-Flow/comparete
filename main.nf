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

include { GET_DATA } from './modules/local/getdata.nf'
include { DOWNLOAD_NCBI } from './modules/local/download_ncbi.nf'
include { GFFREAD } from './modules/local/gffread.nf'
include { ORTHOFINDER } from './modules/local/orthofinder.nf'
//include { EARLGREY } from './modules/local/earlgrey.nf'

include { validateParameters; paramsHelp; paramsSummaryLog } from 'plugin/nf-validation'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'


workflow {

   if (params.help) {
      log.info paramsHelp("nextflow run main.nf --input input_file.csv")
      exit 0
   }

   Channel
   .fromPath(params.input)
   .splitCsv()
   .branch { 
     ncbi: it.size() == 2
     local: it.size() == 3
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
   
   GFFREAD ( DOWNLOAD_NCBI.out.genome.mix(input_type.local) )
   ch_versions = ch_versions.mix(GFFREAD.out.versions.first())

   merge_ch = GFFREAD.out.longest.collect()

   if (params.orthofinder){

      ORTHOFINDER_CAFE ( merge_ch )

   }

   //EARLGREY (DOWNLOAD_NCBI.out.genome.mix(input_type.local))

}