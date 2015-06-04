"""
Produces trackDb files for the STAR alignments star generated against the reference found at
/cluster/home/ifiddes/mus_strain_data/pipeline_data/rnaseq/STAR_output
"""

import sys
import os
import argparse
from collections import OrderedDict

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference genome', required=True)
    return parser.parse_args()

target_folder = "/cluster/home/ifiddes/mus_strain_data/pipeline_data/rnaseq/STAR_output"


composite_trackline = """track rnaseq_star
compositeTrack on
group expression
shortLabel RNAseq
longLabel RNAseq analysis and raw data
subGroup1 view Views Expression=Expression Junctions=Splice_Junctions Alignments=Alignments
subGroup2 genome Genome {genome_string}
subGroup3 tissueType Tissue {tissue_string}
dimensions dimensionX=genome dimensionY=tissueType
sortOrder view=- genome=+ tissueType=+
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

file_paths = OrderedDict([["(+)", "Signal.UniqueMultiple.str1.out.renamed.bw"], 
                         ["(-)", "Signal.UniqueMultiple.str2.out.renamed.bw"],
                         ["bam", "Aligned.sortedByCoord.out.bam"]])


def walk_source_dir(source_dir):
    file_map = {}
    for base_path, dirs, files in os.walk(source_dir):
        if files:
            path_map = OrderedDict([(x, os.path.realpath(os.path.join(base_path, y))) for x, y in file_paths.iteritems()])
            assert all([os.path.exists(x) for x in path_map.values()]), path_map
            try:
                genome, institute, tissue, experiment = base_path.replace(source_dir, "").split("/")[1:]
            except ValueError:
                raise RuntimeError("Looks like the directory structure is not what was expected.")
            if genome not in file_map:
                file_map[genome] = {}
            if tissue not in file_map[genome]:
                file_map[genome][tissue] = {}
            if institute not in file_map[genome][tissue]:
                file_map[genome][tissue][institute] = {}
            file_map[genome][tissue][institute][experiment] = path_map
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


def make_bam_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(alignments.format(genome=genome))
        for tissue in file_map[genome]:
            for institute in file_map[genome][tissue]:
                for experiment in file_map[genome][tissue][institute]:
                    path = file_map[genome][tissue][institute][experiment]["bam"]
                    target_handle.write(base_bam_trackline.format(data_path=path, genome=genome, institute=institute,
                                                                  experiment=experiment, tissue=tissue))


def make_sj_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(junctions.format(genome=genome))
        for tissue in file_map[genome]:
            for institute in file_map[genome][tissue]:
                for experiment in file_map[genome][tissue][institute]:
                    target_handle.write(base_sj_trackline.format(genome=genome, institute=institute, tissue=tissue,
                                                                  experiment=experiment))


def make_tracks(file_map, file_handle):
    genome_string = find_genomes(file_map)
    tissue_string = find_tissues(file_map)
    file_handle.write(composite_trackline.format(genome_string=genome_string, tissue_string=tissue_string))
    make_signal_tracks(file_map, file_handle)
    make_bam_tracks(file_map, file_handle)
    make_sj_tracks(file_map, file_handle)


def main():
    args = parse_args()
    file_map = walk_source_dir(target_folder)
    target_file = "trackDb/{0}/Mus{0}_{1}/starTracks.trackDb.ra".format(args.ref_genome, args.assembly_version)
    if args.assembly_version == "1504":
        make_tracks(file_map, open(target_file, "w"))


if __name__ == "__main__":
    main()
