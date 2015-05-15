import sys, os, argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--genomes", nargs="+", required=True)
    parser.add_argument("--this_genome", required=True)
    parser.add_argument("--hal", required=True)
    args = parser.parse_args()
    assert args.this_genome in args.genomes
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

def main():
    args = parse_args()
    basePri = 15
    print comp
    for i, g in enumerate(args.genomes):
        print template.format(g, basePri + i, args.hal)

if __name__ == "__main__":
    main()
