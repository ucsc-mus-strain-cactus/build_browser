include defs.mk
# this makefile assumes that you have the kent source directory in your path
# see defs.mk for the necessary inclusion of a config.mk from comparativeAnnotator
sharedDatabaseCreateCheckpoint = ./checkpoints/sharedDatabase/sharedDatabaseCreate
gencodeSourceCheckpoint = ./checkpoints/sharedDatabase/source${gencodeTableBase}
gencodeTranscriptFasta = ${GBDB_SHARED_DIR}/$(notdir ${srcCombinedFasta})


all: shared genomes

shared: ${halPath} loadSharedSql gencodeTranscriptFasta
genomes: ${genomes} refGencodeTracks

${halPath}:
	@mkdir -p $(dir $@)
	ln -sf ${HAL} $@

${genomes}: 
	${MAKE} -f loadGenome.mk GENOME=$@ all

loadSharedSql: ${sharedDatabaseCreateCheckpoint} ${gencodeSourceCheckpoint}


${sharedDatabaseCreateCheckpoint}:
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${sharedDb};"
	touch $@

${gencodeSourceCheckpoint}: ${gencodeTranscriptFasta}
	@mkdir -p $(dir $@)
	hgLoadSeq -drop -seqTbl=${gencodeTableBase}Seq -extFileTbl=${gencodeTableBase}ExtFile ${sharedDb} ${gencodeTranscriptFasta}
	hgLoadSqlTab ${sharedDb} ${gencodeTableBase}Cds ${KENT_DIR}/src/hg/lib/cdsSpec.sql ${srcCombinedCds}
	rm ${gencodeTableBase}Seq.tab
	touch $@

gencodeTranscriptFasta: ${gencodeTranscriptFasta}

${gencodeTranscriptFasta}: ${srcCombinedFasta}
	@mkdir -p $(dir $@)
	cp -n ${srcCombinedFasta} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

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
	${gencodeTabTables:%=${refGenomeCheckpointDir}/%.tab}

refGencodeTracks: ${refGenomeCheckpoints}

${refGenomeCheckpointDir}/%.gp:
	@mkdir -p $(dir $@)
	bin/cloneEditGenePredTable ${refGenomeSrcDb} ${refGenomeDb} $*
	touch $@

${refGenomeCheckpointDir}/%.tab:
	@mkdir -p $(dir $@)
	hgsql -e 'drop table if exists $*' ${refGenomeDb}
	hgsql -e 'create table $* LIKE ${refGenomeSrcDb}.$*' ${refGenomeDb}
	hgsql -e 'insert $* select * from ${refGenomeSrcDb}.$*' ${refGenomeDb}
	touch $@
