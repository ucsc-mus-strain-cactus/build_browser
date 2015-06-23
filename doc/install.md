
- Updating UCSC browser code on hgwdev-mus-strain.  This uses a script to run make
  which sets all the environment variables, including USER=mus-strain

  JKMAKE= /where/ever/build_browser/bin/jkmake
  cd kent/src
  git pull
  nice $JKMAKE -j 32 clean
  nice $JKMAKE -j 32 cgi
  cd hg/htdocs
  nice $JKMAKE
