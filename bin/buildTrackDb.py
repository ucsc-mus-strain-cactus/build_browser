#!/usr/bin/env python
"""Create per-organism or per-genome assemble trackDb files for standard
tracks.  This has special handling for snake tracks.  If the output directory
contains files in the form *.trackDb.ra, include directives will be added.
"""

import sys, os, argparse, glob

def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--genomes", nargs="+", default=None)
    parser.add_argument("--this_genome", default=None)
    parser.add_argument("--hal", default=None)
    parser.add_argument("trackDbFile")
    args = parser.parse_args()
    if (((args.genomes is not None) or (args.this_genome is not None) or (args.hal is not None))
        and ((args.genomes is None) or (args.this_genome is None) or (args.hal is None))):
        parser.error("must specify all or none of --genomes, --this_genome, and --hal")
    if args.this_genome is not None:
        if args.this_genome not in args.genomes:
            parser.error(args.this_genome + " not in --genomes option")
        tmp = set(args.genomes)
        tmp.remove(args.this_genome)
        args.genomes = sorted(tmp)
    return args

cactusComp = """track cactus
compositeTrack on
shortLabel Cactus Alignments
longLabel Snake Track of progressiveCactus Alignments
group compGeno
type bed 3
priority 2
visibility full
dragAndDrop subTracks

"""

snakeTemplate = """track snake{0}
longLabel {0}
shortLabel {0}
otherSpecies {0}
parent cactus on
priority {1}
bigDataUrl {2}
type halSnake

"""


def getIncludeFiles(trackDbDir):
    "get include files, excluding directory"
    return [os.path.basename(t) for t in glob.glob(trackDbDir+"/*.trackDb.ra")]


def addSnakeTracks(trackDbFh, genomes, hal, trackDbDir):
    basePri = 15
    trackDbFh.write(cactusComp)
    for pri, genome in enumerate(genomes):
        trackDbFh.write(snakeTemplate.format(genome, basePri+pri, hal))


def createTrackDb(trackDbFh, genomes, hal, trackDbDir):
    if genomes != None:
        addSnakeTracks(trackDbFh, genomes, hal, trackDbDir)
    for inc in getIncludeFiles(trackDbDir):
        trackDbFh.write("include " + inc + "\n")

        
def main():
    args = parse_args()
    trackDbDir = os.path.dirname(args.trackDbFile)
    with file(args.trackDbFile, "w") as trackDbFh:
        createTrackDb(trackDbFh, args.genomes, args.hal, trackDbDir)


if __name__ == "__main__":
    main()
