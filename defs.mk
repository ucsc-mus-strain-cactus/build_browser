#########################################################################################
# SHARED VARIABLES
# this file contains variables shared across all of the individual makefiles
#########################################################################################

# this should be the config file from comparativeAnnotator
include /hive/users/ifiddes/comparativeAnnotator/config_1411.mk

# what type of chaining was performed? TODO: should be in comparativeAnnotator's config files
CHAINING = simpleChain

# directories
BASE_DATA_DIR = ${MSCA_PROJ_DIR}/browser
GBDB_SHARED_DIR = ${BASE_DATA_DIR}/gbdb/${sharedDb}

# shared variables
sciName = "Mus musculus"
sharedDb = musStrainShared

# shared table names
gencodeTableBase = gencode${GENCODE_VERSION}${CHAINING}

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
