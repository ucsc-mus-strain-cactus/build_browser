include defs.mk
#########################################################################################
# Creates databases and loads tracks for one specific genome. called by Makefile.
#########################################################################################
targetOrgDb = $(call orgToOrgDbFunc,${GENOME})
allOrgsDbs = ${allOrgs:%= $(call orgToOrgDbFunc,%)}
GBDB_DIR = ${BASE_DATA_DIR}/gbdb/${GENOME}/${targetOrgDb}
BED_DIR = ${BASE_DATA_DIR}/genomes/${targetOrgDb}/bed
CHROM_INFO_DIR = ${BED_DIR}/chromInfo
twoBit = ${GBDB_DIR}/${targetOrgDb}.2bit
agp = ${BED_DIR}/${targetOrgDb}.agp
chromSizes = ${ASM_GENOMES_DIR}/${GENOME}.chrom.sizes
svDir = /hive/groups/recon/projs/mus_strain_cactus/data/yalcin_structural_variants
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${GENOME}

# some basic tracks we will need to build
repeatMaskerOut = $(wildcard ${ASM_GENOMES_DIR}/${GENOME}.out)

##
# placeholder done files - used to checkpoint sql loading commands
##
dbCheckpointDir = ${CHECKPOINT_DIR}/${targetOrgDb}
databaseCheckpoint = ${dbCheckpointDir}/init
loadTrackDbCheckpoint = ${dbCheckpointDir}/loadTrackDb.done
chromInfoCheckpoint = ${dbCheckpointDir}/chromInfo.done
goldGapCheckpoint =  ${dbCheckpointDir}/goldGap.done
gcPercentCheckpoint = ${dbCheckpointDir}/gcPercent.done
repeatMaskerCheckpoint = ${dbCheckpointDir}/repeatMasker.done
augustusTrackDbCheckpoint = ${dbCheckpointDir}/augustus.done
chainsCheckpoint = ${dbCheckpointDir}/chains.done
netsCheckpoint = ${dbCheckpointDir}/nets.done

# structural variants (yalcin et al 2012) against reference genome
ifeq (${GENOME},${srcOrg})
svTrackDbCheckpoint = ${dbCheckpointDir}/svTrackDb.done
svCheckpoints = ${yalcinSvGenomes:%=${dbCheckpointDir}/structural_variants/%.sv.done}
# RNAseq tracks - against reference
rnaSeqTrackDbCheckpoint = ${dbCheckpointDir}/rnaSeqTrackDb.done
kallistoTrackDbCheckpoint = ${dbCheckpointDir}/kallistoTrackDb.done
endif

# RNAseq tracks - against strains (on 1504/1509)
ifneq (${GENOME},${srcOrg})
ifeq (${haveRnaSeq},yes)
ifneq ($(filter ${GENOME},${rnaSeqStrains}),)
# only 1504/1509 has RNAseq alignments
rnaSeqTrackDbCheckpoint = ${dbCheckpointDir}/rnaSeqTrackDb.done
endif
endif
endif

all: loadTracks loadTrackDb

# this loads all tracks, but not trackDb.  This must be done first due to -strict trackDb
loadTracks: loadTransMap loadGenomeSeqs loadGoldGap loadGcPercent \
	loadCompAnn loadSv loadRepeatMasker loadAugustus loadConsensus loadChains


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
trackDbOrgDir=./trackDb/${GENOME}
trackDbGenomeDir=${trackDbOrgDir}/${targetOrgDb}
createTrackDb: ${trackDbOrgDir}/trackDb.ra ${trackDbGenomeDir}/trackDb.ra ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} ${kallistoTrackDbCheckpoint} ${augustusTrackDbCheckpoint}

