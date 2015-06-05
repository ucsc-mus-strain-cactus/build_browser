"""
Produces trackDb files for the STAR alignments star generated both against the reference (by Ian)
and against the individual assemblies (1505 release from Sanger).
The individual assembly does not have wiggle tracks.
"""

import sys
import os
import argparse
from collections import OrderedDict

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference genome', required=True)
    parser.add_argument('--genome', help='genome', required=True)
    return parser.parse_args()

# alignments done against reference by Ian
folder_ian_star = "/cluster/home/ifiddes/mus_strain_data/pipeline_data/rnaseq/STAR_output"
# individual assembly BAM path (1505 release)
folder_1505 = "/hive/groups/recon/projs/mus_strain_cactus/data/assembly_rel_1505/bam/ftp-mouse.sanger.ac.uk/REL-1505-RNA-Seq/REL-1504-renamed"



composite_trackline_reference = """track rnaseq_star
compositeTrack on
group regulation
shortLabel RNAseq
longLabel RNAseq analysis and raw data
subGroup1 view Views Expression=Expression Junctions=Splice_Junctions Alignments=Alignments
subGroup2 genome Genome {genome_string}
subGroup3 tissueType Tissue {tissue_string}
dimensions dimensionX=genome dimensionY=tissueType
sortOrder view=+ tissueType=+
dragAndDrop subTracks
type bed 3
noInherit on

"""

composite_trackline_individual = """track rnaseq_star
compositeTrack on
group regulation
shortLabel RNAseq
longLabel RNAseq analysis and raw data
subGroup1 view Views Junctions=Splice_Junctions Alignments=Alignments
subGroup2 tissueType Tissue {tissue_string}
dimensions dimensionX=tissueType dimensionY=view
sortOrder view=- tissueType=+
dragAndDrop subTracks
type bed 3
noInherit on

"""

raw_sig = """    track {genome}_expression_star
    shortLabel {genome}_Expression
    view Expression
    visibility pack
    subTrack rnaseq_star
    maxHeightPixels 100:24:16
    autoScale on

"""

raw_sig_multi_wig = """        track {genome}_{tissue}_expression_star
        shortLabel Overlaid Expression
        container multiWig
        parent {genome}_expression_star
        subGroups view=Expression genome=g{genome} tissueType=t{tissue}
        type bigWig
        aggregate transparentOverlay
        windowingFunction mean+whiskers
        transformFunc NONE

"""

base_wig_trackline = """            track wig_star_{genome}_{institute}_{tissue}_{experiment}_{strand}
            longLabel {genome} {tissue} {strand}-strand Expression ({institute}, {experiment})
            shortLabel {genome}_{tissue}_{strand}-strand_Expression
            parent {genome}_{tissue}_expression_star
            type bigWig
            bigDataUrl {data_path}
            color 153,38,0
            altColor 0,115,153
            negateValues {negate}

"""

junctions = """    track {genome}_splice_junctions_star
    shortLabel Splice Junctions
    view Junctions
    visibility hide
    subTrack rnaseq_star

"""

base_sj_trackline = """        track {experiment}_splice_junctions_star
        longLabel {genome} {tissue} Splice Junctions ({institute}, {experiment})
        shortLabel {genome}_{tissue}_Splice_Junctions
        parent {genome}_splice_junctions_star
        subGroups view=Junctions genome=g{genome} tissueType=t{tissue}
        type bed 12

"""

alignments = """    track {genome}_rnaseq_alignments_star
    shortLabel Raw Alignments
    view Alignments
    visibility hide
    subTrack rnaseq_star

"""

base_bam_trackline = """        track bam_star_{genome}_{institute}_{tissue}_{experiment}
        longLabel {genome} {tissue} RNASeq ({institute}, {experiment})
        shortLabel {genome}_{tissue}_RNASeq_({institute},_{experiment})
        bigDataUrl {data_path}
        parent {genome}_rnaseq_alignments_star
        subGroups view=Alignments genome=g{genome} tissueType=t{tissue}
        type bam
        indelDoubleInsert on
        indelQueryInsert on
        showNames off
        pairEndsByName on

"""

reference_file_paths = OrderedDict([["(+)", "Signal.UniqueMultiple.str1.out.renamed.bw"], 
                         ["(-)", "Signal.UniqueMultiple.str2.out.renamed.bw"],
                         ["bam", "Aligned.sortedByCoord.out.bam"]])


def build_map(file_map, paths, genome, institute, tissue, experiment):
    if genome not in file_map:
        file_map[genome] = {}
    if tissue not in file_map[genome]:
        file_map[genome][tissue] = {}
    if institute not in file_map[genome][tissue]:
        file_map[genome][tissue][institute] = {}
    file_map[genome][tissue][institute][experiment] = paths
    return file_map


