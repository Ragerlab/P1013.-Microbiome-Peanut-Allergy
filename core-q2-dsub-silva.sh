#!/bin/bash
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=36g
#SBATCH -t 48:00:00

. ~/Q2/q2.source

qiime tools import \
      --type 'SampleData[PairedEndSequencesWithQuality]' \
      --input-path $1  \
      --input-format CasavaOneEightSingleLanePerSampleDirFmt \
      --output-path demux-paired-end.qza

qiime demux summarize \
      --i-data demux-paired-end.qza \
      --o-visualization demux-paired-end.qzv

qiime cutadapt trim-paired \
      --i-demultiplexed-sequences demux-paired-end.qza \
      --p-cores 8 \
      --p-front-f $2 \
      --p-front-r $3 \
      --o-trimmed-sequences demux-paired-end-trimmed.qza

qiime demux summarize \
      --i-data demux-paired-end-trimmed.qza \
      --o-visualization demux-paired-end-trimmed.qzv

rm demux-paired-end.qza

qiime dada2 denoise-paired \
      --i-demultiplexed-seqs demux-paired-end-trimmed.qza \
      --p-trunc-len-f 220 \
      --p-trunc-len-r 220 \
      --p-n-threads 8 \
      --o-representative-sequences rep-seqs.qza \
      --o-table table.qza \
      --o-denoising-stats stats-dada2.qza

qiime metadata tabulate \
      --m-input-file stats-dada2.qza \
      --o-visualization stats-dada2.qzv

qiime feature-table summarize \
       --i-table table.qza \
      --o-visualization table.qzv \
      --m-sample-metadata-file $1.mapping.txt

qiime feature-table tabulate-seqs \
      --i-data rep-seqs.qza \
      --o-visualization rep-seqs.qzv

qiime alignment mafft \
      --i-sequences rep-seqs.qza \
      --p-n-threads 8 \
      --o-alignment aligned-rep-seqs.qza

qiime alignment mask \
      --i-alignment aligned-rep-seqs.qza \
      --o-masked-alignment masked-aligned-rep-seqs.qza

qiime phylogeny fasttree \
      --i-alignment masked-aligned-rep-seqs.qza \
      --p-n-threads 8 \
      --o-tree unrooted-tree.qza

qiime phylogeny midpoint-root \
      --i-tree unrooted-tree.qza \
      --o-rooted-tree rooted-tree.qza

qiime composition add-pseudocount \
      --i-table table.qza \
      --o-composition-table comp-table.qza

qiime diversity core-metrics-phylogenetic \
      --i-phylogeny rooted-tree.qza \
      --i-table table.qza \
      --p-n-jobs-or-threads 1 \
      --p-sampling-depth 5000 \
      --m-metadata-file $1.mapping.txt \
      --output-dir core-metrics

qiime diversity alpha-rarefaction \
      --i-table table.qza \
      --i-phylogeny rooted-tree.qza \
      --p-max-depth 5000 \
      --m-metadata-file $1.mapping.txt \
      --o-visualization alpha-rarefaction.qzv

qiime emperor plot \
      --i-pcoa core-metrics/weighted_unifrac_pcoa_results.qza \
      --m-metadata-file $1.mapping.txt \
      --o-visualization weighted-unifrac-emperor.qzv

qiime emperor plot \
      --i-pcoa core-metrics/bray_curtis_pcoa_results.qza \
      --m-metadata-file $1.mapping.txt \
      --o-visualization bray-curtis-emperor.qzv

qiime feature-classifier classify-sklearn \
      --i-classifier silva-138-99-515-806-nb-q2-2022.2.qza \
      --p-n-jobs 1 \
      --i-reads rep-seqs.qza \
      --o-classification taxonomy.qza

rm silva-138-99-515-806-nb-q2-2022.2.qza

qiime metadata tabulate \
      --m-input-file taxonomy.qza \
      --o-visualization taxonomy.qzv

qiime taxa collapse \
      --i-table table.qza \
      --i-taxonomy taxonomy.qza \
      --p-level 6 \
      --o-collapsed-table table-l6.qza

samples=`wc -l $1.mapping.txt | cut -f 1 -d' '`
qiime feature-table filter-features \
      --i-table table-l6.qza \
      --p-min-frequency 5000 \
      --p-min-samples $(( ($samples - 2)/5 )) \
      --o-filtered-table table-l6-filtered.qza

qiime composition add-pseudocount \
      --i-table table-l6-filtered.qza \
      --o-composition-table comp-table-l6.qza

