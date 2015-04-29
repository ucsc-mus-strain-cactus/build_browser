#########################################################################################
# CONFIG
#########################################################################################
GENOME=C57B6NJ
RELEASE=1411
BASE_DATA_DIR=/hive/groups/recon/projs/mus_strain_cactus/pipeline_data/browser
START_DIR=$PWD
BASE_TRACKDB_DIR=./trackDb
KENT_DIR=~/kent
TARGET_TWO_BIT=/hive/users/ifiddes/comparativeAnnotator/pipeline_data/assemblies/1411/${GENOME}.2bit
TARGET_PSL=/hive/users/ifiddes/comparativeAnnotator/pipeline_data/comparative/1411/transMap/results/filtered/${GENOME}.filtered.psl
SOURCE_CDS=/hive/users/ifiddes/comparativeAnnotator/pipeline_data/comparative/1411/transMap/data/VM4.BasicPseudoCombined.cds
SOURCE_TRANSCRIPT_FASTA=/hive/users/ifiddes/comparativeAnnotator/pipeline_data/comparative/1411/transMap/data/VM4.BasicPseudoCombined.fasta
SCI_NAME="Mus musculus"
umask a+rw

#########################################################################################
# VARIABLES
#########################################################################################
DB=${GENOME}_${RELEASE}
SHARED_DB=musStrainShared
GENOME_DIR=${BASE_DATA_DIR}/genomes/${DB}
TWO_BIT=${GENOME_DIR}/${DB}.2bit
FASTA=${GENOME_DIR}/${DB}.fa
SIZES=${GENOME_DIR}/${DB}.chrom.sizes
AGP=${GENOME_DIR}/${DB}.agp
BED_DIR=${GENOME_DIR}/bed/
CHROM_INFO_DIR=${GENOME_DIR}/bed/chromInfo
GBDB_DIR=${BASE_DATA_DIR}/gbdb/${GENOME}/${DB}
GBDB_SHARED_DIR=${BASE_DATA_DIR}/gbdb/${SHARED_DB}
SQL_DIR=${KENT_DIR}/src/hg/lib
TRACKDB=${BASE_TRACKDB_DIR}/${GENOME}/${DB}
LOAD_TRACKS=${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks
SQL_DIR=${KENT_DIR}/src/hg/lib

#########################################################################################
# preparing directories/2bit/fa/sizes/agp files
#########################################################################################
mkdir -p ${GENOME_DIR}
mkdir -p ${GBDB_DIR}
mkdir -p ${GBDB_SHARED_DIR}
mkdir -p ${TRACKDB}
cp ${TARGET_TWO_BIT} ${TWO_BIT}
twoBitToFa ${TWO_BIT} ${FASTA}
twoBitInfo ${TWO_BIT} stdout | sort -k2nr > ${SIZES}
hgFakeAgp ${FASTA} ${AGP}
ln -s ${TWO_BIT} ${GBDB_DIR}/${DB}.2bit
touch ${BASE_TRACKDB_DIR}/trackDb.ra
cp ${KENT_DIR}/src/hg/makeDb/trackDb/tagTypes.tab ${BASE_TRACKDB_DIR}/tagTypes.tab

#########################################################################################
# generating track information
#########################################################################################
mkdir -p ${CHROM_INFO_DIR}
awk '{print $1 "\t" $2 "\t'${GBDB_DIR}'/'${DB}'.2bit";}' ${SIZES} > ${CHROM_INFO_DIR}/chromInfo.tab
cut -f1 ${CHROM_INFO_DIR}/chromInfo.tab | awk '{print length($0)}'  | sort -nr > ${CHROM_INFO_DIR}/t.chrSize
chrSize=`head -1 ${CHROM_INFO_DIR}/t.chrSize`
sed -e "s/chrom(16)/chrom($chrSize)/" ${HOME}/kent/src/hg/lib/chromInfo.sql > ${CHROM_INFO_DIR}/chromInfo.sql
rm -f bed/chromInfo/t.chrSize

#########################################################################################
# starting hgsql commands
#########################################################################################
hgsql -e "create database ${DB};"
hgsql -e "create database ${SHARED_DB};"
hgGoldGapGl -noGl ${DB} ${AGP}
hgLoadSqlTab ${DB} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
hgsql $DB < ${SQL_DIR}/grp.sql
cd ${BASE_TRACKDB_DIR} && ${LOAD_TRACKS} -grpSql=${SQL_DIR}/grp.sql -sqlDir=${SQL_DIR} trackDb hgFindSpec ${DB} 
rm trackDb.tab hgFindSpec.tab && cd ../
# load RNA sequence into database to be shared by all genomes
# TODO: VM4 should not be hard coded, but instead pulled from the comparativeAnnotator config file
hgLoadPsl -table=gencodeVM4_SimpleChain ${DB} ${TARGET_PSL}
# copy the reference transcriptome to gbdb
n=`basename ${SOURCE_TRANSCRIPT_FASTA}`
cp -n ${SOURCE_TRANSCRIPT_FASTA} ${GBDB_SHARED_DIR}/${n}
# this creates a .tab file - do we need it?
hgLoadSeq -seqTbl=gencodeVM4_SimpleChainSeq -extFileTbl=gencodeVM4_SimpleChainExtFile ${SHARED_DB} ${GBDB_SHARED_DIR}/${n}
hgLoadSqlTab ${SHARED_DB} gencodeVM4Cds ~/kent/src/hg/lib/cdsSpec.sql ${SOURCE_CDS}
cd ${BASE_TRACKDB_DIR} && ${LOAD_TRACKS} -sqlDir=${SQL_DIR} trackDb hgFindSpec ${DB} && cd ../
