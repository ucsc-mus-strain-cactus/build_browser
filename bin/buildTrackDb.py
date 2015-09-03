#!/usr/bin/env python
"""Create per-organism or per-genome assemble trackDb files for standard
tracks.  This has special handling for snake tracks.  If the output directory
contains files in the form *.trackDb.ra, include directives will be added.
"""

import sys, os, argparse, glob
from string import Template

def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref_genome", default=None)
    parser.add_argument("--genomes", nargs="+", default=None)
    parser.add_argument("--this_genome", default=None)
    parser.add_argument("--halOrLod", default=None,
                        help="path to hal file or lod.txt file")
    parser.add_argument("trackDbFile")
    args = parser.parse_args()
    if (((args.genomes is not None) or (args.this_genome is not None) or (args.ref_genome is not None) or (args.halOrLod is not None))
        and ((args.genomes is None) or (args.this_genome is None) or (args.ref_genome is None) or (args.halOrLod is None))):
        parser.error("must specify all or none of --ref_genome, --genomes, --this_genome, and --halOrLod")
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

snakeTemplate = Template("""track snake${genome}
longLabel ${genome}
shortLabel ${genome}
otherSpecies ${genome}
parent cactus on
priority ${pri}
bigDataUrl ${halOrLod}
type halSnake

""")

# takes srcGenome name description
chainNetRefTemplate = Template("""
track chainNet${name}
compositeTrack on
shortLabel ${description} Chain/Net
longLabel ${description} Chain and Net Alignments
subGroup1 view Views chain=Chain net=Net
dragAndDrop subTracks
visibility hide
group compGeno
noInherit on
priority 205.3
color 0,0,0
altColor 255,255,0
type bed 3
sortOrder view=+
#matrix 16 100,-179,-37,-144,-179,96,-195,-37,-37,-195,96,-179,-144,-37,-179,100
#matrixHeader A, C, G, T
otherDb ${srcGenome}
chainMinScore 5000
chainLinearGap medium
spectrum on
html chainNet

    track chainNet${name}Viewchain
    shortLabel Chain
    view chain
    visibility pack
    parent chainNet${name}
    spectrum on

        track chain${name}
        parent chainNet${name}Viewchain
        subGroups view=chain
        shortLabel ${description} Chain
        longLabel ${description} Chained Alignments
        type chain ${srcGenome}
        html chainNet

    track chainNet${name}Viewnet
    shortLabel Net
    view net
    visibility dense
    parent chainNet${name}

        track net${name}
        parent chainNet${name}Viewnet
        subGroups view=net
        shortLabel ${description} Net
        longLabel ${description} Alignment Net
        type netAlign ${srcGenome} chain${name}
        html chainNet

""")

def getIncludeFiles(trackDbDir):
    "get include files, excluding directory"
    return [os.path.basename(t) for t in glob.glob(trackDbDir+"/*.trackDb.ra")]


def addSnakeTracks(trackDbFh, genomes, halOrLod):
    basePri = 15
    trackDbFh.write(cactusComp)
    for pri, genome in enumerate(genomes):
        trackDbFh.write(snakeTemplate.substitute(genome=genome, pri=basePri+pri, halOrLod=halOrLod))

def addNetChainTracks(trackDbFh, refGenome):
    trackDbFh.write(chainNetRefTemplate.substitute(srcGenome=refGenome, name=refGenome, description=refGenome))
    trackDbFh.write(chainNetRefTemplate.substitute(srcGenome=refGenome, name="Syn"+refGenome, description=refGenome+" Syntenic"))

def createTrackDb(trackDbFh, refGenome, thisGenome, genomes, halOrLod, trackDbDir):
    if (refGenome != None) and (refGenome != thisGenome):
        addNetChainTracks(trackDbFh, refGenome)
    if genomes != None:
        addSnakeTracks(trackDbFh, genomes, halOrLod)
    for inc in getIncludeFiles(trackDbDir):
        trackDbFh.write("include " + inc + "\n")

        
def main():
    args = parse_args()
    trackDbDir = os.path.dirname(args.trackDbFile)
    with file(args.trackDbFile, "w") as trackDbFh:
        createTrackDb(trackDbFh, args.ref_genome, args.this_genome, args.genomes, args.halOrLod, trackDbDir)


if __name__ == "__main__":
    main()
