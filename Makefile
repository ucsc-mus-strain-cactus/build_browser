include defs.mk
# this makefile assumes that you have the kent source directory in your path
# see defs.mk for the necessary inclusion of a config.mk from comparativeAnnotator
sharedDatabaseCreateCheckpoint = ./checkpoints/sharedDatabase/sharedDatabaseCreate
gencodeSourceCheckpoint = ./checkpoints/sharedDatabase/source${gencodeTableBase}
gencodeTranscriptFasta = ${GBDB_SHARED_DIR}/$(notdir ${srcCombinedFasta})


all: ${genomes}

shared: ${halPath} loadSharedSql gencodeTranscriptFasta

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
