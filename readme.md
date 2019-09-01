Some automation I have written over the past few years.
2 Separate tools

AutoPackager
=============

Script which parses a xml file specification of a package and target.
Target can be MSI, EXE or APPV.
APPV Target produces a script which can be executed on a sequencing machine to produce an APPV.
EXE or MSI produces an apppackage XML which can be consumed by **ImportConvert** and brought into Config Manager for deployment.

ImportConvert
=============

Originally written in 2013 for an Appv 4.6 to Appv 5 migration (Along with SCCM 2007 to SCCM 2012), this script sucks in APPV files and names them and deploys them appropriatly based on their filename.

---

## Autopackager - Critical files and scripts

`Orchestration\Settings.json`
contains configuration settings for the autopackager, and needs to be configured for your site *.

(* NB: within a " enclosed json string, the backslash (\\) character used in windows filepaths
must be doubled eg. "C:\\\\windows\\\\filespec").

The required settings are:
* PackageDest: The destination folder for auto-packaged applications ready to be added as sccm packages
* PackageQueue:  APPV source files and sequencing scripts will be queued here
* PackageSource:  MSI & EXE source files are queued here

`Orchestration\PackageChecker.ps1` Script

For each package definition in 'packages' this script checks if a new dist is avalable.
If a newer dist than what is currently packaged is available, it downloads it and queues for packaging.

There are three different ways a package definition may be specified:
1. folder with a Manifest.xml definition
2. folder with checkpackage.ps1 script
3. standalone PACKAGE.ps1 script

### Folder with a Manifest.xml definition

In this case all the required metadata to create a package is contained in the file `Packages\APPNAME\Manifest.xml`. Look in the Orchestration\Packages folder for example `manifest.xml` files.

Broadly speaking the manifest XML has the following basic structure:

>`<Application>`: The root tag, with attributes to specify the Name, Version, Vendor, License, Target
>
>>`<Downloads>`: Contains one or more `<download>` subtags
>>>`<Download>`: Attributes specify the source URL and how to download the installer
>
>>`<LocalFiles>`: Optionally specify additional local files in the package folder to be used in the packaging process
>
>> `<Type>`: Specifies either APPV, MSI, or EXE with a set of subtags to specify the details of how to package for each type

`Orchestration\Functions\Start-ManifestProcess.ps` is called to process each `manifest.xml` file. It loads the metadata, and then calls one of:
* `New-SequencerScript`

   if `<Type>` is APPV

   which adds the installer and a sequencing script to `PackageQueue` folder defined in `Settings.json`
* `New-AppPackageBundle` if `<Type>` is MSI or EXE

   which adds the installer and required packaging metadata to the `PackageSource` folder defined in `Settings.json`

### Folder with checkpackage.ps1 script
_WIP - to be completed._

### Standalone PACKAGE.ps1 script
_WIP - to be completed._