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

# structural variants calls
svGenomes = C57BL_6NJ NZO_HlLtJ 129S1_SvImJ FVB_NJ NOD_ShiLtJ LP_J A_J AKR_J BALB_cJ DBA_2J C3H_HeJ CBA_J WSB_EiJ CAST_EiJ PWK_PhJ SPRET_EiJ
svDir = ${PROJ_DIR}/data/rel-1410-sv

# SV calls made from the alignment
halSVDir = ${PROJ_DIR}/pipeline_data/comparative/${VERSION}/sv/halSVCalls/

# transMap data
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${GENOME}

# dless BED for interesting subtree
dlessBed = /hive/groups/recon/projs/mus_strain_cactus/pipeline_data/comparative/1509/phastAnalysis/SPRET_EiJ.PWK_PhJ.WSB_EiJ.NOD_ShiLtJ.CAROLI_EiJ.Pahari_EiJ.Rattus.C57B6J/dless/dless.bed

# phastCons BED and wig
phastConsDir = /hive/users/ifiddes/comparativeAnnotator/mammal_phastcons
phastConsBed = ${phastConsDir}/phast_cons_rescaled.bed
phastConsWig = ${phastConsDir}/phast_cons.bw


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
chainsCheckpoint = ${dbCheckpointDir}/chains.done
netsCheckpoint = ${dbCheckpointDir}/nets.done

# non-ref non-rat tracks
ifneq (${GENOME},Rattus)
ifneq (${GENOME},${srcOrg})
augustusTrackDbCheckpoint = ${dbCheckpointDir}/augustus.done
consensusTrackDbCheckpoint = ${dbCheckpointDir}/consensus.done
endif
endif


# reference specific tracks
ifeq (${GENOME},${srcOrg})
# structural variants against reference genome
svTrackDbCheckpoint = ${dbCheckpointDir}/svTrackDb.done
svCheckpoints = ${svGenomes:%=${dbCheckpointDir}/structural_variants/%.sv.done}
# alignment SV calls against reference genome
alignmentSVCheckpoints = ${mappedOrgs:%=${dbCheckpointDir}/alignmentSvCalls/%.hal.done}
alignmentSVTrackDbCheckpoint = ${dbCheckpointDir}/alignmentSvCallsTrackDb.done}
# RNAseq tracks - against reference
rnaSeqTrackDbCheckpoint = ${dbCheckpointDir}/rnaSeqTrackDb.done
# conservation tracks using reference
conservationTrackDbCheckpoint = ${dbCheckpointDir}/conservationTrackDb.done
conservationCheckpoint = ${dbCheckpointDir}/conservation.done
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
	loadSv loadConservation loadRepeatMasker loadAugustus loadConsensus loadChains \
	loadAlignmentSVCalls


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
createTrackDb: ${trackDbOrgDir}/trackDb.ra ${trackDbGenomeDir}/trackDb.ra ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} \
	${kallistoTrackDbCheckpoint} ${augustusTrackDbCheckpoint} ${consensusTrackDbCheckpoint} ${alignmentSVTrackDbCheckpoint}

${trackDbOrgDir}/trackDb.ra: ${consensusTrackDbCheckpoint} ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} bin/buildTrackDb.py $(wildcard ${trackDbOrgDir}/*.trackDb.ra)
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
${trackDbGenomeDir}/trackDb.ra: ${conservationTrackDbCheckpoint} ${rnaSeqTrackDbCheckpoint} ${svTrackDbCheckpoint} ${rnaSeqStarTrackDbCheckpoint} bin/buildTrackDb.py $(wildcard ${trackDbGenomeDir}/*.trackDb.ra)
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

${augustusTrackDbCheckpoint}: bin/augustus_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/augustus_trackDb.py --assembly_version ${VERSION} --genome ${GENOME} --ref_genome ${srcOrg}
	touch $@

${consensusTrackDbCheckpoint}: bin/consensus_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/consensus_trackDb.py --assembly_version ${VERSION} --genome ${GENOME}
	touch $@

# structural variant trackDb entries (reference genome only)
${svTrackDbCheckpoint}: bin/structural_variants.py
	@mkdir -p $(dir $@)
	${python} bin/structural_variants.py --assembly_version ${VERSION} --ref_genome ${srcOrg} --sv_dir ${svDir}
	touch $@

${alignmentSVTrackDbCheckpoint}: bin/alignment_sv_calls_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/alignment_sv_calls_trackDb.py --assembly_version ${VERSION} --ref_genome ${srcOrg} --halSVDir ${halSVDir}
	touch $@

${conservationTrackDbCheckpoint}: bin/conservation_trackDb.py
	@mkdir -p $(dir $@)
	${python} bin/conservation_trackDb.py --assembly_version ${VERSION} --ref_genome ${srcOrg} --wigpath ${phastConsWig}
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

${dbCheckpointDir}/transMap%.aln.done: ${transMapDataDir}/%.psl ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/loadTransMapAln ${srcOrgDb} ${targetOrgDb} transMapAln$* $<
	touch $@

${dbCheckpointDir}/transMap%.info.done: ${transMapDataDir}/%.psl ${chromInfoCheckpoint}
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

${dbCheckpointDir}/structural_variants/%.sv.done: ${svDir}/%.svs.bed
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed4 -ignoreEmpty ${targetOrgDb} $*_svs $<
	touch $@


##
# SV calls from the alignment
##
loadAlignmentSVCalls: ${alignmentSVCheckpoints}

${dbCheckpointDir}/alignmentSvCalls/%.hal.done: ${halSVDir}/%.bed
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed4 -ignoreEmpty ${targetOrgDb} $*_hal_sv_calls $<
	touch $@

##
# conservation tracks
##
loadConservation: ${conservationCheckpoint}

${conservationCheckpoint}:
	@mkdir -p $(dir $@)
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed6 -ignoreEmpty ${targetOrgDb} dless1 ${dlessBed}
	hgLoadBed -tmpDir=$${TMPDIR} -allowStartEqualEnd -tab -type=bed6 -ignoreEmpty ${targetOrgDb} phast_bed ${phastConsBed}


##
# load augustus tracks as genePred
##
ifneq (${GENOME},${srcOrg})
ifneq (${GENOME},Rattus)
# rule for species with all augustus tracks (all except C57B6J and Rattus)
loadAugustus: ${dbCheckpointDir}/augustusTMR.done ${dbCheckpointDir}/augustusCGP.done
else
# rule for Rattus
loadAugustus:
endif
else
# rule for C57B6J
loadAugustus: ${dbCheckpointDir}/augustusCGP.done
endif

${dbCheckpointDir}/augustusTMR.done: ${tmrDir}/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	./bin/addName2ToGenePred.py $< augustus | flock locks/augustusTMR hgLoadGenePred -genePredExt ${targetOrgDb} augustusTMR stdin
	touch $@

${dbCheckpointDir}/augustusCGP.done: ${cgpDir}/${GENOME}.gp ${chromInfoCheckpoint}
	@mkdir -p $(dir $@)
	flock locks/augustusCGP hgLoadGenePred -genePredExt ${targetOrgDb} augustusCGP $<
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
