# End-to-end RNA-Seq and Protein Folding on Google Cloud

![Successful pipeline execution graph](/images/workflow.png)

## Summary
We have developed an end-to-end pipeline for RNA-Seq and protein structure prediction that utilizes BigQuery and Vertex AI to efficiently handle and process terabyte-scale data. We hope to provide insights into how Google Cloud can be used to tackle computational challenges in modern biology and medicine, ultimately paving the way for new discoveries and innovations.

## Data
FASTQ files are sourced from a public NCBI dataset [GSE181830](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE181830).

### Workflow 
The steps of the RNA-Seq pipeline are:
1. Adapter and quality trimming with [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/)
2. Quality control readout with [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
3. Estimation of gene and isoform expression with [RSEM](https://github.com/deweylab/RSEM)
4. Write of gene and isoform expression data to [BigQuery](https://cloud.google.com/bigquery).
