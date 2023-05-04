FROM continuumio/miniconda3:4.7.12

RUN mkdir -p /usr/share/man/man1
RUN apt-get --allow-releaseinfo-change-suite update \
    && apt-get install -y \
    procps \
    cutadapt \
    fastqc \
    rsem \
    bwa \
    samtools \
    bcftools
    

RUN wget https://github.com/alexdobin/STAR/archive/2.7.0c.tar.gz
RUN tar -xzf 2.7.0c.tar.gz
ENV PATH="/STAR-2.7.0c/bin/Linux_x86_64_static:$PATH"
RUN STAR --version
RUN wget http://archive.ubuntu.com/ubuntu/pool/universe/t/trim-galore/trim-galore_0.6.5-1_all.deb
RUN apt-get install -f -y ./trim-galore_0.6.5-1_all.deb

RUN pip install multiqc==1.12 \
                pyarrow==7.0.0 \
                google-cloud-bigquery==2.34.2 \
                pandas==1.3.5 \
                numpy==1.21.5 \
                pytz==2021.3
