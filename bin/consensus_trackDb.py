"""
Produces trackDb files for the consensus sets - both CGP and regular
"""

import sys
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--genome', help='genome', required=True)
    return parser.parse_args()


supertrack = """track consensus
superTrack on show
shortLabel consensus
longLabel consensus gene sets
group genes

"""


tmr = """    track TMR_consensus
    superTrack consensus pack
    shortLabel Consensus between transMap and AugustusTMR
    longLabel Consensus between transMap and AugustusTMR
    group genes
    type genePred
    priority 1.0
    color 255,0,0
    visibility pack

"""

cgp = """    track TMR_CGP_consensus
    superTrack consensus pack
    shortLabel consensus between transMap, AugustusTMR and augustusCGP
    longLabel consensus between transMap, AugustusTMR and augustusCGP
    group genes
    type genePred
    priority 1.0
    color 100,150,250
    visibility pack

"""


def make_track(file_handle):
    for x in [supertrack, tmr, cgp]:
        file_handle.write(x)


def main():
    args = parse_args()
    target_file_template = "trackDb/{0}/Mus{0}_{1}/consensus.trackDb.ra"
    if args.assembly_version == "1509":
        target_file = target_file_template.format(args.genome, args.assembly_version)
        with open(target_file, "w") as outf:
            make_track(outf)
    else:
        print "This script was called on a release that was not 1509. Did nothing."


if __name__ == "__main__":
    main()
