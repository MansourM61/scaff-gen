#!/usr/bin/perl
package GenerateScaffolder;

=pod

=head1 Generate Scaffolding Script

This script samples a project folder and creates a script to replicate the project.
To use this script, install Perl +v5.20, then run the following in the command line:

    perl <script.pl> -i<project/folder> -o<output/script/name> [--add-gen-scaf]

Mandatory I<-i> is used to point to the source folder to be sampled. By
default, the output script is B<Scaffolder.pl>, if needed use I<-o> option to
change the script name.
If this script is also needed to be included in the project, use
-I<--add-gen-scaf> option.

=over

=cut

################################################################################
# required packages
use v5.20;
use strict;
use warnings;
use Cwd;
use File::Spec;
use File::Find;
use Time::HiRes;
use List::Util qw(min);
use POSIX qw/floor/;

################################################################################
# constants
use constant EXCLUDE_DIRS =>
  qw/.venv node_modules .git coverage .next out build .vercel/
  ;    # directories to ignore when sampling
use constant EXCLUDE_FILES => qw/.DS_Store package-lock.json/
  ;    # files to ignore when sampling
use constant EXCLUDE_EXTENSIONS => qw/pyc exe/
  ;    # extensions to ignore when sampling
use constant BINARY_EXTENSIONS => qw/db png ico jpeg jpg webp/
  ;    # extensions of binary files
use constant LIST_GLUE_CHAR => ":"
  ; # character used to  join path elements into a single text when exported as a list
use constant OUTPUT_FILE_NAME => "Scaffolder.pl"; # scaffolding script
use constant OUTPUT_DIRECTORY => "Project";       # scaffolding output directory

################################################################################
# declaration of heredoc definitions
my $content_prescaf_cmd_win;     # pre-scaffolding commands (Windows OS)
my $content_prescaf_cmd_lnx;     # pre-scaffolding commands (Linux OS)
my $content_prescaf_cmd_mac;     # pre-scaffolding commands (Mac OS)
my $content_postscaf_cmd_win;    # pre-scaffolding commands (Windows OS)
my $content_postscaf_cmd_lnx;    # pre-scaffolding commands (Linux OS)
my $content_postscaf_cmd_mac;    # pre-scaffolding commands (Mac OS)
my $messages_win;                # messages and guidelines (Windows OS)
my $messages_lnx;                # messages and guidelines (Linux OS)
my $messages_mac;                # messages and guidelines (Mac OS)
my $data_section;                # embedded data

################################################################################
# declaration of global variable
my $dir_search;         # directory to search and sample
my $out_fh;             # file handle of output
my @dirs_names_list;    # list of all discovered directories
my $dir_file_list;      # string containing array definition of all directories
my $constants_list;     # list of constants
my $commands_list;      # list of pre and post scaffolding commands for all OSs
my $message_list;       # list of messages and guidelines for all OSs
my $total_searched_folders;   # total number of search folders
my $total_searched_files;     # total number of search files
my $total_added_folders;      # total number of folders added to scaffolder
my $total_added_files;        # total number of files added to scaffolder
my $total_added_text_files;   # total number of text files added to scaffolder
my $total_added_bin_files;    # total number of binary files added to scaffolder

################################################################################
# definition of global variable

=item $ReadTextFile($file_name)

Reads an entire text file and returns the content.

=cut

my $ReadTextFile = sub {
    my $file_name = shift;
    open( my $target_fh, "<", $file_name ) or die "Can't open file $!";
    my $file_content = do { local $/; <$target_fh> };
    close($target_fh);

    return \$file_content;
};

=pod

=item $ReadBinaryFile($file_name)

Reads an entire binary file and returns the content.

=cut

