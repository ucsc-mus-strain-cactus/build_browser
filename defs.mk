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

# augustus dir containing the genePreds.
tmrDir = /hive/users/ifiddes/ihategit/pipeline/mouse_work_v5/C57B6J/GencodeCompVM8/AugustusTMR/for_browser
cgpDir = /hive/users/ifiddes/ihategit/pipeline/cgp_predictions_v4_overlaps

# consensus location
consensusBaseDir = /hive/users/ifiddes/ihategit/pipeline/mouse_output_v5/C57B6J/GencodeCompVM8/AugustusTMR_consensus_gene_set/for_browser
cgpConsensusBaseDir = /hive/users/ifiddes/ihategit/pipeline/mouse_output_v5/comprehensive_gene_sets/for_browser
cgpConsensusBasicDir = /hive/users/ifiddes/ihategit/pipeline/mouse_output_v5/basic_gene_sets/for_browser

# Environment variables paralleling hg.conf variables to use a different hgcentral database for
# some tables.  Use by loadTracks
export HGDB_DBDBTABLE=musStrainShared.dbDb
export HGDB_DEFAULTDBTABLE=musStrainShared.defaultDb
export HGDB_GENOMECLADETABLE=musStrainShared.genomeClade
export HGDB_CLADETABLE=musStrainShared.clade
