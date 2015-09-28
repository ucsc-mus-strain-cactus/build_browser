import urllib2
import time
import subprocess
path = "http://hgwdev-mus-strain.cse.ucsc.edu/cgi-bin/hgTracks?db=MusC57B6NJ_1504&position=chr4%3A86452710-87130489&hgsid=389526992_naSv6Z52da2mB0jzzQrJ3aawiFJc"

load_times = []
free = []
while True:
    start = time.time()
    s = urllib2.urlopen(path)
    r = s.readlines()
    end = time.time()
    load_times.append([start, end])
    free.append(subprocess.Popen(["free", "-g"], stdout=subprocess.PIPE).communicate()[0])
    if end - start > 10:
        print time.strftime("%H:%M:%S",time.localtime(start)), "{} seconds to load".format(end - start)
    time.sleep(60)