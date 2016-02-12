"""
Produces trackDb files for the various SV calls produced from the alignment.

The tracks are all relative to and placed on the reference genome.
"""
import os
from argparse import ArgumentParser
from glob import glob

def parse_args():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference strain (C57B6J)', required=True)
    parser.add_argument('--halSVDir', help='directory containing halBranchMutation calls lifted onto ref')
    return parser.parse_args()

def write_hal_sv_tracks(halSVDir, outputFile):
    # First write the overall composite track that contains the calls for each target genome
    outputFile.write("""track hal_sv_calls
compositeTrack on
shortLabel HAL SV calls
longLabel Structural variant calls from halBranchMutations
allButtonPair on
dragAndDrop subtracks
type bed 4
visibility hide
group compGeno

""")
    # Next, write the tracks for each genome, that will contain the actual info
    for bedPath in glob(halSVDir + '/*.bed'):
        genome = os.path.basename(bedPath).split('.')[0]
        outputFile.write("""    track {genome}_hal_sv_calls
    shortLabel {genome}
    longLabel {genome} SVs called by halBranchMutations
    type bed 4
    parent hal_sv_calls

""".format(genome=genome))
        
def main():
    opts = parse_args()
    outputPath = "trackDb/{0}/Mus{0}_{1}/alignmentSVCalls.trackDb.ra".format(opts.ref_genome, opts.assembly_version)
    with open(outputPath, 'w') as output:
        if opts.halSVDir is not None:
            write_hal_sv_tracks(opts.halSVDir, output)

if __name__ == '__main__':
    main()
