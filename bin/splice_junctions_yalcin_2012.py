"""
Produces trackDb files for the chr19 splice junctions seen in Yalcin et al 2012
Which are present at /hive/groups/recon/projs/mus_strain_cactus/data/yalcin_structural_variants
These BEDs are lifted over from mm9 to mm10 by Joel
"""

import sys
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference strain (C57B6J)', required=True)
    return parser.parse_args()


bed_dir = "/hive/groups/recon/projs/mus_strain_cactus/data/yalcin_structural_variants"


composite_track = """track yalcin_structural_variants
compositeTrack on
shortLabel Structural Variants
longLabel Gold Standard Structural Variants (Yalcin et al 2012)
allButtonPair on
dragAndDrop subTracks
type bed 4
visibility hide

"""

per_bed_track = """    track {genome}_yalcin_svs
    shortLabel {genome}
    longLabel {genome} Structural Variants
    type bed 4
    parent yalcin_structural_variants

"""


def main():
    args = parse_args()
    target_file = "trackDb/{0}/Mus{0}_{1}/spliceJunctions.trackDb.ra".format(args.ref_genome, args.assembly_version)
    with open(target_file, "w") as outf:
        outf.write(composite_track)
        for bed in os.listdir(bed_dir):
            assert bed.endswith(".bed")
            genome = bed.split("_")[0].split(".")[0]
            outf.write(per_bed_track.format(genome=genome))


if __name__ == "__main__":
    main()
