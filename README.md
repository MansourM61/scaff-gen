- [Generate Scaffolding Script](#generate-scaffolding-script)
  - [$ReadTextFile($file_name)](#readtextfilefile_name)
  - [$ReadBinaryFile($file_name)](#readbinaryfilefile_name)
  - [wanted()](#wanted)
  - [CreateSampledContents()](#createsampledcontents)
  - [CreateCommandsLists()](#createcommandslists)
  - [CreateMessageLists()](#createmessagelists)
  - [CreateConstantsLits()](#createconstantslits)
  - [AddGenScaffolder($out_fh)](#addgenscaffolderout_fh)
  - [CreateScaffolder(@ARGS)](#createscaffolderargs)
- [Instruction](#instruction)
- [Version](#version)
- [Author](#author)
- [LICENCE](#licence)

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

## Instruction

To scaffold a project, you need to adjust a few settings in the Perl script:

1. Add the folders, files, and extensions you want to exclude from sampling process to `EXCLUDE_DIRS`, `EXCLUDE_FILES`, and `EXCLUDE_EXTENSIONS` constants, respectively.
2. If you want to include binary (non-text) data in your sampling process, include the extensions in `BINARY_EXTENSIONS` constant.
3. If you need to run a script in the command line before the files are scaffolded, you can add them to `$content_prescaf_cmd_<OS>` heredoc. Depending on the target operating system, pick the appropriate `<OS>`.
4. The same goes for commands to run after scaffolding. Use `$content_postscaf_cmd_<OS>` heredoc.
5. To show any messages after the scaffolding is finished, use `$messages_<OS>` heredoc.
6. Once the script is ready, run:

```shell
perl GenerateScaffolder.pl -i<project/folder> -o<output/script/name> --add-gen-scaf
```

`<project/folder>` is the input project folder to be sampled, and `-o<output/script/name>` is used to name the output script name. Adding `--add-gen-scaf` flag means that the output scaffolder script can clone the scaffolding script along with the project.

## Version

01.00.00

## Author

Mojtaba Mansour Abadi

## LICENCE

This program is licenced under MIT License.
