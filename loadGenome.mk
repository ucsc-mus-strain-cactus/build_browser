include defs.mk
#########################################################################################
# Creates databases and loads tracks for one specific genome. called by Makefile.
#########################################################################################
DB = Mus${GENOME}_${MSCA_VERSION}
genomesDbs = ${genomes:%=Mus%_${MSCA_VERSION}}
GBDB_DIR = ${BASE_DATA_DIR}/gbdb/${GENOME}/${DB}
BED_DIR = ${BASE_DATA_DIR}/genomes/${DB}/bed
CHROM_INFO_DIR = ${BED_DIR}/chromInfo
twoBit = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.2bit
agp = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.agp

# some basic tracks we will need to build
assemblyTrack = ${BED_DIR}/assemblyTrack/${DB}.bed
gapTrack = ${BED_DIR}/gapTrack/${DB}.bed
gcPercentTrack = ${BED_DIR}/gcPercent/${DB}.bed
repeatMaskerOut = ${BASE_DATA_DIR}/genomes/${DB}/${DB}/fa.out



# placeholder DONE files - used to checkpoint sql loading commands
checkpointDir = ./checkpoints/database/${DB}
databaseCheckpoint = ${checkpointDir}/init
transMapGencodeLoadCheckpoints = ${transMapGencodeSubsets:%=${checkpointDir}/%.aln} \
	${transMapGencodeSubsets:%=${checkpointDir}/%.info}
loadTracksCheckpoint = ${checkpointDir}/loadTracks

# the variables below dig through comparativeAnnotator output
comparisons = $(shell /bin/ls ${ANNOTATION_DIR}/bedfiles/)
comparisonBeds = ${comparisons:%=${BED_DIR}/%/${GENOME}.bed}
comparisonCheckpoints = ${comparisons:%=${checkpointDir}/%}


all: trackDb genomeFiles prepareTracks loadTransMap basicBrowserTracks loadBeds loadTracks


trackDb: ./trackDb/${GENOME}/trackDb.ra ./trackDb/${GENOME}/${DB}/trackDb.ra

./trackDb/${GENOME}/trackDb.ra:
	@mkdir -p $(dir $@)
	touch $@

# also depend on included files
./trackDb/${GENOME}/${DB}/trackDb.ra: bin/buildSnakeTrackDb.py $(wildcard ./trackDb/${GENOME}/${DB}/*.trackDb.ra)
	@mkdir -p $(dir $@)
	python bin/buildSnakeTrackDb.py --genomes ${genomesDbs} --this_genome ${DB} --hal ${halFile} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

genomeFiles: ${twoBit} ${agp} ${GBDB_DIR}/${DB}.2bit ${repeatMasker}

${twoBit}: ${GENOMES_DIR}/${GENOME}.2bit
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

${BED_DIR}/%/${DB}.bed: ${ANNOTATION_DIR}/bedfiles/%/${GENOME}/${GENOME}.bed
	@mkdir -p $(dir $@)
	cp -u $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# use lock, as hgGoldGapGl uses static file name
${databaseCheckpoint}: ${agp} ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@) locks
	hgsql -e "CREATE DATABASE IF NOT EXISTS ${DB};"
	flock locks/hgGoldGap.lock hgGoldGapGl -noGl ${DB} ${agp}
	hgLoadSqlTab ${DB} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	touch $@

##
# gencode mapped tracks, except on reference
##
ifeq (${GENOME},${refGenome})
loadTransMap:
else
loadTransMap: ${transMapGencodeLoadCheckpoints}
endif

${checkpointDir}/transMap%.aln: ${transMapDataDir}/transMap%.psl ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapAln ${refGenomeDb} ${DB} transMapAln$*${TRANS_MAP_TABLE_VERSION} $<
	touch $@

${checkpointDir}/transMap%.info: ${transMapDataDir}/transMap%.psl ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapInfo ${refGenomeDb} ${DB} $< transMapInfo$*${TRANS_MAP_TABLE_VERSION} ${HOME}/kent/src/hg/lib/transMapInfo.sql
	touch $@


##
# standard browser tracks
##
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
	cd ${BED_DIR}/gcPercent/ && hgGcPercent -win=10000 -verbose=0 -doGaps ${DB} ${twoBit}
	mv -f ${BED_DIR}/gcPercent/gcPercent.bed $@


loadBeds: ${comparisonCheckpoints}

${checkpointDir}/%: ${ANNOTATION_DIR}/bedfiles/%/${GENOME}/${GENOME}.bed ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	@mkdir -p $${TMPDIR}/${DB}
	hgLoadBed -tmpDir=$${TMPDIR}/${DB} -allowStartEqualEnd -tab -type=bed12 ${DB} $* $<
	touch $@


loadTracks: ${loadTracksCheckpoint}

${loadTracksCheckpoint}:  $(wildcard ./trackDb/*trackDb.ra) $(wildcard ./trackDb/${GENOME}/*trackDb.ra) $(wildcard ./trackDb/${GENOME}/${DB}/*trackDb.ra)
	cd ./trackDb && ${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks -grpSql=./grp.sql -sqlDir=${KENT_DIR}/src/hg/lib trackDb hgFindSpec ${DB}
	rm trackDb/trackDb.tab trackDb/hgFindSpec.tab
	touch $@
