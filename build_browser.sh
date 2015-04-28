#########################################################################################
# CONFIG
#########################################################################################
GENOME=C57B6NJ
RELEASE=1411
BASE_DATA_DIR=/hive/groups/recon/projs/mus_strain_cactus/pipeline_data/browser
START_DIR=$PWD
BASE_TRACKDB_DIR=./trackDb
KENT_DIR=~/kent
# TODO: SOURCE_TWO_BIT should be the only and only input argument
SOURCE_TWO_BIT=/cluster/home/ifiddes/ifiddes_hive/comparativeAnnotator/pipeline_data/assemblies/1411/${GENOME}.2bit
SCI_NAME="Mus musculus"
umask a+rwx

#########################################################################################
# VARIABLES
#########################################################################################
DB=${GENOME}_${RELEASE}
GENOME_DIR=${BASE_DATA_DIR}/genomes/${DB}
TWO_BIT=${GENOME_DIR}/${DB}.2bit
FASTA=${GENOME_DIR}/${DB}.fa
SIZES=${GENOME_DIR}/${DB}.chrom.sizes
AGP=${GENOME_DIR}/${DB}.agp
BED_DIR=${GENOME_DIR}/bed/
CHROM_INFO_DIR=${GENOME_DIR}/bed/chromInfo
GBDB_DIR=${BASE_DATA_DIR}/gbdb/${GENOME}/${DB}
SQL_DIR=${KENT_DIR}/src/hg/lib
TRACKDB=${BASE_TRACKDB_DIR}/${GENOME}/${DB}
LOAD_TRACKS=${KENT_DIR}/src/hg/makeDb/trackDb/loadTracks
SQL_DIR=${KENT_DIR}/src/hg/lib

#########################################################################################
# preparing directories/2bit/fa/sizes/agp files
#########################################################################################
mkdir -p ${GENOME_DIR}
mkdir -p ${GBDB_DIR}
mkdir -p ${TRACKDB}
cp ${SOURCE_TWO_BIT} ${TWO_BIT}
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
hgGoldGapGl -noGl ${DB} ${AGP}
hgLoadSqlTab ${DB} chromInfo ${CHROM_INFO_DIR}/chromInfo.sql ${CHROM_INFO_DIR}/chromInfo.tab
hgsql $DB < ${SQL_DIR}/grp.sql
cd ${BASE_TRACKDB_DIR} && ${LOAD_TRACKS} -grpSql=${SQL_DIR}/grp.sql -sqlDir=${SQL_DIR} trackDb hgFindSpec ${DB} 
rm trackDb.tab hgFindSpec.tab && cd ${START_DIR}

