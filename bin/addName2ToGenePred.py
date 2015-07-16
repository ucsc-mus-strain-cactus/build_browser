#!/usr/bin/env python
"""A tiny script to add the name2 field to each of the genes in a
genePred file, given the sort of transcript name munging used
(augustus, transmap, etc.).
"""
from argparse import ArgumentParser
import re

def parse_args():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("genePredFile", help="genePred formatted file")
    parser.add_argument("nameType", choices=["augustus", "transmap"])
    return parser.parse_args()

def main():
    opts = parse_args()
    with open(opts.genePredFile) as f:
        for line in f:
            fields = line.strip().split("\t")
            name = fields[0]
            pattern = r''
            if opts.nameType == 'augustus':
                pattern = r'aug-([0-9]+-|)(?P<name2>.*)-[0-9]+'
            elif opts.nameType == 'transmap':
                pattern = r'(?P<name2>.*)-[0-9]+'
            match = re.search(pattern, name)
            if not match:
                raise RuntimeError("name %s does not fit expected pattern %s" \
                                   % (name, opts.nameType))
            name2 = match.groupdict()['name2']
            # name2 is the 12th field
            fields[11] = name2
            print "\t".join(fields)

if __name__ == '__main__':
    main()
