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
params.reads = "$projectDir/*_{1,2}.fastq.gz"
params.results_dir = 'results'
params.trim_length = 30

log.info """\
 S I M P L E  V A R I A N T - C A L L I N G  (G R C h 3 8)
 ===================================
 reads                    : ${params.reads}
 results_dir              : ${params.results_dir}
 trim_length              : ${params.trim_length}
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
    trim_galore --length ${trim_length} --paired ${reads} --cores=4
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
 * Index the reference genome for use by bwa and samtools.
 */
process BWA_INDEX {
   tag{"BWA_INDEX ${genome}"}
   publishDir "${results_dir}/bwa_index", mode: 'copy'
   
   input:
   path genome
   val(results_dir)
   
   output:
   tuple path(genome), path( "*" ), emit: bwa_index
   
   script:
   """
   bwa index ${genome} 
   """
}

/*
 * Align reads to reference genome & create BAM file.
 */
process BWA_ALIGN {
    tag "$pair_id"
    publishDir "${results_dir}/${pair_id}/aligned_bam", mode: 'copy'
    
    input:
    tuple path(genome), path("*"), val(pair_id), path(reads)
    val(results_dir)

    output:
    tuple val(pair_id), path("${pair_id}.aligned.bam"), emit: aligned_bam

    script:
    """
    INDEX=`find -L ./ -name "*.amb" | sed 's/.amb//'`
    bwa mem \$INDEX ${reads} > ${pair_id}.aligned.sam
    samtools view -S -b ${pair_id}.aligned.sam > ${pair_id}.aligned.bam
    """
}

/*
 * Convert the format of the alignment to sorted BAM.
 */
process SAMTOOLS_SORT {
   tag "$pair_id"
   publishDir "${results_dir}/${pair_id}/sorted_bam", mode: 'copy'

   input:
   tuple val(pair_id), path(bam)
   val(results_dir)

   output:
   tuple val(pair_id), path("${pair_id}.aligned.sorted.bam"), emit: sorted_bam

   script:
   """
   samtools sort -o "${pair_id}.aligned.sorted.bam" ${bam}
   """
}

/*
 * Index the BAM file for visualization purpose
 */
process SAMTOOLS_INDEX {
   tag "$pair_id"
   publishDir "${results_dir}/${pair_id}/sorted_bam", mode: 'copy'

   input:
   tuple val(pair_id), path(bam)
   val(results_dir)

   output:
   tuple val(pair_id), path("${pair_id}.aligned.sorted.bam"), emit: sorted_bam

   script:
   """
   samtools index ${bam}
   """
}

/*
 * Calculate the read coverage of positions in the genome.
 */
process BCFTOOLS_MPILEUP {
   tag "$pair_id"
   publishDir "${results_dir}/${pair_id}/raw_bcf", mode: 'copy'

   input:
   tuple val(pair_id), path(bam), path(genome)
   val(results_dir)

   output:
   tuple val(pair_id), path("${pair_id}_raw.bcf"), emit: raw_bcf

   script:
   """
   bcftools mpileup -O b -o ${pair_id}_raw.bcf -f ${genome} ${bam}
   """
}

/*
 * Detect the single nucleotide variants (SNVs).
 */
process BCFTOOLS_CALL {
   tag "$pair_id"
   publishDir "${results_dir}/${pair_id}/variants", mode: 'copy'

   input:
   tuple val(pair_id), path(raw_bcf)
   val(results_dir)
   
   output:
   tuple val(pair_id), path("${pair_id}_variants.vcf"), emit: variants

   script:
   """
   bcftools call --ploidy 1 -m -v -o ${pair_id}_variants.vcf ${raw_bcf}
   """
}

/*
 * Filter and report the SNVs in VCF (variant calling format).
 */
process VCFUTILS {
   tag "$pair_id"
   publishDir "${results_dir}/${pair_id}/final_variants", mode: 'copy'

   input:
   tuple val(pair_id), path(variants)
   val(results_dir)

   script:
   """
   vcfutils.pl varFilter ${variants} > ${pair_id}_final_variants.vcf 
   """
}

workflow {
  ref_ch = Channel.fromPath( params.annotations_fasta, checkIfExists: true )  
  read_pairs_ch = Channel.fromFilePairs(params.reads, checkIfExists: true)
  
  TRIMGALORE(read_pairs_ch, params.trim_length)
  FASTQC(TRIMGALORE.out.trimmed_read_pairs_ch, params.results_dir)
  BWA_INDEX(ref_ch, params.results_dir)
  BWA_ALIGN(BWA_INDEX.out.bwa_index.combine(TRIMGALORE.out.trimmed_read_pairs_ch), params.results_dir)
  SAMTOOLS_SORT(BWA_ALIGN.out.aligned_bam, params.results_dir)
  SAMTOOLS_INDEX(SAMTOOLS_SORT.out.sorted_bam, params.results_dir)
  BCFTOOLS_MPILEUP(SAMTOOLS_INDEX.out.sorted_bam.combine(ref_ch), params.results_dir)
  BCFTOOLS_CALL(BCFTOOLS_MPILEUP.out.raw_bcf, params.results_dir)
  VCFUTILS(BCFTOOLS_CALL.out.variants, params.results_dir)
}

/*
 * Completion Handler
 */
workflow.onComplete {
	log.info ( workflow.success ? "\nDone! Find read pair results here --> ${params.results_dir}\n" : "Oops .. something went wrong" )
}
