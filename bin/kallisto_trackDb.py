"""
Produces trackDb files for the log-normalized expression BEDfiles created from kallisto
(see comparativeRNAseq repo)
"""

import sys
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference strain (C57B6J)', required=True)
    return parser.parse_args()


bed_dir = "/hive/groups/recon/projs/mus_strain_cactus/pipeline_data/rnaseq/log_expression_bedfiles"


per_gene_set_super_trackline = """track kallisto_log_expression_{gene_set}
compositeTrack on
group regulation
shortLabel {gene_set} Expression
longLabel Log Scale Normalized Expression (Kallisto)
type bed 3
noInherit on
dragAndDrop subTracks
subGroup1 view Views Expression=Expression
subGroup2 genome Genome {genome_string}
subGroup3 tissueType Tissue {tissue_string}
sortOrder view=+ genome=+ tissueType=+

"""


composite_track = """    track {genome}_kallisto_log_expression_{gene_set}
    shortLabel {genome} logExpression
    view Expression
    visibility hide
    subTrack kallisto_log_expression_{gene_set}
    spectrum on
    scoreMin 100
    scoreMax 650
    color 45,30,61
    altColor 200,30,61
    allButtonPair on
    dragAndDrop subTracks

"""

per_bed_track = """        track {genome}_{tissue}_kallisto_expression_{gene_set}
        shortLabel {tissue} logExpression
        longLabel {genome} {tissue} logExpression ({gene_set})
        bigDataUrl {data_path}
        subGroups view=Expression genome=g{genome} tissueType=t{tissue}
        type bigBed 12
        parent {genome}_kallisto_log_expression_{gene_set}

"""

def find_tissues(file_map):
    return " ".join(sorted(set(["t{0}={0}".format(t) for g in file_map for t in file_map[g].iterkeys()])))


def find_genomes(file_map):
    return " ".join(sorted(["g{0}={0}".format(g) for g in file_map.keys()]))


def walk_bed_dir(bed_dir):
    file_map = {}
    for base_path, dirs, files in os.walk(bed_dir):
        if files:
            files = [x for x in files if x.endswith("bb")]
            assert len(files) == 1
            gene_set, genome, tissue = base_path.split("/")[-3:]
            if gene_set not in file_map:
                file_map[gene_set] = {}
            if genome not in file_map[gene_set]:
                file_map[gene_set][genome] = {}
            if tissue not in file_map[gene_set][genome]:
                file_map[gene_set][genome][tissue] = os.path.join(base_path, files[0])
    return file_map


def write_trackdb(file_map, out_handle):
    for gene_set in file_map:
        tissues = find_tissues(file_map[gene_set])
        genomes = find_genomes(file_map[gene_set])
        out_handle.write(per_gene_set_super_trackline.format(gene_set=gene_set, genome_string=genomes, tissue_string=tissues))
        for genome in file_map[gene_set]:
            out_handle.write(composite_track.format(genome=genome, gene_set=gene_set))
            for tissue, bed_path in file_map[gene_set][genome].iteritems():
                out_handle.write(per_bed_track.format(genome=genome, gene_set=gene_set, tissue=tissue, data_path=bed_path))


def main():
    args = parse_args()
    target_file = "trackDb/{0}/Mus{0}_{1}/kallistoExpression.trackDb.ra".format(args.ref_genome, args.assembly_version)
    file_map = walk_bed_dir(bed_dir)
    with open(target_file, "w") as outf:
        write_trackdb(file_map, outf)



if __name__ == "__main__":
    main()