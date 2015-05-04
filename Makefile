include defs.mk
# this makefile assumes that you have the kent source directory in your path
# see defs.mk for the necessary inclusion of a config.mk from comparativeAnnotator
sharedDatabaseCheckpoint = ./checkpoints/sharedDatabase/INIT
sourceTranscriptCheckpoint = ./checkpoints/sharedDatabase/TRANSCRIPT
gbdbTranscriptFasta = ${GBDB_SHARED_DIR}/$(notdir ${srcCombinedFasta})

all: ${genomes} trackDbFiles loadSharedSql transcriptFasta

${genomes}: 
	${MAKE} -f loadGenome.mk GENOME=$@ all

trackDbFiles: ./trackDb/trackDb.ra ./trackDb/tagTypes.tab

./trackDb/trackDb.ra:
	@mkdir -p $(dir $@)
	touch $@

./trackDb/tagTypes.tab:
	@mkdir -p $(dir $@)
	cp ${KENT_DIR}/src/hg/makeDb/trackDb/tagTypes.tab $@

loadSharedSql: ${sharedDatabaseCheckpoint} ${sourceTranscriptCheckpoint}

${sharedDatabaseCheckpoint}:
	@mkdir -p $(dir $@)
	hgsql -e "create database IF NOT EXISTS ${sharedDb};"
	touch $@

${sourceTranscriptCheckpoint}: ${gbdbTranscriptFasta}
	@mkdir -p $(dir $@)
	# WARNING: semi hard coded table name here
	hgsql -e "DROP TABLE IF EXISTS ${tableBase}Seq" ${sharedDb}
	hgLoadSeq -seqTbl=${tableBase}Seq -extFileTbl=${tableBase}ExtFile ${sharedDb} ${gbdbTranscriptFasta}
	hgLoadSqlTab ${sharedDb} ${tableBase}Cds ${KENT_DIR}/src/hg/lib/cdsSpec.sql ${srcCombinedCds}
	rm ${tableBase}Seq.tab
	touch $@

transcriptFasta: ${gbdbTranscriptFasta}

${gbdbTranscriptFasta}:
	@mkdir -p $(dir $@)
	cp -n ${srcCombinedFasta} $@.${tmpExt}
	mv -f $@.${tmpExt} $@
