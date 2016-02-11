"""
Produces trackDb files for the phastCons/dless calls
"""

import argparse


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference strain (C57B6J)', required=True)
    parser.add_argument('--wigpath', help='phastCons wiggle path', required=True)
    return parser.parse_args()


trackline = """track conservation_tracks
superTrack on
shortLabel Conservation
longLabel PHAST Conservation
visibility hide
group compGeno

    track dless
    superTrack conservation_tracks
    shortLabel dless
    longLabel Detection of Lineage Specific Selection
    type bed 6

    track phast_bed
    superTrack conservation_tracks
    shortLabel Phast Ultra Conserved
    longLabel PhastCons Ultra Conserved Regions
    type bed 6

    track phast_wig
    superTrack conservation_tracks
    shortLabel Phast Conservation
    longLabel PhastCons Conservation Scores
    type bigWig
    bigDataUrl {}

"""


def main():
    args = parse_args()
    target_file = "trackDb/{0}/Mus{0}_{1}/structuralVariants.trackDb.ra".format(args.ref_genome, args.assembly_version)
    with open(target_file, "w") as outf:
        outf.write(trackline.format(args.wigpath))


if __name__ == "__main__":
    main()
