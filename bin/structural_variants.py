"""
Produces trackDb files for the structural variant calls found in
ftp://ftp-mouse.sanger.ac.uk/REL-1410-SV/
And munged to beds with the parse_SDP.py script.
"""

import sys
import os
import argparse


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference strain (C57B6J)', required=True)
    return parser.parse_args()


composite_track = """track structural_variants
compositeTrack on
shortLabel Structural Variants
longLabel Structural Variant Calls (Release 1410)
allButtonPair on
dragAndDrop subTracks
type bed 4
visibility hide
group compGeno

"""

per_bed_track = """    track {genome}_svs
    shortLabel {genome}
    longLabel {genome} Structural Variants
    type bed 4
    parent structural_variants

"""


def main():
    args = parse_args()
    target_file = "trackDb/{0}/Mus{0}_{1}/structuralVariants.trackDb.ra".format(args.ref_genome, args.assembly_version)
    with open(target_file, "w") as outf:
        outf.write(composite_track)
        for bed in os.listdir(bed_dir):
            assert bed.endswith(".bed")
            genome = bed.split("_")[0].split(".")[0]
            outf.write(per_bed_track.format(genome=genome))


if __name__ == "__main__":
    main()