my $ReadBinaryFile = sub {
    my $file_name = shift;
    my $hex_str   = "";
    open my $fh, "<", $file_name;
    binmode $fh;
    while ( defined( my $buffer = <$fh> ) ) {
        for ( 0 .. length($buffer) - 1 ) {
            my $next_char = substr $buffer, $_, 1;
            my $next_code = ord($next_char);

            $hex_str .= sprintf( "%02x", $next_code );
        }
    }
    close $fh;

    my $offset      = 0;
    my $data_length = length $hex_str;

    my $data_str = "";
    for ( 0 .. floor( $data_length / 60 ) - 1 ) {
        my $chunck = substr $hex_str, 60 * $_, min(60);
        $data_str .= $chunck . "\n";
    }
    my $chunck = substr $hex_str, ( floor( $data_length / 60 ) * 60 );
    $data_str .= $chunck;    # . "\n";

    return \$data_str;
};

################################################################################
# callback function called when a new file or directory is found in the search path

=pod

=item wanted()

Callback function, called when a new folder or file is discovered.
The function filters the discovered folder or file to exclude ignore cases.
The outcome is a string that is put into the scaffolder script to generate 
the same folder and file.

=cut

sub wanted {
    my $full_path = $File::Find::name;
    my $finding   = $_;

    my @dir_sections     = File::Spec->splitdir($full_path);
    my $target_name      = $dir_sections[-1];
    my $target_extension = ( split( /\./, $target_name ) )[-1];

    my $is_dir  = -d $finding;
    my $is_file = -f $finding;

    my $relative_path = File::Spec->abs2rel( $full_path, $dir_search );

    if ( -d $finding ) {    # target is directory
        $total_searched_folders += 1;
        foreach my $item (@dir_sections) {
            if ( grep( /^$item$/, EXCLUDE_DIRS ) ) {
                return;
            }
        }
        say "Found directory: " . $dir_search . "/" . $finding;
        $total_added_folders += 1;

        my @relative_dir_sections = File::Spec->splitdir($relative_path);

        push( @dirs_names_list,
            join( LIST_GLUE_CHAR, @relative_dir_sections ) );
    }
    elsif ( -f $finding ) {    # target is file
        $total_searched_files += 1;
        if ( grep( /^$target_name$/, EXCLUDE_FILES ) ) {
            return;
        }
        if ( grep( /^$target_extension$/, EXCLUDE_EXTENSIONS ) ) {
            return;
        }
        foreach my $item (@dir_sections) {
            if ( grep( /^$item$/, EXCLUDE_DIRS ) ) {
                return;
            }
        }

        ++$total_added_files;

        my $file_path = $relative_path =~ s/\\|\//:/rg;

        if ( !grep( /^$target_extension$/, BINARY_EXTENSIONS ) ) {
            say "\tFound text-based file: " . $finding;

            my $file_content_ref = $ReadTextFile->($finding);
            $data_section .=
              "<<<text|$file_path|\n" . ${$file_content_ref} . "\n>>>\n";

            ++$total_added_text_files;
        }
        else {
            say "\tFound binary-based file: " . $finding;

            my $file_content_ref = $ReadBinaryFile->($finding);
            $data_section .=
              "<<<binary|$file_path|\n" . ${$file_content_ref} . "\n>>>\n";

            ++$total_added_bin_files;
        }
    }
    else {    # unwanted target
        return;
    }
}

################################################################################
# populate folder content variables

=pod

=item CreateSampledContents()

The function searches within the given root project folder and extracts the 
folders names as well as files contents. These information are 
used in the scaffolder script to duplicate the folders and files.

=cut

