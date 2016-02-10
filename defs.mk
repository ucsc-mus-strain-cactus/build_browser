#########################################################################################
# SHARED VARIABLES
# this file contains variables shared across all of the individual makefiles
#########################################################################################

include ../pipeline_msca/defs.mk

srcOrgDb = $(call orgToOrgDbFunc,${srcOrg})

# all that are live in the browser
liveSrcOrgDbs =  ${LIVE_VERSIONS:%=Mus${srcOrg}_%}

# directories
BASE_DATA_DIR = ${PROJ_DIR}/browser
GBDB_SHARED_DIR = ${BASE_DATA_DIR}/gbdb/${sharedDb}

CHECKPOINT_DIR = ${BASE_DATA_DIR}/checkpoints/${VERSION}

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
#lodBrowserHtDocsFile = /scratch/msca_hal/$(notdir ${lodTxtFile})
#lodBrowserHtDocsDir = /scratch/msca_hal/$(notdir ${lodDir})

# structural variants calls
svDir = ${PROJ_DIR}/rel-1410-sv
# no SVs on pahari/caroli
svGenomes = NOD_ShiLtJ BALB_cJ LP_J NZO_HlLtJ AKR_J PWK_PhJ WSB_EiJ CAST_EiJ CBA_J DBA_2J C3H_HeJ SPRET_EiJ 129S1_SvImJ FVB_NJ A_J C57BL_6NJ

# augustus dir containing the genePreds.
augustusResultsDir = ${AUGUSTUS_DIR}

# consensus location
consensusBaseDir = ${ANNOTATION_DIR}/${augustusGencodeSet}/consensus/for_browser
cgpConsensusBaseDir = ${ANNOTATION_DIR}/${augustusGencodeSet}/cgp_consensus/for_browser

# Environment variables paralleling hg.conf variables to use a different hgcentral database for
# some tables.  Use by loadTracks
export HGDB_DBDBTABLE=musStrainShared.dbDb
export HGDB_DEFAULTDBTABLE=musStrainShared.defaultDb
export HGDB_GENOMECLADETABLE=musStrainShared.genomeClade
export HGDB_CLADETABLE=musStrainShared.clade