def walk_source_dir(source_dir, ref=False, genome=None):
    file_map = {}
    for base_path, dirs, files in os.walk(source_dir):
        if files:
            if ref:
                try:
                    genome, institute, tissue, experiment = base_path.replace(source_dir, "").split("/")[1:]
                except ValueError:
                    raise RuntimeError("Looks like the directory structure is not what was expected.")
            else:
                try:
                    institute, tissue, experiment = base_path.replace(source_dir, "").split("/")[1:]
                except ValueError:
                    raise RuntimeError("Looks like the directory structure is not what was expected.")                
            if ref:
                path_map = OrderedDict([(x, os.path.realpath(os.path.join(base_path, y))) for x, y in reference_file_paths.iteritems()])
                assert all([os.path.exists(x) for x in path_map.values()]), path_map
            else:
                path_map = {"bam": os.path.realpath(os.path.join(base_path, reference_file_paths["bam"]))}
            build_map(file_map, path_map, genome, institute, tissue, experiment)
    return file_map


def find_tissues(file_map):
    return " ".join(sorted(["t{0}={0}".format(x) for x in {y for x in file_map.itervalues() for y in x.keys()}]))


def find_genomes(file_map):
    return " ".join(sorted(["g{0}={0}".format(x) for x in file_map.keys()]))


def make_signal_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(raw_sig.format(genome=genome))
        for tissue in file_map[genome]:
            target_handle.write(raw_sig_multi_wig.format(genome=genome, tissue=tissue))
            for institute in file_map[genome][tissue]:
                for experiment in file_map[genome][tissue][institute]:
                    experiment_map = file_map[genome][tissue][institute][experiment]
                    for data_type, path in experiment_map.iteritems():
                        if data_type == "(+)":
                            negate = "off"
                        elif data_type == ("(-)"):
                            negate = "on"
                        else:
                            continue
                        target_handle.write(base_wig_trackline.format(negate=negate, data_path=path, strand=data_type, 
                                                                      genome=genome, institute=institute,
                                                                      experiment=experiment, tissue=tissue))


def make_bam_tracks(file_map, target_handle, ref=False):
    for genome in file_map:
        target_handle.write(alignments.format(genome=genome))
        for tissue in file_map[genome]:
            for institute in file_map[genome][tissue]:
                for experiment in file_map[genome][tissue][institute]:
                    path = file_map[genome][tissue][institute][experiment]["bam"]
                    line = base_bam_trackline.format(data_path=path, genome=genome, institute=institute,
                                                     experiment=experiment, tissue=tissue)
                    if not ref:
                        line = line.replace(" genome=g{}".format(genome), "")
                    target_handle.write(line)


def make_sj_tracks(file_map, target_handle, ref=False):
    for genome in file_map:
        target_handle.write(junctions.format(genome=genome))
        for tissue in file_map[genome]:
            for institute in file_map[genome][tissue]:
                for experiment in file_map[genome][tissue][institute]:
                    line = base_sj_trackline.format(genome=genome, institute=institute, tissue=tissue, 
                                                    experiment=experiment)
                    if not ref:
                        line = line.replace(" genome=g{}".format(genome), "")
                    target_handle.write(line)


def make_ref_tracks(file_map, file_handle):
    genome_string = find_genomes(file_map)
    tissue_string = find_tissues(file_map)
    file_handle.write(composite_trackline_reference.format(genome_string=genome_string, tissue_string=tissue_string))
    make_signal_tracks(file_map, file_handle)
    make_bam_tracks(file_map, file_handle, ref=True)
    make_sj_tracks(file_map, file_handle, ref=True)


def make_individual_tracks(file_map, file_handle):
    tissue_string = find_tissues(file_map)
    file_handle.write(composite_trackline_individual.format(tissue_string=tissue_string))
    make_bam_tracks(file_map, file_handle, ref=False)
    make_sj_tracks(file_map, file_handle, ref=False)    


def main():
    args = parse_args()
    target_file_template = "trackDb/{0}/Mus{0}_{1}/starTracks.trackDb.ra"
    if args.genome == args.ref_genome:
        file_map = walk_source_dir(folder_ian_star, ref=True)
        target_file = target_file_template.format(args.ref_genome, args.assembly_version)
        make_ref_tracks(file_map, open(target_file, "w"))
    elif args.assembly_version == "1504":
        genome_dir = os.path.join(folder_1505, args.genome)
        assert os.path.exists(genome_dir), genome_dir
        file_map = walk_source_dir(genome_dir, ref=False, genome=args.genome)
        target_file = target_file_template.format(args.genome, args.assembly_version)
        make_individual_tracks(file_map, open(target_file, "w"))
    else:
        print "This script was called on a release that was not 1504 or not on the reference. Did nothing."
        sys.exit(1)


if __name__ == "__main__":
    main()
