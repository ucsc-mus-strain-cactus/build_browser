#########################################################################################
# SHARED VARIABLES
# this file contains variables shared across all of the individual makefiles
#########################################################################################

# this should be the config file from the pipeline
include ../pipeline/config.mk

.SECONDARY:

refGenomeSrcDb = ${refGenomeSQLName}
refGenomeDb = Mus${refGenome}_${MSCA_VERSION}

# what type of chaining was performed? TODO: should be in comparativeAnnotator's config files
CHAINING = simpleChain

# directories
BASE_DATA_DIR = ${MSCA_PROJ_DIR}/browser
GBDB_SHARED_DIR = ${BASE_DATA_DIR}/gbdb/${sharedDb}

# shared variables
sciName = "Mus musculus"
sharedDb = musStrainShared

# insist on group-writable umask
ifneq ($(shell umask),0002)
     $(error umask must be 0002)
endif

ifeq (${TMPDIR},)
     $(error TMPDIR environment variable not set)
endif

KENT_DIR = ${HOME}/kent

# where should we symlink the HAL?
halPath = ${HOME}/public_html/MSCA_HAL_files/$(notdir ${HAL})
halUrl = http://hgwdev.soe.ucsc.edu/~${USER}/MSCA_HAL_files/$(notdir ${HAL})
halFile = /hive/groups/recon/projs/mus_strain_cactus/pipeline_data/comparative/1411/cactus/1411_browser.hal 


# GENCODE transMap input files (FIXME: duplication of pipeline/rules/transMap.mk)
GENCODE_VERSION = VM4
TRANS_MAP_VERSION = 2015-05-15
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
