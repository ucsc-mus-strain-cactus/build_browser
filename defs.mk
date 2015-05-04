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
tableBase = gencode${GENCODE_VERSION}_${CHAINING}

# this magic sets the umask for every shell call
# https://groups.google.com/forum/?hl=en#!topic/gnu.utils.bug/J3r-QcxcDWc
SHELL = umask a+rw; exec /bin/sh

# hard coding Ian's kent dir; I have a grp.sql file that drops the grp table
KENT_DIR = /cluster/home/ifiddes/kent