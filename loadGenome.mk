include defs.mk
#########################################################################################
# Creates databases and loads tracks for one specific genome. called by Makefile.
#########################################################################################
DB = Mus${GENOME}_${MSCA_VERSION}
GBDB_DIR = ${BASE_DATA_DIR}/gbdb/${GENOME}/${DB}
BED_DIR = ${BASE_DATA_DIR}/genomes/${DB}/bed
CHROM_INFO_DIR = ${BED_DIR}/chromInfo
twoBit = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.2bit
fasta = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.fa
chromSizes = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.chrom.sizes
agp = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.agp

# some basic tracks we will need to build
assemblyTrack = ${BED_DIR}/assemblyTrack/${DB}.bed
gapTrack = ${BED_DIR}/gapTrack/${DB}.bed
gcPercentTrack = ${BED_DIR}/gcPercent/${DB}.bed

# placeholder DONE files - used to checkpoint sql loading commands
databaseCheckpoint = ./checkpoints/database/${DB}/init
referencePslCheckpoint = ./checkpoints/database/${DB}/referencePsl
trackDbCheckpoint = ./checkpoints/database/${DB}/trackDb
hgFindSpecCheckpoint = ./checkpoints/database/${DB}/hgFindSpec

# the variables below dig through comparativeAnnotator output
comparisons = $(shell /bin/ls ${ANNOTATION_DIR}/bedfiles/)
comparisonBeds = ${comparisons:%=${BED_DIR}/%/${GENOME}.bed}
comparisonCheckpoints = ${comparisons:%=./checkpoints/database/${DB}/%}


all: trackDb genomeFiles prepareTracks loadSql basicBrowserTracks loadBeds

trackDb: ./trackDb/${GENOME}/trackDb.ra ./trackDb/${GENOME}/${DB}/trackDb.ra

./trackDb/${GENOME}/trackDb.ra:
	@mkdir -p $(dir $@)
	touch $@

./trackDb/${GENOME}/${DB}/trackDb.ra:
	@mkdir -p $(dir $@)
	touch $@

genomeFiles: ${twoBit} ${fasta} ${chromSizes} ${agp} ${GBDB_DIR}/${DB}.2bit

${twoBit}: ${GENOMES_DIR}/${GENOME}.2bit
	@mkdir -p $(dir $@)
	cp -u $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${fasta}: ${GENOMES_DIR}/${GENOME}.fa
	@mkdir -p $(dir $@)
	cp -u $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${chromSizes}: ${GENOMES_DIR}/${GENOME}.chrom.sizes
	@mkdir -p $(dir $@)
	cp -u $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${agp}: ${GENOMES_DIR}/${GENOME}.fa
	@mkdir -p $(dir $@)
	hgFakeAgp $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${GBDB_DIR}/${DB}.2bit: ${twoBit}
	@mkdir -p $(dir $@)
	ln -sf ${twoBit} $@

prepareTracks: ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab ${comparisonBeds}

${CHROM_INFO_DIR}/chromInfo.tab: ${chromSizes}
	@mkdir -p $(dir $@)
	awk '{print $$1 "\t" $$2 "\t'${GBDB_DIR}'/'${DB}'.2bit";}' ${chromSizes} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${CHROM_INFO_DIR}/chromInfo.sql: ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@)
	cut -f1 ${CHROM_INFO_DIR}/chromInfo.tab | awk '{print length($0)}'  | sort -nr > ${CHROM_INFO_DIR}/t.chrSize
	chrSize=`head -1 ${CHROM_INFO_DIR}/t.chrSize`; \
	sed -e "s/chrom(16)/chrom($$chrSize)/" ${HOME}/kent/src/hg/lib/chromInfo.sql > $@.${tmpExt}
	rm ${CHROM_INFO_DIR}/t.chrSize
	mv -f $@.${tmpExt} $@

${BED_DIR}/%/${GENOME}.bed: ${ANNOTATION_DIR}/bedfiles/%/${GENOME}/${GENOME}.bed
	@mkdir -p $(dir $@)
	cp -u $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

loadSql: ${databaseCheckpoint} ${referencePslCheckpoint}

${databaseCheckpoint}: ${agp} ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@)
	hgsql -e "CREATE DATABASE IF NOT EXISTS ${DB};"
	hgGoldGapGl -noGl ${DB} ${agp}
	hgsql ${DB} < ${KENT_DIR}/src/hg/lib/grp.sql
	hgLoadSqlTab ${DB} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	cd ./trackDb && ${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks -sqlDir=${KENT_DIR}/src/hg/lib \
	trackDb hgFindSpec ${DB} && rm trackDb.tab hgFindSpec.tab
	touch $@

${referencePslCheckpoint}: ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	hgLoadPsl -table=${tableBase} ${DB} ${TRANS_MAP_DIR}/results/filtered/${GENOME}.filtered.psl
	touch $@


basicBrowserTracks: ${assemblyTrack} ${gapTrack} ${gcPercentTrack}

${assemblyTrack}: ${agp}
	@mkdir -p $(dir $@)
	grep -v "^\#" ${agp} | awk '$$5 != "N"' | awk '{printf "%s\t%d\t%d\t%s\t0\t%s\n", $$1, $$2, $$3, $$6, $$9}' | sort -k1,1 -k2,2n > $@.${tmpExt}
	hgLoadBed -tmpDir=$${TMPDIR}/${DB} -allowStartEqualEnd -type=bed3+ ${DB} assembly $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${gapTrack}: ${agp}
	@mkdir -p $(dir $@)
	grep -v "^\#" ${agp} | awk '$$5 == "N"' | awk '{printf "%s\t%d\t%d\t%s\n", $$1, $$2, $$3, $$8}' | sort -k1,1 -k2,2n > $@.${tmpExt}
	hgLoadBed -tmpDir=$${TMPDIR}/${DB} -allowStartEqualEnd -type=bed3+ ${DB} gap $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${gcPercentTrack}: ${twoBit}
	@mkdir -p $(dir $@)
	cd ${BED_DIR}/gcPercent/ && hgGcPercent -win=500 -verbose=0 -doGaps ${DB} ${twoBit}
	mv -f ${BED_DIR}/gcPercent/gcPercent.bed $@


loadBeds: ${comparisonCheckpoints} ${trackDbCheckpoint} ${hgFindSpecCheckpoint}

./checkpoints/database/${DB}/%: ${ANNOTATION_DIR}/bedfiles/%/${GENOME}/${GENOME}.bed ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	@mkdir -p $${TMPDIR}/${DB}
	hgLoadBed -tmpDir=$${TMPDIR}/${DB} -allowStartEqualEnd -tab -type=bed12 ${DB} $* $<
	touch $@

${trackDbCheckpoint}: ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	cd ./trackDb && hgTrackDb . ${DB} trackDb ${KENT_DIR}/src/hg/lib/trackDb.sql .
	touch $@

${hgFindSpecCheckpoint}: ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	cd ./trackDb && hgFindSpec . ${DB} trackDb ${KENT_DIR}/src/hg/lib/hgFindSpec.sql .
	touch $@