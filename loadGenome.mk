include defs.mk
#########################################################################################
# Creates databases and loads tracks for one specific genome. called by Makefile.
#########################################################################################
DB = ${GENOME}_${MSCA_VERSION}
GBDB_DIR = ${BASE_DATA_DIR}/gbdb/${GENOME}/${DB}
CHROM_INFO_DIR = ${BASE_DATA_DIR}/genomes/${DB}/bed/chromInfo
twoBit = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.2bit
gbdbTwoBit = ${GBDB}
fasta = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.fa
chromSizes = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.chrom.sizes
agp = ${BASE_DATA_DIR}/genomes/${DB}/${DB}.agp
# placeholder DONE files - used to checkpoint sql loading commands
databaseCheckpoint = ./checkpoints/database/${DB}/INIT
referencePslCheckpoint = ./checkpoints/database/${DB}/REFERENCE_PSL

all: trackDb genomeFiles prepareTracks loadSql

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
	cp $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${fasta}: ${GENOMES_DIR}/${GENOME}.fa
	@mkdir -p $(dir $@)
	cp $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${chromSizes}: ${GENOMES_DIR}/${GENOME}.chrom.sizes
	@mkdir -p $(dir $@)
	cp $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${agp}: ${GENOMES_DIR}/${GENOME}.fa
	@mkdir -p $(dir $@)
	hgFakeAgp $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${GBDB_DIR}/${DB}.2bit:
	@mkdir -p $(dir $@)
	ln -s ${twoBit} ${GBDB_DIR}/${DB}.2bit

prepareTracks: ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab

${CHROM_INFO_DIR}/chromInfo.tab: ${chromSizes}
	@mkdir -p $(dir $@)
	awk '{print $$1 "\t" $$2 "\t'${GBDB_DIR}'/'${DB}'.2bit";}' ${chromSizes} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${CHROM_INFO_DIR}/chromInfo.sql: ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@)
	cut -f1 ${CHROM_INFO_DIR}/chromInfo.tab | awk '{print length($0)}'  | sort -nr > ${CHROM_INFO_DIR}/t.chrSize
	chrSize=`head -1 ${CHROM_INFO_DIR}/t.chrSize`; \
	sed -e "s/chrom(16)/chrom($$chrSize)/" ${HOME}/kent/src/hg/lib/chromInfo.sql > $@.${tmpExt}
	mv -f $@.${tmpExt} $@


loadSql: ${databaseCheckpoint} ${referencePslCheckpoint}

${databaseCheckpoint}: ${agp} ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${DB};"
	hgGoldGapGl -noGl ${DB} ${agp}
	hgLoadSqlTab ${DB} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	cd ./trackDb && ${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks -grpSql=${KENT_DIR}/src/hg/lib/grp.sql \
	-sqlDir=${KENT_DIR}/src/hg/lib trackDb hgFindSpec ${DB} && rm trackDb.tab hgFindSpec.tab
	touch $@

${referencePslCheckpoint}: ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	hgLoadPsl -table=${tableBase} ${DB} ${TRANS_MAP_DIR}/results/filtered/${GENOME}.filtered.psl
	touch $@