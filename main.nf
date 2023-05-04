#!/usr/bin/env nextflow

/*
 * Enable modules
 * https://www.nextflow.io/docs/latest/dsl2.html
 */
nextflow.enable.dsl=2

/*
 * Default pipeline parameters. They can be overriden on the command line eg.
 * given `params.foo` specify on the run command line `--foo some_value`.
 */
params.project_dir = "${projectDir}"
params.reads = "$projectDir/*_{1,2}.fastq"
params.star_index = "$projectDir/assembly-annotation/refdata-gex-GRCh38-2020-A/star"
params.results_dir = 'results'
params.trim_length = 30

log.info """\
 R N A S E Q  P I P E L I N E - P A I R  E N D  (G R C h 3 8)
 ===================================
 reads                    : ${params.reads}
 star_index               : ${params.star_index}
 results_dir              : ${params.results_dir}
 trim_length              : ${params.trim_length}
 gene_results_table_id    : ${params.gene_results_table_id}
 isoform_results_table_id : ${params.isoform_results_table_id}
 """


/*
 * Apply adapter and quality trimming to FastQ files with Trim Galore
 */
process TRIMGALORE {
    tag "$pair_id"

    input:
    tuple val(pair_id), path(reads)
    val(trim_length)

    output:
    tuple val(pair_id), path("*.fq.gz"), emit: trimmed_read_pairs_ch

    script:
    """
    echo ${pair_id}
    trim_galore --length $trim_length --paired $reads --cores=4
    """
}

/*
 * Perform quality control checks with FastQC
 */
process FASTQC {
    tag "$pair_id"
    publishDir "${results_dir}/${pair_id}/fastqc", mode: 'copy'

    input:
    tuple val(pair_id), path(reads)
    val(results_dir)

    output:
    path("fastqc_${pair_id}_logs/*")

    script:
    """
    mkdir -p fastqc_${pair_id}_logs
    fastqc -o fastqc_${pair_id}_logs -f fastq -q $reads
    """
}

/*
 * Estimate gene and isoform expression from FASTQ using RSEM
 */
process RSEM {
    tag "$pair_id"
    publishDir "${results_dir}/${pair_id}/rsem", mode: 'copy'

    input:
    tuple val(pair_id), path(trimmed_reads)
    path(star_index)
    path(annotations_gtf)
    path(annotations_fasta)
    val(results_dir)

    output:
    tuple val(pair_id), path("output_${pair_id}.genes.results"), emit: gene_results_ch
    tuple val(pair_id), path("output_${pair_id}.isoforms.results"), emit: isoform_results_ch
    tuple val(pair_id), path("output_${pair_id}.genome.bam"), emit: bam_results_ch

    script:
    """
    echo $star_index files:
    ls -rlth $star_index
    cp -rf $star_index/* .
    echo "./ files:"
    ls -rlth .
    rsem-prepare-reference --gtf ${annotations_gtf} ${annotations_fasta} star
    rsem-calculate-expression -p 8 <(zcat ${trimmed_reads[0]}) <(zcat ${trimmed_reads[1]}) --paired-end \
      --star --seed 1337 \
      --estimate-rspd \
      --append-names \
      --output-genome-bam \
      $star_index output_${pair_id}
    """
}

/*
 * Write gene results to BQ
 */
process WRITE_GENE_RESULTS_TO_BQ {
    tag "$pair_id"

    input:
    tuple val(pair_id), path(results)
    val(table_id)
    path(project_dir)

    script:
    """
    python ${project_dir}/load_rsem_results_into_bq.py \
      --results_type gene \
      --results_path ${results} \
      --table_id ${table_id} \
      --sample_id ${pair_id} \
      --verbose True
    """
}

/*
 * Write isoform results to BQ
 */
process WRITE_ISOFORM_RESULTS_TO_BQ {
    tag "$pair_id"

    input:
    tuple val(pair_id), path(results)
    val(table_id)
    path(project_dir)

    script:
    """
    python ${project_dir}/load_rsem_results_into_bq.py \
      --results_type isoform \
      --results_path ${results} \
      --table_id ${table_id} \
      --sample_id ${pair_id} \
      --verbose True
    """
}

workflow {
  read_pairs_ch = channel.fromFilePairs(params.reads, checkIfExists: true)
  TRIMGALORE(read_pairs_ch, params.trim_length)
  FASTQC(TRIMGALORE.out.trimmed_read_pairs_ch, params.results_dir)
  RSEM(TRIMGALORE.out.trimmed_read_pairs_ch, params.star_index, params.annotations_gtf, params.annotations_fasta, params.results_dir)
  WRITE_GENE_RESULTS_TO_BQ(RSEM.out.gene_results_ch, params.gene_results_table_id, params.project_dir)
  WRITE_ISOFORM_RESULTS_TO_BQ(RSEM.out.isoform_results_ch, params.isoform_results_table_id, params.project_dir)
}

/*
 * Completion Handler
 */
workflow.onComplete {
	log.info ( workflow.success ? "\nDone! Find read pair results here --> ${params.results_dir}\n" : "Oops .. something went wrong" )
}
