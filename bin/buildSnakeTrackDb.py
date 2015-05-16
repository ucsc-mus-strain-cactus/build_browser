#!/usr/bin/env python
"""
Create per-genome assemble trackDb files with snake tracks.
If the output directory contains files in the form *.trackDb.ra,
include directives will be added.
"""

import sys, os, argparse, glob

def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--genomes", nargs="+", required=True)
    parser.add_argument("--this_genome", required=True)
    parser.add_argument("--hal", required=True)
    parser.add_argument("trackDbFile")
    args = parser.parse_args()
    if args.this_genome not in args.genomes:
        parser.error(args.this_genome + " not in --genomes option")
    tmp = set(args.genomes)
    tmp.remove(args.this_genome)
    args.genomes = sorted(tmp)
    return args

comp = """track cactus
compositeTrack on
shortLabel Cactus Alignments
longLabel Snake Track of progressiveCactus Alignments
group compGeno
type bed 3
priority 2
visibility dense
dragAndDrop subTracks

"""

template = """track snake{0}
longLabel {0}
shortLabel {0}
otherSpecies {0}
parent cactus on
priority {1}
bigDataUrl {2}
type halSnake

"""

def getIncludeFiles(trackDbFile):
    "get include files, excluding directory"
    return [os.path.basename(t) for t in glob.glob(os.path.dirname(trackDbFile)+"/*.trackDb.ra")]

def createSnakeTrackDb(genome, pri, hal, trackDbFile):
    with file(trackDbFile, "w") as fh:
        fh.write(comp)
        fh.write(template.format(genome, pri, hal))
        for inc in getIncludeFiles(trackDbFile):
            fh.write("include " + inc + "\n")

def main():
    args = parse_args()
    basePri = 15
    print comp
    for i, g in enumerate(args.genomes):
        createSnakeTrackDb(g, basePri + i, args.hal, args.trackDbFile)

if __name__ == "__main__":
    main()