sub CreateSampledContents {
    $total_searched_folders = 0;
    $total_searched_files   = 0;
    $total_added_folders    = 0;
    $total_added_files      = 0;
    my $start_time;
    my $diff;

    my $files_names_str;

    if ( -d $dir_search ) {
        say "\"" . $dir_search . "\" is a directory!\n";
        say "Searching for files recursively...\n\n";

        $start_time = [ Time::HiRes::gettimeofday() ];
        find( \&wanted, $dir_search );
        $diff = Time::HiRes::tv_interval($start_time);

        $dir_file_list =
            "my \@dir_list = qw/"
          . join( " ", @dirs_names_list )
          . "/;  # list of directories to create\n";

        say "\n\nSampling is finished!\n";

        say "=" x 40;
        say "\n";
        say "Total No of sampled folders = " . $total_searched_folders;
        say "Total No of added folders = " . $total_added_folders;
        say "Total No of sampled files = " . $total_searched_files;
        say "Total No of added text files = " . $total_added_text_files;
        say "Total No of added binary files = " . $total_added_bin_files;
        say "Total No of added files = " . $total_added_files;
        say "\n";
        say "Elapsed time = " . $diff * 1000.0 . " ms, = " . $diff . " s";
        say "-" x 40;
        say "\n";

    }
    else {
        say $dir_search . " is not a directory!";
        exit(0);
    }
}

################################################################################
# populate commands list variable

=pod

=item CreateCommandsLists()

All the commands needed to be executed before and after recreation of folders 
and files, are collected and formatted to be used in the scaffolder script.

=cut

sub CreateCommandsLists {
    $commands_list =
        "# pre-scaffolding commands (Windows OS)\n"
      . "\$prescaf_commands_Windows"
      . " = <<\'FILE_CONTENT\';\n"
      . $content_prescaf_cmd_win
      . "FILE_CONTENT\n\n"
      . "# pre-scaffolding commands (Linux OS)\n"
      . "\$prescaf_commands_Linux"
      . " = <<\'FILE_CONTENT\';\n"
      . $content_prescaf_cmd_lnx
      . "FILE_CONTENT\n\n"
      . "# pre-scaffolding commands (Mac OS)\n"
      . "\$prescaf_commands_Mac"
      . " = <<\'FILE_CONTENT\';\n"
      . $content_prescaf_cmd_mac
      . "FILE_CONTENT\n\n"
      . "# post-scaffolding commands (Windows OS)\n"
      . "\$postscaf_commands_Windows"
      . " = <<\'FILE_CONTENT\';\n"
      . $content_postscaf_cmd_win
      . "FILE_CONTENT\n\n"
      . "# post-scaffolding commands (Linux OS)\n"
      . "\$postscaf_commands_Linux"
      . " = <<\'FILE_CONTENT\';\n"
      . $content_postscaf_cmd_lnx
      . "FILE_CONTENT\n\n"
      . "# post-scaffolding commands (Mac OS)\n"
      . "\$postscaf_commands_Mac"
      . " = <<\'FILE_CONTENT\';\n"
      . $content_postscaf_cmd_mac
      . "FILE_CONTENT\n";
}

################################################################################
# populate message list variable

=pod

=item CreateMessageLists()

All the guidelines and messages to be shown at the end of scaffolder script are
formed here to be inserted into the scaffolder script.

=cut

sub CreateMessageLists {
    $message_list =
        "# guidelines and messages (Windows OS)\n"
      . "\$messages_Windows"
      . " = <<\'FILE_CONTENT\';\n"
      . $messages_win
      . "FILE_CONTENT\n\n"
      . "# guidelines and messages (Linux OS)\n"
      . "\$messages_Linux"
      . " = <<\'FILE_CONTENT\';\n"
      . $messages_lnx
      . "FILE_CONTENT\n\n"
      . "# guidelines and messages (Mac OS)\n"
      . "\$messages_Mac"
      . " = <<\'FILE_CONTENT\';\n"
      . $messages_mac
      . "FILE_CONTENT\n";
}

################################################################################
# inserting constants into the script

=pod

=item CreateConstantsLits()

Any required constants' statements are generated here to be written into the
Scaffolder script.

=cut

