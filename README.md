# RNASeq Nextflow Demo on Google Cloud

A proof-of-concept paired-end RNA-Seq pipeline managed by [Nextflow](https://nextflow.io/) using the Google Cloud [Life Sciences API](https://cloud.google.com/life-sciences/docs/reference/rest). 

The steps of the pipeline are:
1. Adapter and quality trimming with [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/)
2. Quality control readout with [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
3. Estimation of gene and isoform expression with [RSEM](https://github.com/deweylab/RSEM)
4. Write of gene and isoform expression data to [BigQuery](https://cloud.google.com/bigquery).
