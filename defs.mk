#########################################################################################
# SHARED VARIABLES
# this file contains variables shared across all of the individual makefiles
#########################################################################################

include ../pipeline/defs.mk

srcOrgDb = $(call orgToOrgDbFunc,${srcOrg})

# all that are live in the browser
liveSrcOrgDbs =  ${MSCA_LIVE_VERSIONS:%=Mus${srcOrg}_%}

# directories
BASE_DATA_DIR = ${MSCA_PROJ_DIR}/browser
GBDB_SHARED_DIR = ${BASE_DATA_DIR}/gbdb/${sharedDb}

CHECKPOINT_DIR = ${BASE_DATA_DIR}/checkpoints/${MSCA_VERSION}

# misc
sciName = "Mus musculus"
sharedDb = musStrainShared

##
# HAL file.  Copy to local disk
##
musStrainUrl = http://hgwdev-mus-strain.sdsc.edu/
musStrainHtDocsDir = /data/apache/htdocs-mus-strain
halBrowserHtDocsFile = /scratch/msca_hal/$(notdir ${halBrowserFile})

# Comment these two lines out if you have not yet created LODs, and
# the browser will use the raw hal file instead.
lodBrowserHtDocsFile = /scratch/msca_hal/$(notdir ${lodTxtFile})
lodBrowserHtDocsDir = /scratch/msca_hal/$(notdir ${lodDir})

TRANS_MAP_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/transMap/${TRANS_MAP_VERSION}

srcGencodeBasic = wgEncodeGencodeBasic${GENCODE_VERSION}
srcGencodeComp = wgEncodeGencodeComp${GENCODE_VERSION}
srcGencodePseudo = wgEncodeGencodePseudoGene${GENCODE_VERSION}
srcGencodeAttrs = wgEncodeGencodeAttrs${GENCODE_VERSION}
srcGencodeSubsets = ${srcGencodeBasic} ${srcGencodeComp} ${srcGencodePseudo}

transMapDataDir = ${TRANS_MAP_DIR}/transMap/${GENOME}
transMapGencodeBasic = transMapGencodeBasic${GENCODE_VERSION}
transMapGencodeComp = transMapGencodeComp${GENCODE_VERSION}
transMapGencodePseudo = transMapGencodePseudoGene${GENCODE_VERSION}
transMapGencodeAttrs = transMapGencodeAttrs${GENCODE_VERSION}
transMapGencodeSubsets = ${transMapGencodeBasic} ${transMapGencodeComp} ${transMapGencodePseudo}

# structural variants from yalcin et al 2012
#yalcinSvDir = ${MSCA_PROJ_DIR}/data/yalcin_structural_variants
#yalcinSvGenomes = LPJ DBA2J CBAJ C3HHeJ BALBcJ AKRJ AJ

rnaSeqStrains = 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6NJ CASTEiJ CBAJ DBA2J LPJ NODShiLtJ NZOHlLtJ PWKPhJ SPRETEiJ WSBEiJ CAROLIEiJ PAHARIEiJ

# augustus dir containing the genePreds.
augustusResultsDir = /hive/groups/recon/projs/mus_strain_cactus/pipeline_data/comparative/${MSCA_VERSION}/augustus

# Environment variables paralleling hg.conf variables to use a different hgcentral database for
# some tables.  Use by loadTracks
export HGDB_DBDBTABLE=musStrainShared.dbDb
export HGDB_DEFAULTDBTABLE=musStrainShared.defaultDb
export HGDB_GENOMECLADETABLE=musStrainShared.genomeClade
export HGDB_CLADETABLE=musStrainShared.clade