sub CreateConstantsLits {
    $constants_list =
        "use constant LIST_GLUE_CHAR => " . "\""
      . LIST_GLUE_CHAR . "\""
      . ";  # character used to join path elements into a single text when exported as a list"
      ;    # write 'use' section
    $constants_list .= "\n";

    $constants_list .=
        "use constant PROJ_DIR => " . "\""
      . ( +OUTPUT_DIRECTORY ) . "\""
      . ";  # default project root directory";    # write 'use' section
    $constants_list .= "\n";
}

################################################################################
# add the content of this script to the scaffolder

=pod

=item AddGenScaffolder($out_fh)

This script is also included in the scaffolder file with file handle of
-I<$out_fh>, so the end user can sample its project and generate a scaffolder.

=cut

sub AddGenScaffolder {
    my $out_fh = shift;
    print $out_fh "<<<text|" . __FILE__ . "|\n";

    my $genscaf_content_ref = $ReadTextFile->(__FILE__);
    print $out_fh ${$genscaf_content_ref};

    print $out_fh "\n>>>\n";
}

################################################################################
# main logic function called from main scope

=pod

=item CreateScaffolder(@ARGS)

The main core where all different parts of the scaffolder script are written in
the file.

=cut

sub CreateScaffolder {

    my $output_script = ( +OUTPUT_FILE_NAME );

    my $include_gen_scaf = 0;

    for my $option (@_) {
        ($dir_search)    = $option =~ m/^\-i(\S+)$/ if ( $option =~ m/^\-i/ );
        ($output_script) = $option =~ m/^\-o(\S+)$/ if ( $option =~ m/^\-o/ );
        ($include_gen_scaf) = 1 if ( $option =~ m/^\-\-add\-gen\-scaf$/ );
    }

    if ( !defined $dir_search ) {
        die "Input directory is not given.\n\n"
          . "To use the sampler, type:\n"
          . "\tperl "
          . __FILE__
          . " -i<project/folder>\n\n"
          . "By default, the output script is 'Scaffolder.pl'.\n"
          . "Use -o<output/script/name> to change the script name.\n"
          . "To include the scaffolder generator in project, "
          . "use '--add-gen-scaf' option.\n";
    }

    if ( !-d $dir_search ) {
        die "$dir_search folder does not exist!";
    }

    &CreateSampledContents;
    &CreateConstantsLits;
    &CreateCommandsLists;
    &CreateMessageLists;

    say "Creating Scaffolder...";

    open( $out_fh, ">", $output_script )
      or die "Can't open > " . $output_script . ": $!";

    while ( my $line = <DATA> ) {
        my ($line_content) = $line =~ m/^(\S+)/;

        if ( !defined $line_content ) {
            print $out_fh $line;
        }
        elsif ( $line_content eq "__CONSTANT_SECTION__" ) {
            print $out_fh $constants_list;
        }
        elsif ( $line_content eq "__DIR_LIST_SECTION__" ) {
            print $out_fh $dir_file_list;
        }
        elsif ( $line_content eq "__HEREDOC_SECTION__" ) {
            print $out_fh $commands_list;
            print $out_fh "\n";
            print $out_fh $message_list;
            print $out_fh "\n";
        }
        elsif ( $line_content eq "__DATA_SECTION__" ) {
            print $out_fh $data_section;
        }
        else {
            print $out_fh $line;
        }
    }

    if ($include_gen_scaf) {
        say "\nAdding " . __FILE__ . " to the scaffolder $output_script...";

        &AddGenScaffolder($out_fh);
    }

    close($out_fh);

    say "\n";
    printf( "Scaffolder script '%s' (size = %d kB) generated!\n",
        $output_script, ( -s $output_script ) / 1024 );

    say "\n";
    say "Run the following to duplicate the project:\n";
    say "\tperl " . $output_script . " all";
}

################################################################################
# definition of heredocs

# pre-scaffolding commands for Windows OS
$content_prescaf_cmd_win = <<'FILE_CONTENT';
@echo off
echo --------------------------------------------------------------------------------
echo Performing pre-scaffolding tasks...
echo.
echo Changing the directory to the project directory
cd __PROJ_NAME__

