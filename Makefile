include defs.mk
# this makefile assumes that you have the kent source directory in your path
# see defs.mk for the necessary inclusion of a config.mk from comparativeAnnotator

sharedCheckpointDir = ${CHECKPOINT_DIR}/${sharedDb}
sharedDatabaseCreateCheckpoint = ${sharedCheckpointDir}/sharedDatabaseCreate.done

transMapGencodeSrcLoadCheckpoints = \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.seq.done} \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.src.done} \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.gene.done}

all: shared genomes

shared: ${halBrowserHtDocsFile} loadSharedSql
genomes: ${genomes:%=%.loadGenome} refGencodeTracks

${halBrowserHtDocsFile}: ${halBrowserFile}
	@mkdir -p $(dir $@)
	cp -f $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

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

${sharedCheckpointDir}/transMap%.seq.done: ${GBDB_SHARED_DIR}/transMap%.fa
	@mkdir -p $(dir $@)
	hgLoadSeq -drop -seqTbl=transMapSeq$*${TRANS_MAP_TABLE_VERSION} -extFileTbl=transMapExtFile$*${TRANS_MAP_TABLE_VERSION} ${sharedDb} $<
	rm -f transMapSeq$*${TRANS_MAP_TABLE_VERSION}.tab
	touch $@
${GBDB_SHARED_DIR}/transMap%.fa: ${TRANS_MAP_DIR}/data/wgEncode%.fa
	@mkdir -p $(dir $@)
	bin/editTransMapSrcFasta  ${srcOrgDb} $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${sharedCheckpointDir}/transMap%.src.done: ${TRANS_MAP_DIR}/data/wgEncode%.psl
	@mkdir -p $(dir $@)
	bin/loadTransMapSrc ${srcOrgDb} ${sharedDb} $< transMapSrc$*${TRANS_MAP_TABLE_VERSION}  ${KENT_HG_LIB_DIR}/transMapSrc.sql
	rm -f transMapSrc$*.tab
	touch $@
${sharedCheckpointDir}/transMap%.gene.done: ${TRANS_MAP_DIR}/data/wgEncode%.cds \
					${TRANS_MAP_DIR}/data/wgEncode%.psl \
					${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv
	@mkdir -p $(dir $@)
	bin/loadTransMapGene ${srcOrgDb} ${sharedDb} ${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv  ${TRANS_MAP_DIR}/data/wgEncode$*.cds  ${TRANS_MAP_DIR}/data/wgEncode$*.psl transMapGene$*${TRANS_MAP_TABLE_VERSION}  ${KENT_HG_LIB_DIR}/transMapGene.sql
	touch $@

# error about pipeline not being run
define pipelineMissingErr
echo "Error $@ does not exist, this should be created by the pipeline module" >&2
exit 1
endef

${TRANS_MAP_DIR}/data/wgEncode%.psl ${TRANS_MAP_DIR}/data/wgEncode%.fa ${TRANS_MAP_DIR}/data/wgEncode%.cds:
	@$(pipelineMissingErr)
${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv:
	@$(pipelineMissingErr)

###
# copy gencode tracks that contain chromosome names to our copy of the
# reference genome (C57B6J) and edit. Don't bother with
# wgEncodeGencodeExonSupport, as it's not currently used by the browser and is
# huge.

srcOrgCheckpointDir = ${CHECKPOINT_DIR}/${srcOrgDb}
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

srcOrgCheckpoints = \
	${gencodeGenepredTables:%=${srcOrgCheckpointDir}/%.gp.done} \
	${gencodeExonSupportTable:%=${srcOrgCheckpointDir}/%.exonsup.done} \
	${gencodeTabTables:%=${srcOrgCheckpointDir}/%.tab.done}

refGencodeTracks: ${srcOrgCheckpoints}

${srcOrgCheckpointDir}/%.gp.done:
	@mkdir -p $(dir $@)
	bin/cloneEditPositionalTable 3 ${srcOrgHgDb} ${srcOrgDb} $*
	touch $@

${srcOrgCheckpointDir}/%.exonsup.done:
	@mkdir -p $(dir $@)
	bin/cloneEditPositionalTable 5 ${srcOrgHgDb} ${srcOrgDb} $*
	touch $@

${srcOrgCheckpointDir}/%.tab.done:
	@mkdir -p $(dir $@)
	hgsql -e 'drop table if exists $*' ${srcOrgDb}
	hgsql -e 'create table $* LIKE ${srcOrgHgDb}.$*' ${srcOrgDb}
	hgsql -e 'insert $* select * from ${srcOrgHgDb}.$*' ${srcOrgDb}
	touch $@
