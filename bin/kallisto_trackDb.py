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
    parser.add_argument('--ref_strain', help='reference strain (C57B6J)', required=True)
    return parser.parse_args()


bed_dir = "/hive/groups/recon/projs/mus_strain_cactus/pipeline_data/rnaseq/log_expression_bedfiles"


per_gene_set_super_trackline = """track kallisto_log_expression_{gene_set}
superTrack on
group Expression
shortLabel Log Scale Normalized Expression {gene_set} (Kallisto)
longLabel Log Scale Normalized Expression {gene_set} (Kallisto)

"""


composite_track = """    track {genome}_kallisto_log_expression_{gene_set}
    compositeTrack on
    shortLabel {genome} logExpression
    longLabel {genome} Log Scale Normalized Expression (Kallisto)
    allButtonPair on
    dragAndDrop subTracks
    visibility hide
    parent kallisto_log_expression_{gene_set}

"""

per_bed_track = """        track {genome}_{tissue}_kallisto_expression_{gene_set}
        shortLabel {tissue} logExpression
        longLabel {genome} {tissue} Log Scale Normalized Expression (Kallisto)
        type bed 12
        parent {genome}_kallisto_log_expression_{gene_set}

"""

def walk_bed_dir(bed_dir):
    file_map = {}
    for base_path, dirs, files in os.walk(bed_dir):
        if files:
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
        out_handle.write(per_gene_set_super_trackline.format(gene_set=gene_set))
        for genome in file_map[gene_set]:
            out_handle.write(composite_track.format(genome=genome, gene_set=gene_set))
            for tissue, bed_path in file_map[gene_set][genome].iteritems():
                out_handle.write(per_bed_track.format(genome=genome, gene_set=gene_set, tissue=tissue))


def main():
    args = parse_args()
    trackDb_path = os.path.join("trackDb", args.ref_strain, "Mus" + args.ref_strain + "_" + args.assembly_version)
    file_map = walk_bed_dir(bed_dir)
    with open(os.path.join(trackDb_path, "kallistoExpression.trackDb.ra"), "w") as outf:
        outf.write(composite_track)
        for bed in os.listdir(bed_dir):
            assert bed.endswith(".bed")
            genome = bed.split("_")[0].split(".")[0]
            outf.write(per_bed_track.format(genome=genome))
    tmp = "".join(open(os.path.join(trackDb_path, "trackDb.ra")).readlines())
    if "include kallistoExpression.trackDb.ra" not in tmp:
        with open(os.path.join(trackDb_path, "trackDb.ra"), "a") as outf:
            outf.write("\ninclude kallistoExpression.trackDb.ra\n")



if __name__ == "__main__":
    main()