REM Tasks

echo Changing the directory to the script directory
cd __SCRIPT_DIR__
FILE_CONTENT

# pre-scaffolding commands for Linux OS
$content_prescaf_cmd_lnx = <<'FILE_CONTENT';
echo --------------------------------------------------------------------------------
echo Performing pre-scaffolding tasks...
echo
echo Changing the directory to the project directory
cd __PROJ_NAME__

# Tasks

echo Changing the directory to the script directory
cd __SCRIPT_DIR__
FILE_CONTENT

# pre-scaffolding commands for Mac OS
$content_prescaf_cmd_mac = <<'FILE_CONTENT';
echo --------------------------------------------------------------------------------
echo Performing pre-scaffolding tasks...
echo
echo Changing the directory to the project directory
cd __PROJ_NAME__

# Tasks

echo Changing the directory to the script directory
cd __SCRIPT_DIR__
FILE_CONTENT

# post-scaffolding commands for Windows OS
$content_postscaf_cmd_win = <<'FILE_CONTENT';
@echo off
echo --------------------------------------------------------------------------------
echo Performing post-scaffolding tasks...
echo.
echo Changing the directory to the project directory
cd __PROJ_NAME__

REM Tasks

echo Changing the directory to the script directory
cd __SCRIPT_DIR__
FILE_CONTENT

# post-scaffolding commands for Linux OS
$content_postscaf_cmd_lnx = <<'FILE_CONTENT';
echo --------------------------------------------------------------------------------
echo Performing post-scaffolding tasks...
echo
echo Changing the directory to the project directory
cd __PROJ_NAME__

# Tasks

echo Changing the directory to the script directory
cd __SCRIPT_DIR__
FILE_CONTENT

# post-scaffolding commands for Mac OS
$content_postscaf_cmd_mac = <<'FILE_CONTENT';
echo --------------------------------------------------------------------------------
echo Performing post-scaffolding tasks...
echo
echo Changing the directory to the project directory
cd __PROJ_NAME__

# Tasks

echo Changing the directory to the script directory
cd __SCRIPT_DIR__
FILE_CONTENT

# messages and guidelines (Windows OS)
$messages_win = <<'FILE_CONTENT';
----------------------------------------
Go to the root folder:
	cd __PROJ_NAME__

NOTE: All following instructions only work when executed in the project root folder!
----------------------------------------
REM Instructions and messages
----------------------------------------
FILE_CONTENT

# messages and guidelines (Linux OS)
$messages_lnx = <<'FILE_CONTENT';
----------------------------------------
Go to the root folder:
	cd __PROJ_NAME__

NOTE: All following instructions only work when executed in the project root folder!
----------------------------------------
# Instructions and messages
----------------------------------------
FILE_CONTENT

# messages and guidelines (Mac OS)
$messages_mac = <<'FILE_CONTENT';
----------------------------------------
Go to the root folder:
	cd __PROJ_NAME__

NOTE: All following instructions only work when executed in the project root folder!
----------------------------------------
# Instructions and messages
----------------------------------------
FILE_CONTENT

################################################################################
# main entry of the script
main:
{
    &CreateScaffolder(@ARGV);
}

1;

################################################################################
# POD

=pod

=back

=head2 Version

00.02.00.a

=head2 Author

Mojtaba Mansour Abadi

=head2 LICENCE

This program is licenced under MIT License.

=cut

################################################################################
# embedded data
__DATA__
#!/usr/bin/perl
package Scaffolder;

=pod

=head1 Automatic Project Creation

=head2 Generated by GenerateScaffolder script

To use this script, install Perl +v5.20, then run the following in the command line:

    perl <script.pl> <step> [--ignore-err] [-d<project/name>]

Mandatory argument I<step> can be any of the followings:

