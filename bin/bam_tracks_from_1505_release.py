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
    parser.add_argument('--genome', help='genome we care about right now', required=True)
    parser.add_argument('--ref_genome', help='reference genome', required=True)
    return parser.parse_args()

# reference BAM path
reference_bam_path = "/hive/groups/recon/projs/mus_strain_cactus/data/assembly_rel_1505/bam/ftp-mouse.sanger.ac.uk/REL-1505-RNA-Seq/GRCm38"
# individual assembly BAM path (1505 release)
assembly_bam_path = "/hive/groups/recon/projs/mus_strain_cactus/data/assembly_rel_1505/bam/ftp-mouse.sanger.ac.uk/REL-1505-RNA-Seq/REL-1504-chromosomes"

# maps assembly names used by Sanger to our names
genome_map = {'129S1_SvImJ': '129S1', 'AKR_J': 'AKRJ', 'C3H_HeJ': 'C3HHeJ', 'CAST_EiJ': 'CASTEiJ', 'DBA_2J': 'DBA2J',
              'NOD_ShiLtJ': 'NODShiLtJ', 'PWK_PhJ': 'PWKPhJ', 'WSB_EiJ': 'WSBEiJ', 'A_J': 'AJ', 'BALB_cJ': 'BALBcJ',
              'C57BL_6NJ': 'C57B6NJ', 'CBA_J': 'CBAJ', 'LP_J': 'LPJ', 'NZO_HlLtJ': 'NZOHlLtJ', 'SPRET_EiJ': 'SPRETEiJ',
              'CAROLI_EiJ': 'CAROLIEiJ', "Pahari_EiJ": "PAHARIEiJ"}

# used to isolate experiment names from path
r = re.compile('^[a-zA-Z]+[0-9]+')

base_bam_trackline = """        track rnaseq_sanger_{genome}_{institute}_{tissue}_{experiment}
        longLabel {genome} {tissue} RNASeq ({institute}, {experiment})
        shortLabel {genome} {tissue} RNASeq
        bigDataUrl {bam_path}
        parent rnaseq_sanger_{genome}_{tissue}
        type bam
        indelDoubleInsert on
        indelQueryInsert on
        showNames off
        pairEndsByName on

"""

per_tissue_composite_trackline = """    track rnaseq_sanger_{genome}_{tissue}
    compositeTrack on
    shortLabel {genome} {tissue} RNASeq
    longLabel {genome} {tissue} RNASeq
    parent rnaseq_sanger_{genome}
    type bam
    allButtonPair on
    dragAndDrop subTracks

"""

per_genome_super_trackline = """track rnaseq_sanger_{genome}
superTrack on
group regulation
shortLabel {genome} RNAseq raw alignments
longLabel {genome} RNAseq raw alignments (sanger)

"""


def walk_source_dir(source_dir):
    file_map = {}
    for base_path, dirs, files in os.walk(source_dir):
        if files:
            bams = [os.path.join(source_dir, base_path, x) for x in files if x.endswith(".bam")]
            assert bams
            try:
                genome, institute, tissue = base_path.replace(source_dir, "").split("/")[1:]
            except ValueError:
                raise RuntimeError("Looks like the directory structure is not what was expected.")
            new_genome = genome_map[genome]
            institute = institute.title()  # upper case first word
            tissue = tissue.title()
            if new_genome not in file_map:
                file_map[new_genome] = {}
            if tissue not in file_map[new_genome]:
                file_map[new_genome][tissue] = {}
            if institute not in file_map[new_genome][tissue]:
                file_map[new_genome][tissue][institute] = bams
    return file_map
             

def make_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(per_genome_super_trackline.format(genome=genome))
        for tissue in file_map[genome]:
            target_handle.write(per_tissue_composite_trackline.format(genome=genome, tissue=tissue))
            for institute, bams in file_map[genome][tissue].iteritems():
                for bam_path in bams:
                    match = re.findall(r, os.path.basename(bam_path))
                    if len(match) != 1:
                        experiment = os.path.basename(bam_path).split(".")[0]
                    else:
                        experiment = match[0]
                    target_handle.write(base_bam_trackline.format(genome=genome, tissue=tissue, institute=institute,
                                                         bam_path=bam_path, experiment=experiment))


def main():
    args = parse_args()
    target_file = "trackDb/{0}/Mus{0}_{1}/bamTracks.trackDb.ra".format(args.genome, args.assembly_version)
    assert args.assembly_version == "1504"
    assert args.genome != args.ref_genome
    with open(target_file, "w") as target_handle:
        # filter for only the target genome
        file_map = {x: y for x, y in walk_source_dir(assembly_bam_path).iteritems() if x == args.genome}
        make_tracks(file_map, target_handle) 


if __name__ == "__main__":
    main()
