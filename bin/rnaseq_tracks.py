"""
UPDATE: for 1509 we now have all tracks for all assemblies. Obviously the reference tracks
remain unchanged.

Produces trackDb files for the STAR alignments star generated both against the reference (by Ian)
and against the individual assemblies (1505 release from Sanger).
The individual assembly does not have wiggle tracks.
"""

import sys
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference genome', required=True)
    parser.add_argument('--genome', help='genome', required=True)
    parser.add_argument('--munged_data_dir', default='/cluster/home/ifiddes/mus_strain_data/pipeline_data/rnaseq/munged_STAR_data')
    return parser.parse_args()


composite_trackline_wiggles = """track rnaseq_star
compositeTrack on
group regulation
shortLabel RNAseq
longLabel RNAseq analysis and raw data
subGroup1 view Views Expression=Expression Junctions=Splice_Junctions Alignments=Alignments
subGroup2 genome Genome {genome_string}
subGroup3 tissueType Tissue {tissue_string}
dimensions dimensionX=genome dimensionY=tissueType
sortOrder view=+ genome=+ tissueType=+
visibility full
dragAndDrop subTracks
type bed 3
noInherit on

"""

composite_trackline_no_wiggles = """track rnaseq_star
compositeTrack on
group regulation
shortLabel RNAseq
longLabel RNAseq analysis and raw data
subGroup1 view Views Junctions=Splice_Junctions Alignments=Alignments
subGroup2 tissueType Tissue {tissue_string}
subGroup3 genome Genome g{genome}={genome}
dimensions dimensionX=tissueType dimensionY=view
sortOrder view=- tissueType=+
visibility full
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

base_wig_trackline = """        track wig_star_{genome}_{institute}_{tissue}
        longLabel {genome} {tissue} Expression
        shortLabel {genome}_{tissue}_Expression
        parent {genome}_expression_star off
        type bigWig
        bigDataUrl {file_path}
        color 153,38,0
        subGroups view=Expression genome=g{genome} tissueType=t{tissue}

"""

junctions = """    track {genome}_splice_junctions_star
    shortLabel Splice Junctions
    view Junctions
    visibility pack
    subTrack rnaseq_star

"""

base_sj_trackline = """        track {genome}_{tissue}_{institute}_splice_junctions_star
        longLabel {genome} {tissue} STAR Splice Junctions ({institute})
        shortLabel {genome}_{tissue}_Splice_Junctions
        parent {genome}_splice_junctions_star off
        bigDataUrl {file_path}
        type bigBed 12
        colorByStrand 255,0,0 0,0,255
        subGroups view=Junctions genome=g{genome} tissueType=t{tissue}

"""

alignments = """    track {genome}_rnaseq_alignments_star
    shortLabel Raw Alignments
    view Alignments
    visibility dense
    subTrack rnaseq_star

"""

base_bam_trackline = """        track bam_star_{genome}_{institute}_{tissue}_{experiment}
        longLabel {genome} {tissue} RNASeq Alignments ({institute}, {experiment})
        shortLabel {genome}_{tissue}_RNASeq_({institute},_{experiment})
        bigDataUrl {file_path}
        parent {genome}_rnaseq_alignments_star off
        subGroups view=Alignments genome=g{genome} tissueType=t{tissue}
        type bam
        indelDoubleInsert on
        indelQueryInsert on
        showNames off
        pairEndsByName on

"""


def walk_source_dir(source_dir, target_genome=None):
    file_map = {}
    for genome in os.listdir(source_dir):
        if target_genome is not None and target_genome != genome:
            continue
        for f in os.listdir(os.path.join(source_dir, genome)):
            if f.endswith("bai"):
                continue
            elif f.endswith(".bam"):
                institute, tissue, experiment = f.split(".")[0].split("_")[:3]
            elif f.endswith(".bb") or f.endswith(".bw"):
                institute, tissue = f.split(".")[0].split("_")
            else:
                continue
            full_path = os.path.join(source_dir, genome, f)
            if genome not in file_map:
                file_map[genome] = {}
            if (institute, tissue) not in file_map[genome]:
                file_map[genome][(institute, tissue)] = []
            file_map[genome][(institute, tissue)].append(full_path)
    return file_map


def find_tissues(file_map):
    return " ".join(sorted(set(["t{0}={0}".format(t) for g in file_map for i, t in file_map[g].iterkeys()])))


def find_genomes(file_map):
    return " ".join(sorted(["g{0}={0}".format(g) for g in file_map.keys()]))


def make_sj_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(junctions.format(genome=genome))
        for (institute, tissue), files in file_map[genome].iteritems():
            for f in files:
                if f.endswith(".sj.bb"):
                    target_handle.write(base_sj_trackline.format(genome=genome, tissue=tissue, institute=institute,
                                                                 file_path=f))


def make_bam_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(alignments.format(genome=genome))
        for (institute, tissue), files in file_map[genome].iteritems():
            for f in files:
                if f.endswith(".bam"):
                    experiment = f.split(".")[0].split("_")[-1]
                    target_handle.write(base_bam_trackline.format(genome=genome, tissue=tissue, institute=institute,
                                                                  experiment=experiment, file_path=f))


def make_signal_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(raw_sig.format(genome=genome))
        for (institute, tissue), files in file_map[genome].iteritems():
            for f in files:
                if f.endswith(".expression.bw"):
                    target_handle.write(base_wig_trackline.format(genome=genome, tissue=tissue, institute=institute,
                                                                  file_path=f))


def make_tracks_with_wiggles(file_map, file_handle):
    genome_string = find_genomes(file_map)
    tissue_string = find_tissues(file_map)
    file_handle.write(composite_trackline_wiggles.format(genome_string=genome_string, tissue_string=tissue_string))
    make_signal_tracks(file_map, file_handle)
    make_bam_tracks(file_map, file_handle)
    make_sj_tracks(file_map, file_handle)


def make_tracks_no_wiggles(file_map, file_handle):
    genome = file_map.keys()[0]
    tissue_string = find_tissues(file_map)
    file_handle.write(composite_trackline_no_wiggles.format(tissue_string=tissue_string, genome=genome))
    make_bam_tracks(file_map, file_handle)
    make_sj_tracks(file_map, file_handle)    


def main():
    args = parse_args()
    target_file_template = "trackDb/{0}/Mus{0}_{1}/starTracks.trackDb.ra"
    file_map = {}
    if args.genome == args.ref_genome:
        file_map = walk_source_dir(os.path.join(args.munged_data_dir, "GRCm38"))
        target_file = target_file_template.format(args.ref_genome, args.assembly_version)
        with open(target_file, "w") as outf:
            make_tracks_with_wiggles(file_map, outf)
    elif args.assembly_version == "1504"or  args.assembly_version == "1509":
        path = os.path.join(args.munged_data_dir, "REL-{}-chromosomes".format(args.assembly_version))
        file_map = walk_source_dir(path, target_genome=args.genome)
        target_file = target_file_template.format(args.genome, args.assembly_version)
        if args.assembly_version == "1509":
            with open(target_file, "w") as outf:
                make_tracks_with_wiggles(file_map, outf)
        else:
            with open(target_file, "w") as outf:
                make_tracks_no_wiggles(file_map, outf)  
    else:
        print "This script was called on a release that was not 1504 or 1509 or not on the reference. Did nothing."
        sys.exit(1)


if __name__ == "__main__":
    main()