=over 4

=item B<all>: creates everything

=item B<pre>: only runs pre-scaffolding commands

=item B<dir>: only creates project empty folders

=item B<file>: only creates project files

=item B<post>: runs post-scaffolding commands

=back

By default, if an error occurs during scaffolding, the script ends and exits
with an error code. However, if I<--ignore-err> is give, the encountered errors
are ignored and scaffolding continues. 

By default the scaffolding is generated under I<Project> folder. To override
it, use I<-d> option and set the project name to something else.

=over

=cut

################################################################################
# required packages
use v5.20;
use strict;
use warnings;
use Cwd;
use File::Spec;
use Time::HiRes;

###############################################################################
# constants
use constant MY_OS => $^O;  # use (MY_OS) in a hash, to avoid bareword quoting mechanism.
use constant OS_NAME =>
  { "MSWin32" => "Windows", "linux" => "Linux", "darwin" => "MacOS" };  # OS names and aliases
__CONSTANT_SECTION__

################################################################################
# declaration of heredocs
my $prescaf_commands_Windows;          # pre-scaffolding commands (Windows OS)
my $prescaf_commands_Linux;            # pre-scaffolding commands (Linux OS)
my $prescaf_commands_Mac;              # pre-scaffolding commands (Mac OS)
my $postscaf_commands_Windows;         # post-scaffolding commands (Windows OS)
my $postscaf_commands_Linux;           # post-scaffolding commands (Linux OS)
my $postscaf_commands_Mac;             # post-scaffolding commands (Mac OS)
my $messages_Windows;   # messages about how to work on the project (Windows OS)
my $messages_Linux;     # messages about how to work on the project (Linux OS)
my $messages_Mac;       # messages about how to work on the project (Mac OS)
my $command_line_help;  # command line help message

################################################################################
# declaration and definition of global variables
my $output_dir;          # output folder
my %place_holders;       # place holders to be replaced in the command lists
my $total_folders;       # total number of generated folders
my $total_files;         # total number of generated files
my $total_text_files;    # total number of generated text files
my $total_bin_files;     # total number of generated binary files
my $ignore_errors;       # ignore all errors and continue with scaffolding

=item $ReportError($msg)

Depending on the presence of I<--ignore-err>, the function shows a message or
shows the error and stops the script.

=cut

my $ReportError = sub {
    if ( $ignore_errors == 0 ) {
        die shift;
    }
    else {
        say shift;
    }
};

__DIR_LIST_SECTION__

###############################################################################
# execute all given commands

=pod

=item ExecutesCommands()

All the commands that are passed as input arguments are executed.

=cut

sub ExecutesCommands {
    my $content_cmd = shift;

    foreach my $key ( keys %place_holders ) {
        my $place_holder_val = $place_holders{$key};
        $place_holder_val =~
          s/\\/\\\\/gd; # replace \ with \\ (this is needed to disable escape char)
        $content_cmd =~ s/$key/$place_holder_val/g;
    }
    my @command_list = split( "\n", $content_cmd );

    foreach my $item (@command_list) {
        next if length($item) == 0;
        if ( $item =~ m/^cd\s+'?([\w|\.\\\/:]+)'?$/i ) {
            chdir $1;
        }
        elsif ( $item =~ m/^#/ || $item =~ m/^REM / ) {
            next;
        }
        else {
            system($item) == 0 or $ReportError->("Error: $?");
        }
    }
}

###############################################################################
# execute all commands defines as pre-scaffolding commands

=pod

=item ExecutePreScafCommands()

All the commands that run before creating files and folders are executed here.

=cut

