- [Generate Scaffolding Script](#Generate-Scaffolding-Script)
  - [Version](#Version)
  - [Author](#Author)
  - [LICENCE](#LICENCE)

# Generate Scaffolding Script

This script samples a project folder and creates a script to replicate the project. To use this script, install Perl +v5.20, then run the following in the command line:

```
    perl <script.pl> -i<project/folder> -o<output/script/name> [--add-gen-scaf]
```

Mandatory _\-i_ is used to point to the source folder to be sampled. By default, the output script is **Scaffolder.pl**, if needed use _\-o_ option to change the script name. If this script is also needed to be included in the project, use -_\--add-gen-scaf_ option.

#### $ReadTextFile($file_name)

Reads an entire text file and returns the content.

#### $ReadBinaryFile($file_name)

Reads an entire binary file and returns the content.

#### wanted()

Callback function, called when a new folder or file is discovered. The function filters the discovered folder or file to exclude ignore cases. The outcome is a string that is put into the scaffolder script to generate the same folder and file.

#### CreateSampledContents()

The function searches within the given root project folder and extracts the folders names as well as files contents. These information are used in the scaffolder script to duplicate the folders and files.

#### CreateCommandsLists()

All the commands needed to be executed before and after recreation of folders and files, are collected and formatted to be used in the scaffolder script.

#### CreateMessageLists()

All the guidelines and messages to be shown at the end of scaffolder script are formed here to be inserted into the scaffolder script.

#### CreateConstantsLits()

Any required constants' statements are generated here to be written into the Scaffolder script.

#### AddGenScaffolder($out_fh)

This script is also included in the scaffolder file with file handle of -_$out_fh_, so the end user can sample its project and generate a scaffolder.

#### CreateScaffolder(@ARGS)

The main core where all different parts of the scaffolder script are written in the file.

## Version

00.02.00.a

## Author

Mojtaba Mansour Abadi

## LICENCE

This program is licenced under MIT License.
