import sys, os, subprocess, ftplib

target_dir = sys.argv[1]
release="1411"
genomes = "C57B6J Rattus 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6NJ CASTEiJ CBAJ DBA2J FVBNJ LPJ NODShiLtJ NZOHlLtJ PWKPhJ SPRETEiJ WSBEiJ".split()

ftp = ftplib.FTP("ftp-mouse.sanger.ac.uk")
ftp.login("anonymous", "")
files = [x for x in ftp.nlst("REL-1411-Assembly") if x.endswith(".out.gz")]
for f in files:
    genome = os.path.basename(f).split(".")[0].replace("_","")
    if genome == "129S1SvImJ":
        genome = "129S1"
    elif genome == "Rattusnorvegicus":
        genome = "Rattus"
    elif genome == "Musmusculus":
        genome = "C57B6J"
    elif genome == "C57BL6NJ":
        genome = "C57B6NJ"
    assert genome in genomes, genome
    new_genome = "Mus{}_{}".format(genome, release)
    outf = os.path.join(target_dir, new_genome, "{}.fa.out.gz".format(new_genome))
    print outf
    ftp.retrbinary("RETR {}".format(f), open(outf, "w").write)
    subprocess.call("gzip -d {}".format(outf), shell=True)