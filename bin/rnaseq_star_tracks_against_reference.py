"""
Produces trackDb files for the STAR alignments Ian generated against the reference found at
/cluster/home/ifiddes/mus_strain_data/pipeline_data/rnaseq/STAR_output
"""

import sys
import os
import argparse
import itertools
import subprocess

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assembly_version', help='genome assembly version (1504, etc)', required=True)
    parser.add_argument('--ref_genome', help='reference genome', required=True)
    parser.add_argument('--load_tracks', help='load tracks?', default=False, action="store_true")
    return parser.parse_args()

target_folder = "/cluster/home/ifiddes/mus_strain_data/pipeline_data/rnaseq/STAR_output"


composite_trackline = """track rnaseq_star
compositeTrack on
group expression
shortLabel RNAseq 
longLabel RNAseq analysis and raw data
subGroup1 view Views PlusRawSig=Plus_Raw_Signal MinusRawSig=Minus_Raw_Signal PlusRawSigMulti=Plus_Raw_Signal_Multi_Mapping_Included MinusRawSigMulti=Minus_Raw_Signal_Multi_Mapping_Included Junctions=Splice_Junctions Alignments=Alignments
subGroup2 genome Genome
subGroup3 tissueType Tissue {tissues}
subGroup4 rep Rep {rep_string}
dimensions dimensionX=genome dimensionY=tissueType dimensionZ=rep
sorOrder view=- genome+ rep=+ tissueType=+
dragAndDrop subTracks
type bed 3
noInherit on

"""

raw_sig = """    track {genome}_{multi}_{strand}_raw_signal
    shortLabel {multi}_{strand}_Raw_Signal
    view {view}
    visibility full
    subTrack rnaseq_star
    maxHeightPixels 100:24:16
    windowingFunction mean+whiskers
    transformFunc NONE
    autoScale on

"""

base_wig_trackline = """        track wig_ian_{genome}_{institute}_{tissue}_{experiment}_{multi}_{strand}
        longLabel {genome} {tissue} {multi} {strand}-strand Expression ({institute}, {experiment})
        shortLabel {genome}_{tissue}_{strand}-strand_Expression
        parent {genome}_{multi}_{strand}_raw_signal
        subGroups view={view} genome={genome} tissueType={tissue} rep={rep}
        type wig
        color 153,38,0

"""

junctions = """    track {genome}_splice_junctions
    shortLabel Splice Junctions 
    view Junctions
    visibility hide
    subTrack rnaseq_star

"""

base_sj_trackline = """        track sj_ian_{genome}_{institute}_{tissue}_{experiment}
        longLabel {genome} {tissue} Splice Junctions ({institute}, {experiment})
        shortLabel {genome}_{tissue}_Splice_Junnctions
        parent {genome}_splice_junctions
        subGroups view=Junctions genome={genome} tissueType={tissue} rep={rep}
        type bed 12
        indelDoubleInsert on
        indelQueryInsert on
        showNames off
        pairEndsByName on

"""

alignments = """    track {genome}_rnaseq_alignments
    shortLabel Raw Alignments
    view Alignments
    visibility hide
    subTrack rnaseq_star

"""

base_bam_trackline = """        track bam_ian_{genome}_{institute}_{tissue}_{experiment}
        longLabel {genome} {tissue} RNASeq ({institute}, {experiment})
        shortLabel {genome}_{tissue}_RNASeq_({institute},_{experiment})
        bigDataUrl {bam_path}
        parent {genome}_rnaseq_alignments
        subGroups view=Alignments genome={genome} tissueType={tissue} rep={rep}
        type bam
        indelDoubleInsert on
        indelQueryInsert on
        showNames off
        pairEndsByName on

"""


strands = [["PlusRawSig", "(+)"], ["MinusRawSig", "(-)"]]
multis = ["Uniquely_And_Multi_Mapping", "Uniquely_Mapping"]
signal_tracks = [[multi, view, strand] for multi, (view, strand) in itertools.chain(*[zip(x, strands) for x in itertools.permutations(multis, len(strands))])]
# lazy mapping
signal_map = {("PlusRawSig", "Uniquely_And_Multi_Mapping"): "Signal.UniqueMultiple.str1.out.renamed.bw",
              ("PlusRawSig", "Uniquely_Mapping"): "Signal.Unique.str1.out.renamed.bw",
              ("MinusRawSig", "Uniquely_And_Multi_Mapping"): "Signal.UniqueMultiple.str2.out.renamed.bw",
              ("MinusRawSig", "Uniquely_Mapping"): "Signal.Unique.str2.out.renamed.bw"}