qiime taxa collapse \
      --i-table table.qza \
      --i-taxonomy taxonomy.qza \
      --p-level 7 \
      --o-collapsed-table table-l7.qza

samples=`wc -l $1.mapping.txt | cut -f 1 -d' '`
qiime feature-table filter-features \
      --i-table table-l7.qza \
      --p-min-frequency 5000 \
      --p-min-samples $(( ($samples - 2)/5 )) \
      --o-filtered-table table-l7-filtered.qza

qiime composition add-pseudocount \
      --i-table table-l7-filtered.qza \
      --o-composition-table comp-table-l7.qza

qiime taxa barplot \
      --i-table table.qza \
      --i-taxonomy taxonomy.qza \
      --m-metadata-file $1.mapping.txt \
      --o-visualization taxa-bar-plots.qzv

qiime diversity alpha-group-significance \
      --i-alpha-diversity core-metrics/faith_pd_vector.qza \
      --m-metadata-file $1.mapping.txt \
      --o-visualization faith-pd-group-significance.qzv &

qiime diversity alpha-group-significance \
      --i-alpha-diversity core-metrics/evenness_vector.qza \
      --m-metadata-file $1.mapping.txt \
      --o-visualization evenness-group-significance.qzv &

wait

j=0
for i in $@
do
    j=$((j+1))
    if [ $j -gt 3 ]
    then
	qiime diversity beta-group-significance \
	      --i-distance-matrix core-metrics/unweighted_unifrac_distance_matrix.qza \
	      --m-metadata-file $1.mapping.txt \
	      --m-metadata-column $i \
	      --o-visualization unweighted-unifrac-$i-significance.qzv \
     	      --p-pairwise &

	qiime diversity beta-group-significance \
	      --i-distance-matrix core-metrics/weighted_unifrac_distance_matrix.qza \
	      --m-metadata-file $1.mapping.txt \
	      --m-metadata-column $i \
	      --o-visualization weighted-unifrac-$i-significance.qzv \
	      --p-pairwise &

	qiime diversity beta-group-significance \
	      --i-distance-matrix core-metrics/bray_curtis_distance_matrix.qza \
	      --m-metadata-file $1.mapping.txt \
	      --m-metadata-column $i \
	      --o-visualization bray-curtis-$i-significance.qzv \
	      --p-pairwise &

	wait

	qiime composition ancom \
	      --i-table comp-table-l6.qza \
	      --m-metadata-file $1.mapping.txt \
	      --m-metadata-column $i \
	      --o-visualization l6-ancom-$i.qzv &

	qiime composition ancom \
	      --i-table comp-table-l7.qza \
	      --m-metadata-file $1.mapping.txt \
	      --m-metadata-column $i \
	      --o-visualization l7-ancom-$i.qzv &

	wait
    fi
done

mkdir $1-q2-silva
mkdir $1-q2-silva/QZA
mkdir $1-q2-silva/QZV

mkdir $1-q2-silva/QZA/alpha
mkdir $1-q2-silva/QZA/base
mkdir $1-q2-silva/QZA/beta
mkdir $1-q2-silva/QZA/taxa

mkdir $1-q2-silva/QZV/alpha
mkdir $1-q2-silva/QZV/base
mkdir $1-q2-silva/QZV/beta
mkdir $1-q2-silva/QZV/taxa
mkdir $1-q2-silva/QZV/diffab

mv core-metrics/*.qza .
mv core-metrics/*.qzv .

rm demux-paired-end-trimmed.qza

mv evenness_vector.qza faith_pd_vector.qza observed_features_vector.qza shannon_vector.qza $1-q2-silva/QZA/alpha
mv bray_curtis_*.qza jaccard_*.qza unweighted_unifrac_*.qza weighted_unifrac_*.qza $1-q2-silva/QZA/beta
mv taxonomy.qza $1-q2-silva/QZA/taxa
mv *.qza $1-q2-silva/QZA/base

mv alpha-rarefaction.qzv evenness-group-significance.qzv faith-pd-group-significance.qzv $1-q2-silva/QZV/alpha
mv bray*.qzv jaccard*.qzv unweighted*.qzv weighted*.qzv $1-q2-silva/QZV/beta
mv taxa-bar-plots.qzv taxonomy.qzv $1-q2-silva/QZV/taxa
mv l6-ancom-*.qzv l7-ancom-*.qzv $1-q2-silva/QZV/diffab
mv *.qzv $1-q2-silva/QZV/base

cp $1.mapping.txt $1-q2-silva

cp $1.out $1-q2-silva

python -m zipfile -c $1-q2-silva.zip $1-q2-silva/

