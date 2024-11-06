# Use Miniconda3 as base image for Python environment management
FROM continuumio/miniconda3:4.7.12

# Create directory for man pages (required for some package installations)
RUN mkdir -p /usr/share/man/man1

# Install system-level bioinformatics tools
# --allow-releaseinfo-change-suite handles potential repository changes
# procps: System and process monitoring utilities
# cutadapt: Removes adapter sequences from high-throughput sequencing reads
# fastqc: Quality control tool for high throughput sequence data
# rsem: RNA-Seq by Expectation Maximization (for gene expression quantification)
# bwa: Burrows-Wheeler Aligner for mapping sequences against a reference genome
# samtools: Suite of programs for manipulating SAM/BAM/CRAM format files
# bcftools: Tools for variant calling and manipulating VCF/BCF files
RUN apt-get --allow-releaseinfo-change-suite update \
    && apt-get install -y \
    procps \
    cutadapt \
    fastqc \
    rsem \
    bwa \
    samtools \
    bcftools

# Install STAR aligner version 2.7.0c
# STAR (Spliced Transcripts Alignment to a Reference) is used for RNA-seq alignment
RUN wget https://github.com/alexdobin/STAR/archive/2.7.0c.tar.gz
RUN tar -xzf 2.7.0c.tar.gz
# Add STAR to system PATH
ENV PATH="/STAR-2.7.0c/bin/Linux_x86_64_static:$PATH"
# Verify STAR installation
RUN STAR --version

# Install Trim Galore
# Trim Galore is a wrapper around Cutadapt and FastQC for quality control
RUN wget http://archive.ubuntu.com/ubuntu/pool/universe/t/trim-galore/trim-galore_0.6.5-1_all.deb
RUN apt-get install -f -y ./trim-galore_0.6.5-1_all.deb

# Install Python packages
# multiqc: Aggregates bioinformatics analyses into a single report
# pyarrow: Provides columnar data processing capabilities
# google-cloud-bigquery: Google BigQuery client library
# pandas: Data manipulation and analysis library
# numpy: Numerical computing library
# pytz: Timezone handling library
RUN pip install multiqc==1.12 \
                pyarrow==7.0.0 \
                google-cloud-bigquery==2.34.2 \
                pandas==1.3.5 \
                numpy==1.21.5 \
                pytz==2021.3
