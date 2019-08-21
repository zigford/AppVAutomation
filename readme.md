Some automation I have written over the past few years.
2 Seperate tools

AutoPackages
=============

Script which parses a xml file specification of a package and target.
Target can be MSI, EXE or APPV.
APPV Target produces a script which can be executed on a sequencing machine to produce an APPV.
EXE or MSI produces an apppackage XML which can be consumed by **ImportConver** and brought into Config Manager for deployment.

ImportConvert
=============

Originally written in 2013 for an Appv 4.6 to Appv 5 migration (Along with SCCM 2007 to SCCM 2012), this script sucks in APPV files and names them and deploys them appropriatly based on their filename.