${trackDbOrgDir}/trackDb.ra: ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} bin/buildTrackDb.py $(wildcard ${trackDbOrgDir}/*.trackDb.ra)
	@mkdir -p $(dir $@)
	${python} bin/buildTrackDb.py $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# also depend on included files
ifdef lodBrowserHtDocsFile
    # use lod in snake tracks
    halOrLod=${lodBrowserHtDocsFile}
else
    # use hal in snake tracks
    halOrLod=${halBrowserHtDocsFile}
endif
${trackDbGenomeDir}/trackDb.ra: ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} ${rnaSeqStarTrackDbCheckpoint} bin/buildTrackDb.py $(wildcard ${trackDbGenomeDir}/*.trackDb.ra) 
	@mkdir -p $(dir $@)
	${python} bin/buildTrackDb.py --ref_genome=${srcOrgDb} --genomes ${allOrgsDbs} --this_genome ${targetOrgDb} --halOrLod ${halOrLod} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# generate RNASeq trackDb entries 
${rnaSeqTrackDbCheckpoint}: bin/rnaseq_tracks.py
	@mkdir -p $(dir $@) ${trackDbGenomeDir}
	${python} bin/rnaseq_tracks.py --assembly_version ${VERSION} --genome ${GENOME} --ref_genome ${srcOrg}
	touch $@

# Kallisto isoform-level expression (reference genome only)
${kallistoTrackDbCheckpoint}: bin/kallisto_trackDb.py
	@mkdir -p $(dir $@) ${trackDbGenomeDir}
	${python} bin/kallisto_trackDb.py --assembly_version ${VERSION} --ref_genome ${srcOrg}
	touch $@

# structural variant trackDb entries (reference genome only)
${svTrackDbCheckpoint}: bin/structural_variants_yalcin_2012.py
	@mkdir -p $(dir $@)
	${python} bin/structural_variants_yalcin_2012.py --assembly_version ${VERSION} --ref_genome ${srcOrg}
	touch $@

${augustusTrackDbCheckpoint}: bin/augustus_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/augustus_trackDb.py --assembly_version ${VERSION} --genome ${GENOME} --ref_genome ${srcOrg}
	touch $@

${consensusTrackDbCheckpoint}: bin/consensus_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/consensus_trackDb.py --assembly_version ${VERSION} --genome ${GENOME} --ref_genome ${srcOrg}
	touch $@


###
# load trackDb files into tables
###
loadTrackDb: ${loadTrackDbCheckpoint}

# tracks must be loaded first with -strict
# NOTE: see HGDB_* environment variable sset in defs.mk
${loadTrackDbCheckpoint}: createTrackDb loadTracks $(wildcard ./trackDb/*trackDb.ra) $(wildcard ${trackDbOrgDir}/*trackDb.ra) $(wildcard ${trackDbGenomeDir}/*trackDb.ra)
	@mkdir -p $(dir $@) locks
	cd ./trackDb && flock ../locks/loadTracks.lock ${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks -strict -grpSql=./grp.sql -sqlDir=${KENT_DIR}/src/hg/lib trackDb hgFindSpec ${targetOrgDb}
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
ifneq (${GENOME},${srcOrg})
ifneq (${GENOME},Rattus)
loadTransMap: ${transMapGencodeSubsets:%=${dbCheckpointDir}/%.aln.done} \
	${transMapGencodeSubsets:%=${dbCheckpointDir}/%.info.done}
else
loadTransMap:
endif
else
loadTransMap:
endif

${dbCheckpointDir}/transMap%.aln.done: ${transMapDataDir}/transMap%.psl ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapAln ${srcOrgDb} ${targetOrgDb} transMapAln$* $<
	touch $@

${dbCheckpointDir}/transMap%.info.done: ${transMapDataDir}/transMap%.psl ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapInfo ${srcOrgDb} ${targetOrgDb} $< transMapInfo$* ${KENT_HG_LIB_DIR}/transMapInfo.sql
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
# comparative annotation tracks.
##
ifneq (${GENOME},${srcOrg})
ifneq (${GENOME},Rattus)
loadCompAnn: ${gencodeSubsets:%=%.loadCompAnn}
else
loadCompAnn:
endif
else
loadCompAnn: 
endif

%.loadCompAnn: ${chromInfoCheckpoint}
	${MAKE} -f loadGenome.mk loadCompAnnGencodeSubset GENOME="${GENOME}" compAnnGencodeSubset=$*

ifneq (${compAnnGencodeSubset},)
loadCompAnnGencodeSubset: ${compAnnTypes:%=${dbCheckpointDir}/compAnn${compAnnGencodeSubset}_%.done}
endif

#  e.g. compAnnotation/2015-05-29/GencodeBasicVM4/bedfiles/inFrameStop/AJ/AJ.bed
${dbCheckpointDir}/compAnn${compAnnGencodeSubset}_%.done: ${ANNOTATION_DIR}/${compAnnGencodeSubset}/bedfiles/%/${GENOME}/${GENOME}.bed
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed12 -ignoreEmpty ${targetOrgDb} compAnn${compAnnGencodeSubset}_$* $<
	touch $@


##
# structural variation tracks
##
loadSv: ${svCheckpoints}

${dbCheckpointDir}/structural_variants/%.sv.done: ${yalcinSvDir}/%.bed
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed4 -ignoreEmpty ${targetOrgDb} $*_yalcin_svs $<
	touch $@


##
# load augustus tracks as genePred
##
ifneq (${GENOME},${srcOrg})
ifneq (${GENOME},Rattus)
# rule for species with all augustus tracks (all except C57B6J and Rattus)
loadAugustus: ${dbCheckpointDir}/augustusTMR.done ${dbCheckpointDir}/augustusCGP.done ${dbCheckpointDir}/augustusCGP_unfiltered.done
else
# rule for Rattus (has CGP)
loadAugustus: ${dbCheckpointDir}/augustusCGP.done ${dbCheckpointDir}/augustusCGP_unfiltered.done
endif
else
# rule for C57B6J (has CGP)
loadAugustus: ${dbCheckpointDir}/augustusCGP.done ${dbCheckpointDir}/augustusCGP_unfiltered.done
endif

${dbCheckpointDir}/augustusTMR.done: ${augustusResultsDir}/tmr/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/addName2ToGenePred.py $< augustus | flock locks/augustusTMR hgLoadGenePred -genePredExt ${targetOrgDb} augustusTMR stdin
	touch $@

${dbCheckpointDir}/augustusCGP.done: ${augustusResultsDir}/cgp/filteredCGP_forBrowser/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	flock locks/augustusCGP hgLoadGenePred -genePredExt ${targetOrgDb} augustusCGP $<
	touch $@

${dbCheckpointDir}/augustusCGP_unfiltered.done: ${augustusResultsDir}/cgp/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	flock locks/augustusCGP_unfiltered hgLoadGenePred -genePredExt ${targetOrgDb} augustusCGP_unfiltered $<
	touch $@


##
# load consensus tracks as genePred
##
ifneq (${GENOME},${srcOrg})
ifneq (${GENOME},Rattus)
# rule for species with all augustus tracks (all except C57B6J and Rattus)
loadConsensus: ${dbCheckpointDir}/consensusTMR.done ${dbCheckpointDir}/consensusCGP.done
else
loadConsensus: 
endif
else
loadConsensus: 
endif

${dbCheckpointDir}/consensusTMR.done: ${consensusBaseDir}/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	flock locks/TMR_consensus hgLoadGenePred -genePredExt ${targetOrgDb} TMR_consensus $<
	touch $@

${dbCheckpointDir}/consensusCGP.done: ${cgpConsensusBaseDir}/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	flock locks/TMR_CGP_consensus hgLoadGenePred -genePredExt ${targetOrgDb} TMR_CGP_consensus $<
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
###
# genomic chains/net from the reference
###
chainAll = $(wildcard $(call chainAllFunc,${srcOrg},${GENOME}))
netAll = $(wildcard $(call netAllFunc,${srcOrg},${GENOME}))

ifeq (${chainAll},)
loadChains:
else
loadChains: ${chainsCheckpoint}

# FIXME: can't load nets due to needing repeatMasker input for netClass
# ${netsCheckpoint}

${chainsCheckpoint}: ${chainAll}
	@mkdir -p $(dir $@) locks
	flock locks/loadChains.lock hgLoadChain ${targetOrgDb} chain${srcOrgDb} $<
	touch $@

${netsCheckpoint}: ${netAll}
	@mkdir -p $(dir $@) locks
	flock locks/loadNets.lock hgLoadNet ${targetOrgDb} net${srcOrgDb} $<
	touch $@

endif

clean:
	rm -rf ${GBDB_DIR} ${BED_DIR} ${dbCheckpointDir}
	rm -f trackDb/*/trackDb.ra trackDb/*/*/trackDb.ra
	hgsql -e "DROP DATABASE IF EXISTS ${targetOrgDb};"
