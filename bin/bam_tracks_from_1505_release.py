"""
Produces trackDb files for all of the STAR-aligned RNAseq BAMs from the 1505 release
Will dig through /hive/groups/recon/projs/mus_strain_cactus/data/assembly_rel_1505/bam
And produces tracks for both everything-vs-reference and individual assemblies
"""

import sys
import os
import re
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    return parser.parse_args()

# maps assembly names used by Sanger to our names
genome_map = {'129S1_SvImJ': '129S1', 'AKR_J': 'AKRJ', 'C3H_HeJ': 'C3HHeJ', 'CAST_EiJ': 'CASTEiJ', 'DBA_2J': 'DBA2J',
              'NOD_ShiLtJ': 'NODShiLtJ', 'PWK_PhJ': 'PWKPhJ', 'WSB_EiJ': 'WSBEiJ', 'A_J': 'AJ', 'BALB_cJ': 'BALBcJ',
              'C57BL_6NJ': 'C57B6NJ', 'CBA_J': 'CBAJ', 'LP_J': 'LPJ', 'NZO_HlLtJ': 'NZOHlLtJ', 'SPRET_EiJ': 'SPRETEiJ',
              'CAROLI_EiJ': 'CAROLIEiJ'}

# used to isolate experiment names from path
r = re.compile('^[a-zA-Z]+[0-9]+')

base_bam_trackline = """        track {genome}_{institute}_{tissue}_{experiment}
        longLabel {genome} {tissue} BAM ({institute})
        shortLabel {genome} {tissue} BAM ({institute})
        bigDataUrl {bam_path}
        parent {genome}_{tissue}
        type bam
        indelDoubleInsert on
        indelQueryInsert on
        showNames off
        pairEndsByName on

"""

per_tissue_composite_trackline = """    track {genome}_{tissue}
    compositeTrack on
    shortLabel {genome} {tissue} BAMs
    longLabel {genome} {tissue} BAMs
    parent {genome}_BAMs
    type bam
    allButtonPair on
    dragAndDrop subTracks

"""

per_genome_super_trackline = """track {genome}_BAMs
superTrack on
group BAMs
shortLabel {genome} RNAseq raw BAM alignments
longLabel {genome} RNAseq raw BAM alignments

"""


def walk_source_dir(source_dir):
    final_map = {}
    for base_path, dirs, files in os.walk(source_dir):
        if files:
            bams = [os.path.join(source_dir, base_path, x) for x in files if x.endswith(".bam")]
            assert bams
            try:
                genome, institute, tissue = base_path.replace(source_dir, "").split("/")[1:]
            except ValueError:
                raise RuntimeError("Looks like the directory structure is not what was expected.")
            new_genome = genome_map[genome]
            if new_genome not in final_map:
                final_map[new_genome] = {}
            if tissue not in final_map[new_genome]:
                final_map[new_genome][tissue] = {}
            if institute not in final_map[new_genome][tissue]:
                final_map[new_genome][tissue][institute] = bams
    return final_map
             

def make_reference_tracks(source_dir, target_file, assembly_version):
    final_map = walk_source_dir(source_dir)
    with open(target_file, 'w') as outf:
        for genome in final_map:
            outf.write(per_genome_super_trackline.format(genome=genome))
            for tissue in final_map[genome]:
                outf.write(per_tissue_composite_trackline.format(genome=genome, tissue=tissue))
                for institute, bams in final_map[genome][tissue].iteritems():
                    for bam_path in bams:
                        match = re.findall(r, os.path.basename(bam_path))
                        try:
                            assert len(match) == 1
                        except AssertionError:
                            match = os.path.basename(bam_path).split(".")
                        experiment = match[0]
                        outf.write(base_bam_trackline.format(genome=genome, tissue=tissue, institute=institute, 
                                                             bam_path=bam_path, experiment=experiment))
    # don't add it multiple times
    tmp = "".join(open("trackDb/C57B6J/MusC57B6J_{}/trackDb.ra".format(assembly_version)).readlines())
    if "include bamTracks.trackDb.ra" not in tmp:
        with open("trackDb/C57B6J/MusC57B6J_{}/trackDb.ra".format(assembly_version), "a") as outf:
            outf.write("\ninclude bamTracks.trackDb.ra\n")

def make_individual_tracks(source_dir, assembly_version):
    final_map = walk_source_dir(source_dir)
    for genome in final_map:
        target_file = "trackDb/{0}/Mus{0}_{1}/bamTracks.trackDb.ra".format(genome)
        with open(target_file, 'w') as outf:
            outf.write(per_genome_super_trackline.format(genome=genome))
            for tissue in final_map[genome]:
                outf.write(per_tissue_composite_trackline.format(genome=genome, tissue=tissue))
                for institute, bams in final_map[genome][tissue].iteritems():
                    for bam_path in bams:
                        match = re.findall(r, os.path.basename(bam_path))
                        try:
                            assert len(match) == 1
                        except AssertionError:
                            match = os.path.basename(bam_path).split(".")
                        experiment = match[0]
                        outf.write(base_bam_trackline.format(genome=genome, tissue=tissue, institute=institute, 
                                                             bam_path=bam_path, experiment=experiment))
    for genome in final_map:
        # don't add it multiple times
        tmp = "".join(open("trackDb/C57B6J/MusC57B6J_{}/trackDb.ra".format(assembly_version)).readlines())
        if "include bamTracks.trackDb.ra" not in tmp:
            with open("trackDb/{0}/Mus{0}_{1}/trackDb.ra".format(genome, assembly_version), "a") as outf:
                outf.write("\ninclude bamTracks.trackDb.ra\n") 


def main():
    args = parse_args()
    make_reference_tracks("/hive/groups/recon/projs/mus_strain_cactus/data/assembly_rel_1505/bam/ftp-mouse.sanger.ac.uk"
                          "/REL-1505-RNA-Seq/GRCm38", 
                          "trackDb/C57B6J/MusC57B6J_{}/bamTracks.trackDb.ra".format(args.assembly_version),
                          args.assembly_version)
    if args.assembly_version == "1504":
        make_individual_tracks("/hive/groups/recon/projs/mus_strain_cactus/data/assembly_rel_1505/bam/ftp-mouse.sanger."
                               "ac.uk/REL-1505-RNA-Seq/REL-1504-chromosomes", args.assembly_version)       


if __name__ == "__main__":
    main()