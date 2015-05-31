#########################################################################################
# SHARED VARIABLES
# this file contains variables shared across all of the individual makefiles
#########################################################################################

include ../pipeline/defs.mk

srcOrgDb = Mus${srcOrg}_${MSCA_VERSION}

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
musStrainHtDocsDir = /data/apache/htdocs-mus-strain/
halBrowserHtDocsFile = ${musStrainHtDocsDir}/msca_hal/$(notdir ${halBrowserFile})


# version letter so we can have multiple tables
TRANS_MAP_TABLE_VERSION = a
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