def walk_source_dir(source_dir):
    file_map = {}
    for base_path, dirs, files in os.walk(source_dir):
        if files:
            path = os.path.realpath(os.path.join(base_path, "Aligned.sortedByCoord.out.bam"))
            assert os.path.exists(path)
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
            file_map[genome][tissue][institute][experiment] = path
    return file_map


def num_replicates(file_map):
    largest = 0
    for genome in file_map:
        for tissue in file_map[genome]:
            this_count = 0
            for institute in file_map[genome][tissue]:
                this_count += len(file_map[genome][tissue][institute])
            largest = max(largest, this_count)
    return largest


def find_tissues(file_map):
    return " ".join(list({y for x in file_map.itervalues() for y in x.keys()}))


def make_rep_string(file_map):
    return " ".join(["rep{0}={0}".format(i + 1) for i in xrange(num_replicates(file_map))])


def write_individual_track(file_map, target_handle, str_to_format, genome, bigDataUrl=False, **kwargs):
    for tissue in file_map[genome]:
        for institute in file_map[genome][tissue]:
            for i, experiment in enumerate(file_map[genome][tissue][institute]):
                if bigDataUrl:
                    kwargs["bam_path"] = file_map[genome][tissue][institute][experiment]
                target_handle.write(str_to_format.format(genome=genome, tissue=tissue, experiment=experiment, 
                                                         institute=institute, rep="rep{}".format(i), **kwargs))


def make_signal_tracks(file_map, target_handle):
    for genome in file_map:
        for multi, view, strand in signal_tracks:
            target_handle.write(raw_sig.format(genome=genome, multi=multi, strand=strand, view=view))
            write_individual_track(file_map, target_handle, base_wig_trackline, genome, multi=multi, strand=strand, 
                                   view=view)


def make_alignment_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(alignments.format(genome=genome))
        write_individual_track(file_map, target_handle, base_bam_trackline, genome, bigDataUrl=True)  


def make_splice_tracks(file_map, target_handle):
    for genome in file_map:
        target_handle.write(junctions.format(genome=genome))
        write_individual_track(file_map, target_handle, base_sj_trackline, genome)  


def make_tracks(file_map, target_handle):
    tissues = find_tissues(file_map)
    rep_string = make_rep_string(file_map)
    target_handle.write(composite_trackline.format(tissues=tissues, rep_string=rep_string))
    make_signal_tracks(file_map, target_handle)
    make_alignment_tracks(file_map, target_handle)
    make_splice_tracks(file_map, target_handle)


def load_tracks(file_map, source_dir, ref_genome, assembly_version):
    for genome in file_map:
        for tissue in file_map[genome]:
            for institute in file_map[genome][tissue]:
                for experiment in file_map[genome][tissue][institute]:
                    for (multi, strand), path in signal_map.iteritems():
                        track_name = "wig_ian_{genome}_{institute}_{tissue}_{experiment}_{multi}_{strand}".format(
                                                                      genome=genome, institute=institute, tissue=tissue, 
                                                                      experiment=experiment, multi=multi, strand=strand)
                        wig_path = os.path.join(source_dir, genome, institute, tissue, experiment, path)
                        wig_path = os.path.realpath(wig_path)
                        load_wig(track_name, wig_path, ref_genome, assembly_version)
                    sj_name = "sj_ian_{genome}_{institute}_{tissue}_{experiment}".format(genome=genome,
                                                                                         institute=institute,
                                                                                         tissue=tissue,
                                                                                         experiment=experiment)
                    bed_path = os.path.join(source_dir, genome, institute, tissue, experiment, "sj.bed")
                    bed_path = os.path.realpath(bed_path)
                    load_bed(sj_name, bed_path, ref_genome, assembly_version, bed_type="bed12")


def load_wig(track_name, wig_path, ref_genome, assembly_version):
    database = "Mus{}_{}".format(ref_genome, assembly_version)
    subprocess.call("hgLoadWiggle -tmpDir=${{TMPDIR}} {} {} {}".format(database, track_name, wig_path), shell=True)


def load_bed(track_name, bed_path, ref_genome, assembly_version, bed_type="bed3"):
    database = "Mus{}_{}".format(ref_genome, assembly_version)
    subprocess.call("hgLoadBed -type={} -tmpDir=${{TMPDIR}} {} {} {}".format(bed_type, database, track_name, bed_path),
                    shell=True)


def main():
    args = parse_args()
    file_map = walk_source_dir(target_folder)
    if args.load_tracks is False:
        target_file = "trackDb/{0}/Mus{0}_{1}/starTracks.trackDb.ra".format(args.ref_genome, args.assembly_version)
        if args.assembly_version == "1504":
            make_tracks(file_map, open(target_file, "w"))
    else:
        load_tracks(file_map, target_folder, args.ref_genome, args.assembly_version)


if __name__ == "__main__":
    main()