sub ExecutePreScafCommands {
    say( "=" x 80 );
    say "Executing pre-scaffolding commands...\n";

    my $content_prescaf_cmd;
    if ( MY_OS eq "MSWin32" ) {
        $content_prescaf_cmd = $prescaf_commands_Windows;
    }
    elsif ( MY_OS eq "linux" ) {
        $content_prescaf_cmd = $prescaf_commands_Linux;
    }
    elsif ( MY_OS eq "darwin" ) {
        $content_prescaf_cmd = $prescaf_commands_Mac;
    }
    else {
        say "Unknown OS!";
        exit(0);
    }

    &ExecutesCommands($content_prescaf_cmd);
}

################################################################################
# folder creation

=pod

=item CreateFolderStructure()

The method creates the folder structure based on the list of given folders.

=cut

sub CreateFolderStructure {
    say( "=" x 80 );
    say "Creating empty folder structures...\n";
    foreach (@dir_list) {
        my $foldername = File::Spec->catdir($output_dir, split( LIST_GLUE_CHAR, $_ ) );
        say "Creating folder: " . $foldername;
        mkdir $foldername;
        $total_folders += 1;
    }
}

################################################################################
# write embedded data section to files

=pod

=item WriteDataSectionToFiles()

Writes the embedded data to the corresponding binary files

=cut

sub WriteDataSectionToFiles {
    my $file_type;
    my $file_name;
    my $file_content;

    while ( my $data_line = <DATA> ) {
        if ( $data_line =~ m/^<<<(\S+)\|([\S|\s]+)\|/ ) {
            ++$total_files;
            $file_type = $1;
            my $raw_file_name = $2;
            $file_name    = File::Spec->catfile($output_dir, split( LIST_GLUE_CHAR, $raw_file_name ) );
            $file_content = "";
            say "\tWriting $file_type file: " . $file_name;
        }
        elsif ( $data_line =~ m/^>>>/ ) {
            open my $fh, ">", $file_name;
            my $file_str;
            
            if ($file_type eq "binary") {
                ++$total_bin_files;
                $file_str = pack 'H*', map s{\s+}{}gr, $file_content;
                binmode $fh;
            }
            elsif ($file_type eq "text") {
                ++$total_text_files;
                $file_str = $file_content;
            }
            else {
                say "Ignoring unknown $file_type file type: $file_name";
                close $fh;
                next;
            }
            print $fh $file_str;
            close $fh;
        }
        else {
            $file_content .= $data_line;
        }
    }
}

###############################################################################
# execute all commands defines as post-scaffolding commands

=pod

=item ExecutePostScafCommands

All the commands that run after creating files and folders are executed here.

=cut

sub ExecutePostScafCommands {
    say( "=" x 80 );
    say "Executing post-scaffolding commands...\n";

    my $content_postscaf_cmd;
    if ( MY_OS eq "MSWin32" ) {
        $content_postscaf_cmd = $postscaf_commands_Windows;
    }
    elsif ( MY_OS eq "linux" ) {
        $content_postscaf_cmd = $postscaf_commands_Linux;
    }
    elsif ( MY_OS eq "darwin" ) {
        $content_postscaf_cmd = $postscaf_commands_Mac;
    }
    else {
        say "Unknown OS!";
        exit(0);
    }

    &ExecutesCommands($content_postscaf_cmd);
}

###############################################################################
# shows guidelines and messages about how to work on the project

=pod

=item ShowGuidelinesAndMessages()

All the guidelines and messages are displayed using this function.

=cut

sub ShowGuidelinesAndMessages {
    say( "=" x 80 );
    say "Guidelines and messages...\n";

    my $messages;
    if ( MY_OS eq "MSWin32" ) {
        $messages = $messages_Windows;
    }
    elsif ( MY_OS eq "linux" ) {
        $messages = $messages_Linux;
    }
    elsif ( MY_OS eq "darwin" ) {
        $messages = $messages_Mac;
    }
    else {
        say "Unknown OS!";
        exit(0);
    }

    foreach my $key ( keys %place_holders ) {
        my $place_holder_val = $place_holders{$key};
        $messages =~ s/$key/$place_holder_val/g;
    }

    say $messages;
}

