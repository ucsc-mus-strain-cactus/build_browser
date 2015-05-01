# this should be the config file from comparativeAnnotator
include config_1411.mk
# this makefile assumes that you have the kent source directory in your path
# export PATH = /cluster/bin/x86_64/:${PATH}

NUM_JOBS = 5
# what type of chaining was preformed? TODO: should be in comparativeAnnotator
CHAINING = simpleChain


#########################################################################################
# STATIC VARIABLES - shared databases, kent subdirectories, etc
#########################################################################################
# directories
export BASE_DATA_DIR = ${MSCA_PROJ_DIR}/browser
# hard coding Ian's kent dir
export KENT_DIR = /cluster/home/ifiddes/kent
export GBDB_SHARED_DIR = ${BASE_DATA_DIR}/gbdb/${sharedDb}
# static variables, script paths
export sciName = "Mus musculus"
export sharedDb = musStrainShared
# variables from config.mk that must be sent to children
export ${MSCA_VERSION}
export ${GENOMES_DIR}
export ${TRANS_MAP_DIR}
# shared table names
export tableBase = gencode${MSCA_VERSION}${CHAINING}
# these variables are only used in the parent call
# placeholder DONE files - used to checkpoint sql loading commands
sharedDatabaseCheckpoint = ./checkpoints/sharedDatabase/INIT
sourceTranscriptCheckpoint = ./checkpoints/sharedDatabase/TRANSCRIPT
gbdbTranscriptFasta = ${GBDB_SHARED_DIR}/$(notdir ${srcCombinedFasta})


#########################################################################################
# DYNAMIC VARIABLES - set for each recursive call (each genome)
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

#########################################################################################
# MAIN LOGIC - all is the outer loop - external call. also runs shared targets
#########################################################################################
all: ${genomes} trackDbFiles transcriptFasta loadSharedSql

${genomes}: 
	make -j ${NUM_JOBS} GENOME=$@ genomeFiles prepareTracks loadSql

trackDbFiles: ./trackDb/trackDb.ra ./trackDb/tagTypes.tab

./trackDb/trackDb.ra:
	touch $@

./trackDb/tagTypes.tab:
	cp ${KENT_DIR}/src/hg/makeDb/trackDb/tagTypes.tab $@

loadSharedSql: ${sharedDatabaseCheckpoint} ${sourceTranscriptCheckpoint}

${sharedDatabaseCheckpoint}:
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${sharedDb};"
	touch $@

${sourceTranscriptCheckpoint}: ${gbdbTranscriptFasta}
	@mkdir -p $(dir $@)
	# WARNING: semi hard coded table name here
	hgLoadSeq -seqTbl=${tableBase}Seq -extFileTbl=${tableBase}ExtFile ${sharedDb} ${gbdbTranscriptFasta}
	hgLoadSqlTab ${sharedDb} ${tableBase}Cds ${KENT_DIR}/src/hg/lib/cdsSpec.sql ${srcCombinedCds}
	touch $@

transcriptFasta: ${gbdbTranscriptFasta}

${gbdbTranscriptFasta}:
	@mkdir -p $(dir $@)
	cp -n ${srcCombinedFasta} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

#########################################################################################
# RECURSIVE LOGIC - these targets are called for each genome
#########################################################################################

genomeFiles: ${twoBit} ${fasta} ${chromSizes} ${agp}

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

prepareTracks: ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab

${CHROM_INFO_DIR}/chromInfo.sql: ${GENOMES_DIR}/${GENOME}.chrom.sizes
	@mkdir -p ${CHROM_INFO_DIR}
	awk '{print $1 "\t" $2 "\t'${GBDB_DIR}'/'${DB}'.2bit";}' ${GENOMES_DIR}/${GENOME}.chrom.sizes > ${CHROM_INFO_DIR}/chromInfo.tab

${CHROM_INFO_DIR}/chromInfo.tab: ${CHROM_INFO_DIR}/chromInfo.sql
	cut -f1 ${CHROM_INFO_DIR}/chromInfo.tab | awk '{print length($0)}'  | sort -nr > ${CHROM_INFO_DIR}/t.chrSize
	chrSize=`head -1 ${CHROM_INFO_DIR}/t.chrSize`; sed -e "s/chrom(16)/chrom($$chrSize)/" ${KENT_DIR}/src/hg/lib/chromInfo.sql > ${CHROM_INFO_DIR}/chromInfo.sql

loadSql: ${databaseCheckpoint} ${referencePslCheckpoint}

${databaseCheckpoint}: ${agp} ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${DB};"
	hgGoldGapGl -noGl ${DB} ${agp}
	hgLoadSqlTab ${DB} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	hgsql ${DB} < ${KENT_DIR}/src/hg/lib/grp.sql
	cd ./trackDb && ${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks -grpSql ${KENT_DIR}/src/hg/lib/grp.sql -sqlDir ${KENT_DIR}/src/hg/lib trackDb hgFindSpec ${DB}
	touch $@

${referencePslCheckpoint}: ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	hgLoadPsl -table=${tableBase} ${DB} ${TRANS_MAP_DIR}/results/filtered/${GENOME}.filtered.psl
	touch $@