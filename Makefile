include defs.mk
# this makefile assumes that you have the kent source directory in your path
# see defs.mk for the necessary inclusion of a config.mk from comparativeAnnotator
sharedCheckpointDir = ./checkpoints/sharedDatabase
sharedDatabaseCreateCheckpoint = ${sharedCheckpointDir}/sharedDatabaseCreate

transMapGencodeSrcLoadCheckpoints = \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.seq} \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.src} \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.gene}

all: shared genomes

shared: ${halPath} loadSharedSql
genomes: ${genomes:%=%.loadGenome} refGencodeTracks

${halPath}:
	@mkdir -p $(dir $@)
	ln -sf ${HAL} $@

%.loadGenome:
	${MAKE} -f loadGenome.mk GENOME=$* all

loadSharedSql: ${sharedDatabaseCreateCheckpoint} transmapGencodeShared

${sharedDatabaseCreateCheckpoint}:
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${sharedDb};"
	touch $@

##
## transmap shared source tabkes tables.
transmapGencodeShared: ${transMapGencodeSrcLoadCheckpoints}

${sharedCheckpointDir}/transMap%.seq: ${GBDB_SHARED_DIR}/transMap%.fa
	@mkdir -p $(dir $@)
	hgLoadSeq -drop -seqTbl=transMapSeq$*${TRANS_MAP_TABLE_VERSION} -extFileTbl=transMapExtFile$*${TRANS_MAP_TABLE_VERSION} ${sharedDb} $<
	rm -f transMapSeq$*${TRANS_MAP_TABLE_VERSION}.tab
	touch $@
${GBDB_SHARED_DIR}/transMap%.fa: ${TRANS_MAP_DIR}/data/wgEncode%.fa
	@mkdir -p $(dir $@)
	bin/editTransMapSrcFasta  ${refGenomeDb} $<  $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${sharedCheckpointDir}/transMap%.src: ${TRANS_MAP_DIR}/data/wgEncode%.psl
	@mkdir -p $(dir $@)
	bin/loadTransMapSrc ${refGenomeDb} ${sharedDb} $< transMapSrc$*${TRANS_MAP_TABLE_VERSION}  ${HOME}/kent/src/hg/lib/transMapSrc.sql
	rm -f transMapSrc$*.tab
	touch $@
${sharedCheckpointDir}/transMap%.gene: ${TRANS_MAP_DIR}/data/wgEncode%.cds \
					${TRANS_MAP_DIR}/data/wgEncode%.psl \
					${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv
	@mkdir -p $(dir $@)
	bin/loadTransMapGene ${refGenomeDb} ${sharedDb} ${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv  ${TRANS_MAP_DIR}/data/wgEncode$*.cds  ${TRANS_MAP_DIR}/data/wgEncode$*.psl transMapGene$*${TRANS_MAP_TABLE_VERSION}  ${HOME}/kent/src/hg/lib/transMapGene.sql
	touch $@

###
# copy gencode tracks that contain chromosome names to our copy of the
# reference genome (C57B6J) and edit. Don't bother with
# wgEncodeGencodeExonSupport, as it's not currently used by the browser and is
# huge.

refGenomeCheckpointDir = checkpoints/database/${refGenome}
gencodeGenepredTables = wgEncodeGencodeBasic${GENCODE_VERSION} \
	wgEncodeGencodeComp${GENCODE_VERSION} \
	wgEncodeGencodePseudoGene${GENCODE_VERSION} \
	wgEncodeGencode2wayConsPseudo${GENCODE_VERSION} \
	wgEncodeGencodePolya${GENCODE_VERSION}
gencodeExonSupportTable = wgEncodeGencodeExonSupport${GENCODE_VERSION}
gencodeTabTables = wgEncodeGencodeAnnotationRemark${GENCODE_VERSION} \
	wgEncodeGencodeAttrs${GENCODE_VERSION} \
	wgEncodeGencodeGeneSource${GENCODE_VERSION} \
	wgEncodeGencodePdb${GENCODE_VERSION} \
	wgEncodeGencodePubMed${GENCODE_VERSION} \
	wgEncodeGencodeRefSeq${GENCODE_VERSION} \
	wgEncodeGencodeTag${GENCODE_VERSION} \
	wgEncodeGencodeTranscriptSource${GENCODE_VERSION} \
	wgEncodeGencodeTranscriptSupport${GENCODE_VERSION} \
	wgEncodeGencodeTranscriptionSupportLevel${GENCODE_VERSION} \
	wgEncodeGencodeUniProt${GENCODE_VERSION}

refGenomeCheckpoints = \
	${gencodeGenepredTables:%=${refGenomeCheckpointDir}/%.gp} \
	${gencodeExonSupportTable:%=${refGenomeCheckpointDir}/%.exonsup} \
	${gencodeTabTables:%=${refGenomeCheckpointDir}/%.tab}

refGencodeTracks: ${refGenomeCheckpoints}

${refGenomeCheckpointDir}/%.gp:
	@mkdir -p $(dir $@)
	bin/cloneEditPositionalTable 3 ${refGenomeSrcDb} ${refGenomeDb} $*
	touch $@

${refGenomeCheckpointDir}/%.exonsup:
	@mkdir -p $(dir $@)
	bin/cloneEditPositionalTable 5 ${refGenomeSrcDb} ${refGenomeDb} $*
	touch $@

${refGenomeCheckpointDir}/%.tab:
	@mkdir -p $(dir $@)
	hgsql -e 'drop table if exists $*' ${refGenomeDb}
	hgsql -e 'create table $* LIKE ${refGenomeSrcDb}.$*' ${refGenomeDb}
	hgsql -e 'insert $* select * from ${refGenomeSrcDb}.$*' ${refGenomeDb}
	touch $@