################################################################################
# main logic function called from main scope

=pod

=item SetupProject(@ARGS)

The core function where all scaffolding is orchestrated.

=cut

sub SetupProject {
    my %setup = map { $_ => 1 } @_;

    $output_dir = ( +PROJ_DIR );
    for my $option (@_) {
        ($output_dir) = $option =~ m/^\-d(\S+)$/ if ( $option =~ m/^\-d/ );
    }

    $place_holders{"__PROJ_NAME__"}  = $output_dir;
    $place_holders{"__SCRIPT_DIR__"} = cwd();

    my $start_time;
    my $diff;
    $total_folders    = 0;
    $total_files      = 0;
    $total_text_files = 0;
    $total_bin_files  = 0;

    say "Preparing scaffolding for " . OS_NAME->{ (MY_OS) } . ": \n";
    if ( MY_OS ne "MSWin32" && MY_OS ne "linux" && MY_OS ne "darwin" ) {
        say "Unknown operating system!\n";
        exit(0);
    }

    if ( exists( $setup{'--ignore-err'} ) ) {
        $ignore_errors = 1;
    }
    else {
        $ignore_errors = 0;
    }

    $command_line_help =~ s/__SCRIPT_NAME__/__FILE__/gm;

    mkdir $output_dir;
    $start_time = [ Time::HiRes::gettimeofday() ];
    if ( exists( $setup{'all'} ) ) {
        &ExecutePreScafCommands;
        &CreateFolderStructure;
        &WriteDataSectionToFiles;
        &ExecutePostScafCommands;
    }
    elsif ( exists( $setup{'pre'} ) ) {
        &ExecutePreScafCommands;
    }
    elsif ( exists( $setup{'dir'} ) ) {
        &CreateFolderStructure;
    }
    elsif ( exists( $setup{'file'} ) ) {
        &WriteDataSectionToFiles;
    }
    elsif ( exists( $setup{'post'} ) ) {
        &ExecutePostScafCommands;
    }
    elsif ( exists( $setup{'--help'} ) ) {
        say $command_line_help;
        exit(0);
    }
    else {
        say "No action is given!\n";
        say $command_line_help;
        exit(-1);
    }

    $diff = Time::HiRes::tv_interval($start_time);

    say( "#" x 80 );
    say "Scaffolding finished!\n";

    say "Total No of generated folders = " . $total_folders;
    say "Total No of generated text files = " . $total_text_files;
    say "Total No of generated binary files = " . $total_bin_files;
    say "Total No of generated files = " . $total_files;
    say "\n";
    say "Elapsed time = " . $diff * 1000.0 . " ms, = " . $diff . " s";

    &ShowGuidelinesAndMessages
      if ( exists( $setup{'msg'} ) || exists( $setup{'all'} ) );
}

################################################################################
# definition of heredocs

# command line help message
$command_line_help = <<'FILE_CONTENT';
To use this script, run the following in the command line:

    perl __SCRIPT_NAME__ <action> [--ignore-err] [-d<project/name>]

Mandatory argument <action> can be any of the followings:

    all:  creates everything
    pre:  only runs pre-scaffolding commands
    dir:  only creates project empty folders
    file: only creates project files
    post: runs post-scaffolding commands

By default, if an error occurs during scaffolding, the script ends and exits
with an error code. However, if optional argument --ignore-err is given, the
encountered errors are ignored and scaffolding continues. 

By default the scaffolding is generated under 'Project' folder. To override
it, use -d option and set the project name to something else.
FILE_CONTENT

__HEREDOC_SECTION__

################################################################################
# main entry of the script
main: {
    &SetupProject(@ARGV);
}

1;

################################################################################
# POD

=pod

=back

=head2 Version

00.01.00.a

=head2 Author

Mojtaba Mansour Abadi

=cut

################################################################################
# embedded data
__DATA__
__DATA_SECTION__
