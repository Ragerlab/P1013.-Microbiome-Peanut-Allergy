#!/bin/bash
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem=96g
#SBATCH -t 24:00:00

OMP_NUM_THREADS=32

# ADD KRAKEN DB HERE
#KRAKEN_DB=
#BRACKEN_DB=$KRAKEN_DB/database250mers.kmer_distrib

module add kraken/2.1.6
mkdir -p KREPORTs
mkdir -p BRACKEN
conda activate kraken
echo Kraken2 - Bracken Begin
kraken2 \
    --paired \
    --gzip-compressed \
    --threads 32 \
    --db $KRAKEN_DB \
    --output $1.kraken.out \
    --report KREPORTs/$1.kreport \
    $1_R1.fastq.gz \
    $1_R2.fastq.gz
echo Kraken2 Complete

est_abundance.py \
    -i KREPORTs/$1.kreport \
    -k $BRACKEN_DB \
    -o BRACKEN/$1.bracken.out
echo Kraken2 - Bracken Complete
conda deactivate
module rm kraken/2.1.6

mkdir -p NON-HOST/FASTQs
zcat $1_R1.fastq.gz | awk -f remove-host.awk $1.kraken.out - \
    > NON-HOST/FASTQs/$1_R1_001.fastq
zcat $1_R2.fastq.gz | awk -f remove-host.awk $1.kraken.out - \
    > NON-HOST/FASTQs/$1_R2_001.fastq

gzip -9 NON-HOST/FASTQs/$1_R?_001.fastq

rm $1.kraken.out
rm KREPORTs/$1_bracken_species.kreport
