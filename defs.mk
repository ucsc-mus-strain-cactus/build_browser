#########################################################################################
# SHARED VARIABLES
# this file contains variables shared across all of the individual makefiles
#########################################################################################

# this should be the config file from comparativeAnnotator
include config_1411.mk
# this makefile assumes that you have the kent source directory in your path
# PATH = /cluster/bin/x86_64/:${PATH}

# variables from config.mk that we need, included here for clarity
# you could remove the above include statement if you set these variables
# which represent information from comparativeAnnotator
#MSCA_PROJ_DIR = 
#MSCA_VERSION = 
#GENOMES_DIR = 
#TRANS_MAP_DIR = 
#tmpExt = 

# what type of chaining was preformed? TODO: should be in comparativeAnnotator's config files
CHAINING = simpleChain

# directories
BASE_DATA_DIR = ${MSCA_PROJ_DIR}/browser
GBDB_SHARED_DIR = ${BASE_DATA_DIR}/gbdb/${sharedDb}

# shared variables
sciName = "Mus musculus"
sharedDb = musStrainShared

# shared table names
tableBase = gencode${MSCA_VERSION}${CHAINING}

# this magic sets the umask for every shell call
# https://groups.google.com/forum/?hl=en#!topic/gnu.utils.bug/J3r-QcxcDWc
SHELL = umask a+rw; exec /bin/sh

# hard coding Ian's kent dir
KENT_DIR = /cluster/home/ifiddes/kent