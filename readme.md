Some automation I have written over the past few years.
2 Seperate tools

AutoSequencer
=============

Script which runs other scripts.
The _other_ scripts scrape the web and check for newer versions of specific free software. When found, creates another script in a staging area and then boots up a VM which monitors for these scripts. The third written script, uses New-AppvSequencerPackage to sequence the software.

ImportConvert
=============

Originally written in 2013 for an Appv 4.6 to Appv 5 migration (Along with SCCM 2007 to SCCM 2012), this script sucks in APPV files and names them and deploys them appropriatly based on their filename.

