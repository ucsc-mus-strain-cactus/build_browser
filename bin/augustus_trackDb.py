"""
Produces trackDb files for the Augustus tracks generated by Mario.
"""

import sys
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference genome', required=True)
    parser.add_argument('--genome', help='genome', required=True)
    parser.add_argument('--base_data_dir', required=True)
    return parser.parse_args()

supertrack = """track augustus
superTrack on show
shortLabel AUGUSTUS
longLabel AUGUSTUS gene predictions
group genes
html /hive/groups/recon/projs/mus_strain_cactus/pipeline_data/comparative/1504/augustus/augustus.html

"""

tm = """    track augustusTM
    superTrack augustus pack
    shortLabel AUGUSTUS using TransMap
    longLabel AUGUSTUS using TransMap coding genes
    group genes
    type genePred
    priority 1.0
    color 200,0,0
    visibility hide

"""

tmr = """    track augustusTMR
    superTrack augustus pack
    shortLabel AUGUSTUS using TransMap and RNA-Seq
    longLabel AUGUSTUS using TransMap coding genes and RNA-Seq
    group genes
    type genePred
    priority 1.0
    color 255,0,0
    visibility pack

"""

searchtmr = """
# search by ensembl id
searchName augustusTMR_ens_id
searchTable augustusTMR
searchMethod prefix
searchType genePred
termRegex ENSMUST[0-9.]+
query select chrom, txStart, txEnd, name from %s where name2 like '%s%%'

# search by gene name
searchName augustusTMR_geneName
searchTable augustusTMR
searchMethod prefix
searchType genePred
query select chrom, txStart, txEnd, name from %s where name2 like '%s'
xrefTable MusC57B6J_1504.wgEncodeGencodeAttrsVM4
xrefQuery select transcriptId,geneName from %s where geneName like '%s%%'

# search by augustus ID
searchName augustusTMR
searchTable augustusTMR
searchMethod prefix
searchType genePred
termRegex aug-([0-9]+-|)ENSMUST[0-9.]+-[0-9]+

"""

searchcgp = """# search by CGP id
searchName augustusCGP
searchTable augustusCGP
searchMethod prefix
searchType genePred
termRegex g[0-9]+.t[0-9]+

"""

searchtm = """# search by ensembl id
searchName augustusTM_ens_id
searchTable augustusTM
searchMethod prefix
searchType genePred
termRegex ENSMUST[0-9.]+
query select chrom, txStart, txEnd, name from %s where name2 like '%s%%'

# search by gene name
searchName augustusTM_geneName
searchTable augustusTM
searchMethod prefix
searchType genePred
query select chrom, txStart, txEnd, name from %s where name2 like '%s'
xrefTable MusC57B6J_1504.wgEncodeGencodeAttrsVM4
xrefQuery select transcriptId,geneName from %s where geneName like '%s%%'

# search by augustus ID
searchName augustusTM
searchTable augustusTM
searchMethod prefix
searchType genePred
termRegex ENSMUST[0-9.]+-[0-9]+

"""

cgp = """    track augustusCGP
    superTrack augustus pack
    shortLabel comparative AUGUSTUS (chr11 only)
    longLabel comparative AUGUSTUS (chr11 only)
    group genes
    type genePred
    priority 1.0
    color 100,150,250
    visibility pack

"""

cgp_full = """    track augustusCGPFull
    superTrack augustus pack
    shortLabel whole-genome comparative AUGUSTUS
    longLabel whole-genome comparative AUGUSTUS
    group genes
    type bigGenePred
    bigDataUrl {}
    priority 1.0
    color 100,150,250
    visibility pack

"""


def make_ref_tracks(file_handle, full_cgp_path, assembly_version):
    file_handle.write(supertrack)
    if assembly_version == "1504":
        file_handle.write(cgp)
    file_handle.write(cgp_full.format(full_cgp_path))
    file_handle.write(searchcgp)


def make_individual_tracks(file_handle, full_cgp_path, assembly_version):
    file_handle.write(supertrack)
    if assembly_version == "1504":
        dirs = ["tm", "tmr", "cgp"]
    elif assembly_version == "1509":
        dirs = ["tmr"]
    for d in dirs:
        file_handle.write(eval(d))
    file_handle.write(cgp_full.format(full_cgp_path))
    # have to write search defs after everything else
    for d in dirs:
        file_handle.write(eval('search' + d))


def make_rat_track(file_handle, full_cgp_path):
    file_handle.write(supertrack)
    file_handle.write(cgp_full.format(full_cgp_path))


def main():
    args = parse_args()
    target_file_template = "trackDb/{0}/Mus{0}_{1}/augustus.trackDb.ra"
    if args.assembly_version == "1504":
        full_cgp_path = os.path.join(args.base_data_dir, "Mus{}_{}.cgp.jg.bb".format(args.genome, args.assembly_version))
    elif args.assembly_version == "1509":
        full_cgp_path = os.path.join(args.base_data_dir, "{}.cgp.bb".format(args.genome, args.assembly_version))
    if args.genome == args.ref_genome:
        target_file = target_file_template.format(args.ref_genome, args.assembly_version)
        with open(target_file, "w") as outf:
            make_ref_tracks(outf, full_cgp_path, args.assembly_version)
    elif args.assembly_version == "1504" or args.assembly_version == "1509":
        target_file = target_file_template.format(args.genome, args.assembly_version)
        with open(target_file, "w") as outf:
            if args.genome == "Rattus":
                make_rat_track(outf, full_cgp_path)
            else:
                make_individual_tracks(outf, full_cgp_path, args.assembly_version)
    else:
        print "This script was called on a release that was not 1504/1509 or not on the reference. Did nothing."
        sys.exit(1)


if __name__ == "__main__":
    main()
