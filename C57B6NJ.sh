GENOME=$1
TWOBIT=/cluster/home/ifiddes/ifiddes_hive/comparativeAnnotator/pipeline_data/assemblies/1411/$1.2bit
SCI_NAME="Mus musculus"

export DB=$1

mkdir ${DB}
cp ${TWOBIT} ${DB}/${DB}.2bit
