include defs.mk
#########################################################################################
# Creates databases and loads tracks for one specific genome. called by Makefile.
#########################################################################################
targetOrgDb = Mus${GENOME}_${MSCA_VERSION}
allOrgsDbs = ${allOrgs:%=Mus%_${MSCA_VERSION}}
GBDB_DIR = ${BASE_DATA_DIR}/gbdb/${GENOME}/${targetOrgDb}
BED_DIR = ${BASE_DATA_DIR}/genomes/${targetOrgDb}/bed
CHROM_INFO_DIR = ${BED_DIR}/chromInfo
twoBit = ${GBDB_DIR}/${targetOrgDb}.2bit
agp = ${BED_DIR}/${targetOrgDb}.agp
chromSizes = ${ASM_GENOMES_DIR}/${GENOME}.chrom.sizes
svDir = /hive/groups/recon/projs/mus_strain_cactus/data/yalcin_structural_variants

# some basic tracks we will need to build
repeatMaskerOut = $(wildcard ${ASM_GENOMES_DIR}/${GENOME}.*.out)

##
# placeholder done files - used to checkpoint sql loading commands
##
dbCheckpointDir = ${CHECKPOINT_DIR}/${targetOrgDb}
databaseCheckpoint = ${dbCheckpointDir}/init
transMapGencodeLoadCheckpoints = ${transMapGencodeSubsets:%=${dbCheckpointDir}/%.aln.done} \
	${transMapGencodeSubsets:%=${dbCheckpointDir}/%.info.done}
loadTrackDbCheckpoint = ${dbCheckpointDir}/loadTrackDb.done
chromInfoCheckpoint = ${dbCheckpointDir}/chromInfo.done
goldGapCheckpoint =  ${dbCheckpointDir}/goldGap.done
gcPercentCheckpoint = ${dbCheckpointDir}/gcPercent.done
repeatMaskerCheckpoint = ${dbCheckpointDir}/repeatMasker.done

# structural variants (yalcin et al 2012) against reference genome
ifeq (${GENOME},${srcOrg})
svTrackDbCheckpoint = ${dbCheckpointDir}/svTrackDb.done
svCheckpoints = ${yalcinSvGenomes:%=${dbCheckpointDir}/structural_variants/%.sv.done}
# RNAseq tracks - against reference (by Ian) 
rnaSeqTrackDbCheckpoint = ${dbCheckpointDir}/rnaSeqTrackDb.done
kallistoTrackDbCheckpoint = ${dbCheckpointDir}/kallistoTrackDb.done
endif

# RNAseq tracks - against strains (by Sanger - on 1504 only)
ifneq (${GENOME},${srcOrg})
ifeq (${haveRnaSeq},yes)
ifneq ($(filter ${GENOME},${rnaSeqStrains}),)
# only 1504 has RNAseq alignments
rnaSeqTrackDbCheckpoint = ${dbCheckpointDir}/rnaSeqTrackDb.done
endif
endif
endif

all: createTrackDb loadTrackDb loadTransMap loadGenomeSeqs loadGoldGap loadGcPercent \
	loadCompAnn loadSv loadRepeatMasker


###
# setup databases
##
${databaseCheckpoint}:
	@mkdir -p $(dir $@)
	hgsql -e "CREATE DATABASE IF NOT EXISTS ${targetOrgDb};"
	touch $@


##
# Build trackDb files.
##
createTrackDb: ./trackDb/${GENOME}/trackDb.ra ./trackDb/${GENOME}/${targetOrgDb}/trackDb.ra ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} ${kallistoTrackDbCheckpoint}

