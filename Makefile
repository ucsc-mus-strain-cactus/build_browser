include defs.mk
# this makefile assumes that you have the kent source programs in your path

sharedCheckpointDir = ${CHECKPOINT_DIR}/${sharedDb}
sharedDatabaseCreateCheckpoint = ${sharedCheckpointDir}/sharedDatabaseCreate.done
hgCentralCreateCheckpoint = ${sharedCheckpointDir}/hgCentralCreateCheckpoint.done

# for the shared database, build tables with all source versions.   Per-assembly
# tables would mean duplicating trackDb entries (with a program).  While duplicating
# is easy by code, this one table is the way transmap was design to work.  Hence
# we include all live versions 
transMapLiveVers = $(shell echo ${MSCA_LIVE_VERSIONS} | tr " " "_")
transMapGencodeSrcLoadCheckpoints = \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.${transMapLiveVers}.seq.done} \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.${transMapLiveVers}.src.done} \
	${transMapGencodeSubsets:%=${sharedCheckpointDir}/%.${transMapLiveVers}.gene.done}

all: sharedDb genomeDbs

sharedDb: ${halBrowserHtDocsFile} loadSharedSql
genomeDbs: ${allOrgs:%=%.trackDbs} ${allOrgs:%=%.loadGenome} refGencodeTracks
refGenome: ${srcOrg}.loadGenome

${halBrowserHtDocsFile}: ${halBrowserFile}
	@mkdir -p $(dir $@)
	cp -f $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.trackDbs:
	${MAKE} -f loadGenome.mk GENOME=$* createTrackDb

%.loadGenome: %.trackDbs
	${MAKE} -f loadGenome.mk GENOME=$* all

loadSharedSql: ${sharedDatabaseCreateCheckpoint} ${hgCentralCreateCheckpoint} transmapGencodeShared

${sharedDatabaseCreateCheckpoint}:
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${sharedDb};"
	touch $@

# need to wait for chromInfo tables to be loaded in each database
${hgCentralCreateCheckpoint}: ${sharedDatabaseCreateCheckpoint} genomeDbs bin/hgCentralSetup
	@mkdir -p $(dir $@)
	${python} bin/hgCentralSetup --assemblies ${MSCA_LIVE_VERSIONS} -- hgcentraltest ${sharedDb}
	touch $@


##
## transmap shared source tables.
##
transmapGencodeShared: ${transMapGencodeSrcLoadCheckpoints} 

${sharedCheckpointDir}/transMap%.${transMapLiveVers}.seq.done: ${GBDB_SHARED_DIR}/transMap%.${transMapLiveVers}.fa ${sharedDatabaseCreateCheckpoint}
	@mkdir -p $(dir $@)
	hgLoadSeq -drop -seqTbl=transMapSeq$*${TRANS_MAP_TABLE_VERSION} -extFileTbl=transMapExtFile$*${TRANS_MAP_TABLE_VERSION} ${sharedDb} $<
	rm -f transMapSeq$*${TRANS_MAP_TABLE_VERSION}.tab
	touch $@

${GBDB_SHARED_DIR}/transMap%.${transMapLiveVers}.fa: ${TRANS_MAP_DIR}/data/wgEncode%.fa
	@mkdir -p $(dir $@)
	bin/editTransMapSrcFasta $< $@.${tmpExt} ${liveSrcOrgDbs}
	mv -f $@.${tmpExt} $@

${sharedCheckpointDir}/transMap%.${transMapLiveVers}.src.done: ${TRANS_MAP_DIR}/data/wgEncode%.psl ${sharedDatabaseCreateCheckpoint}
	@mkdir -p $(dir $@)
	bin/loadTransMapSrc ${sharedDb} $< transMapSrc$*${TRANS_MAP_TABLE_VERSION}  ${KENT_HG_LIB_DIR}/transMapSrc.sql ${liveSrcOrgDbs}
	touch $@

${sharedCheckpointDir}/transMap%.${transMapLiveVers}.gene.done: ${TRANS_MAP_DIR}/data/wgEncode%.cds \
					${TRANS_MAP_DIR}/data/wgEncode%.psl \
					${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv \
					${sharedDatabaseCreateCheckpoint}
	@mkdir -p $(dir $@)
	bin/loadTransMapGene ${sharedDb} ${TRANS_MAP_DIR}/data/wgEncodeGencodeAttrs${GENCODE_VERSION}.tsv  ${TRANS_MAP_DIR}/data/wgEncode$*.cds  ${TRANS_MAP_DIR}/data/wgEncode$*.psl transMapGene$*${TRANS_MAP_TABLE_VERSION}  ${KENT_HG_LIB_DIR}/transMapGene.sql ${liveSrcOrgDbs}
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
	@echo ${srcOrgCheckpoints}
	@echo ${}

${srcOrgCheckpointDir}/%.gp.done: refGenome
	@mkdir -p $(dir $@)
	bin/cloneEditPositionalTable 3 ${srcOrgHgDb} ${srcOrgDb} $*
	touch $@

${srcOrgCheckpointDir}/%.exonsup.done: refGenome
	@mkdir -p $(dir $@)
	bin/cloneEditPositionalTable 5 ${srcOrgHgDb} ${srcOrgDb} $*
	touch $@

${srcOrgCheckpointDir}/%.tab.done: refGenome
	@mkdir -p $(dir $@)
	hgsql -e 'drop table if exists $*' ${srcOrgDb}
	hgsql -e 'create table $* LIKE ${srcOrgHgDb}.$*' ${srcOrgDb}
	hgsql -e 'insert $* select * from ${srcOrgHgDb}.$*' ${srcOrgDb}
	touch $@


clean: ${allOrgs:%=%.cleanGenome}
%.cleanGenome:
	${MAKE} -f loadGenome.mk GENOME=$* clean
