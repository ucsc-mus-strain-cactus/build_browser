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

comp = ("track cactus\ncompositeTrack on\nshortLabel Cactus Alignments\nlongLabel Snake Track of "
        "progressiveCactus Alignments\npriority 2\nvisibility dense\ndragAndDrop subTracks\n\n")

template = ("track snake{0}\nlongLabel {0}\nshortLabel {0}\notherSpecies {0}\nparent cactus on\npriority {1}\n"
            "bigDataUrl {2}\ntype halSnake\n")

def main():
    args = parse_args()
    print comp
    for i, g in enumerate(args.genomes):
        print template.format(g, i + 15, args.hal)

if __name__ == "__main__":
    main()