./trackDb/${GENOME}/trackDb.ra: ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} bin/buildTrackDb.py $(wildcard ./trackDb/${GENOME}/*.trackDb.ra)
	@mkdir -p $(dir $@)
	${python} bin/buildTrackDb.py $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# also depend on included files
./trackDb/${GENOME}/${targetOrgDb}/trackDb.ra: ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} ${rnaSeqStarTrackDbCheckpoint} bin/buildTrackDb.py $(wildcard ./trackDb/${GENOME}/${targetOrgDb}/*.trackDb.ra) 
	@mkdir -p $(dir $@)
	${python} bin/buildTrackDb.py --genomes ${allOrgsDbs} --this_genome ${targetOrgDb} --hal ${halBrowserHtDocsFile} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# generate RNASeq trackDb entries 
${rnaSeqTrackDbCheckpoint}: bin/rnaseq_tracks.py
	@mkdir -p $(dir $@)
	${python} bin/rnaseq_tracks.py --assembly_version ${MSCA_VERSION} --genome ${GENOME} --ref_genome ${srcOrg}
	touch $@

# Kallisto isoform-level expression (reference genome only)
${kallistoTrackDbCheckpoint}: bin/kallisto_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/kallisto_trackDb.py --assembly_version ${MSCA_VERSION} --ref_genome ${srcOrg}
	touch $@

# structural variant trackDb entries (reference genome only)
${svTrackDbCheckpoint}: bin/structural_variants_yalcin_2012.py
	@mkdir -p $(dir $@)
	${python} bin/structural_variants_yalcin_2012.py --assembly_version ${MSCA_VERSION} --ref_genome ${srcOrg}
	touch $@


###
# load trackDb files into tables
###
loadTrackDb: ${loadTrackDbCheckpoint}

${loadTrackDbCheckpoint}: createTrackDb ${databaseCheckpoint} $(wildcard ./trackDb/*trackDb.ra) $(wildcard ./trackDb/${GENOME}/*trackDb.ra) $(wildcard ./trackDb/${GENOME}/${targetOrgDb}/*trackDb.ra)
	@mkdir -p $(dir $@) locks
	cd ./trackDb && flock ../locks/loadTracks.lock ${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks -grpSql=./grp.sql -sqlDir=${KENT_DIR}/src/hg/lib trackDb hgFindSpec ${targetOrgDb}
	rm -f trackDb/trackDb.tab trackDb/hgFindSpec.tab
	touch $@


###
# Genome sequences: chromInfo and twobit
###
loadGenomeSeqs: ${twoBit} ${chromInfoCheckpoint}

${twoBit}: ${ASM_GENOMES_DIR}/${GENOME}.2bit
	@mkdir -p $(dir $@)
	ln -f $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${CHROM_INFO_DIR}/chromInfo.tab: ${chromSizes}
	@mkdir -p $(dir $@)
	awk '{print $$1 "\t" $$2 "\t'${GBDB_DIR}'/'${targetOrgDb}'.2bit";}' ${chromSizes} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${CHROM_INFO_DIR}/chromInfo.sql: ${CHROM_INFO_DIR}/chromInfo.tab
	@mkdir -p $(dir $@)
	sed -e "s/chrom(16)/chrom(128)/" ${KENT_HG_LIB_DIR}/chromInfo.sql > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${chromInfoCheckpoint}: ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab ${databaseCheckpoint}
	@mkdir -p $(dir $@)
	hgLoadSqlTab ${targetOrgDb} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
	touch $@


##
# assembly and gap tracks. need tmpdir due to static file name
##
# use lock, as hgGoldGapGl uses static file name
loadGoldGap: ${goldGapCheckpoint}
goldTmpDir = ${TMPDIR}/${GENOME}-gold.${tmpExt}

${goldGapCheckpoint}: ${agp} ${databaseCheckpoint}
	@mkdir -p $(dir $@) ${goldTmpDir}
	cd ${goldTmpDir} && hgGoldGapGl -noGl ${targetOrgDb} ${agp}
	rm -rf ${goldTmpDir}
	touch $@

${agp}: ${ASM_GENOMES_DIR}/${GENOME}.fa
	@mkdir -p $(dir $@)
	hgFakeAgp $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@


##
# gencode mapped tracks, except on reference
##
.PHONEY: loadTransMap
ifeq (${GENOME},${srcOrg})
loadTransMap:
else
loadTransMap: ${transMapGencodeLoadCheckpoints}
endif

${dbCheckpointDir}/transMap%.aln.done: ${transMapDataDir}/transMap%.psl ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapAln ${srcOrgDb} ${targetOrgDb} transMapAln$*${TRANS_MAP_TABLE_VERSION} $<
	touch $@

${dbCheckpointDir}/transMap%.info.done: ${transMapDataDir}/transMap%.psl ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapInfo ${srcOrgDb} ${targetOrgDb} $< transMapInfo$*${TRANS_MAP_TABLE_VERSION} ${KENT_HG_LIB_DIR}/transMapInfo.sql
	touch $@


##
# gcPercent  need tmpdir due to static file name
##
loadGcPercent: ${gcPercentTrack}
gcPercentTmpDir = ${TMPDIR}/${GENOME}-gcpercent.${tmpExt}

${gcPercentCheckpoint}: ${twoBit} ${databaseCheckpoint}
	@mkdir -p $(dir $@) ${gcPercentTmpDir}
	cd ${gcPercentTmpDir} && hgGcPercent -win=10000 -verbose=0 -doGaps -noDots ${targetOrgDb} ${twoBit}
	rm -rf ${gcPercentTmpDir}
	touch $@


##
# comparative annotation tracks.  This calls a recurisve target with
# compAnnGencodeSubset=
##
ifeq (${GENOME},${srcOrg})
loadCompAnn:
else
loadCompAnn: ${gencodeSubsets:%=%.loadCompAnn}
endif

%.loadCompAnn: ${chromInfoCheckpoint}
	${MAKE} -f loadGenome.mk loadCompAnnGencodeSubset GENOME="${GENOME}" compAnnGencodeSubset=$*

ifneq (${compAnnGencodeSubset},)
loadCompAnnGencodeSubset: ${compAnnTypes:%=${dbCheckpointDir}/compAnn${compAnnGencodeSubset}_%.done}

#  e.g. compAnnotation/2015-05-29/GencodeBasicVM4/bedfiles/inFrameStop/AJ/AJ.bed
${dbCheckpointDir}/compAnn${compAnnGencodeSubset}_%.done: ${ANNOTATION_DIR}/${compAnnGencodeSubset}/bedfiles/%/${GENOME}/${GENOME}.bed
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed12 -ignoreEmpty ${targetOrgDb} compAnn${compAnnGencodeSubset}_$* $<
	touch $@
endif


##
# structural variation tracks
##
loadSv: ${svCheckpoints}

${dbCheckpointDir}/structural_variants/%.sv.done: ${yalcinSvDir}/%.bed
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed4 -ignoreEmpty ${targetOrgDb} $*_yalcin_svs $<
	touch $@


###
# repeat masker data, if available (not on Rat or all assemblies)
##
ifneq (${repeatMaskerOut},)
loadRepeatMasker: ${repeatMaskerCheckpoint}
else
loadRepeatMasker:
endif

rmskTmpDir = ${TMPDIR}/${GENOME}-rmsk.${tmpExt}
${repeatMaskerCheckpoint}: ${repeatMaskerOut} ${databaseCheckpoint} ${chromInfoCheckpoint}
	@mkdir -p $(dir $@) ${rmskTmpDir}
	cd ${rmskTmpDir} && hgLoadOut ${targetOrgDb} ${repeatMaskerOut}
	rm -rf ${rmskTmpDir}
	touch $@

clean:
	rm -rf ${GBDB_DIR} ${BED_DIR} ${dbCheckpointDir}
	rm -f trackDb/*/trackDb.ra trackDb/*/*/trackDb.ra
	hgsql -e "DROP DATABASE IF EXISTS ${targetOrgDb};"
