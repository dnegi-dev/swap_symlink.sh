#!/usr/bin/env bash

# A script for changing the targets of a defined symlink target.
# Automaticaly detacts the possible sources for the symlink if used with the -p option
# or set it manually with --source1 and --source2
#
# 2023 Daniel Ravi Negi, <contact@dnegi.dev>

set -e

display_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   -d, --dir <path>             Path to the target directory"
    echo "   -p, --possible-value <path>  Path to a possible source for the symlink, located in --dir <path>, can be used multiple times"
    echo "   -t, --target <path>          Name of the symlink target, located in --dir <path>"
    echo "   --source1 <path>             Name of the first source for the symlink, located in --dir <path>"
    echo "   --source2 <path>             Name of the second source for the symlink, located in --dir <path>"
    echo "   --help                       Display this help message"
    echo  
    echo "Example: $0 -d /example/path/ -p example_source1 -p example_source2 -t example_target"
    echo "Example: $0 -d /example/path/ --source1 example_source1 --source2 example_source2 -t example_target"
    echo
    echo "If -p is used, the script will automatically detect the possible sources for the symlink, if more than two sources are found, the script will abort."
    echo "If --source1 and --source2 are used, the script will use the given sources for the symlink."
    echo "If -p and --source1 or --source2 are used, the script will abort."
    echo
    echo "Possible environment variables:"
    echo "   \$CONFIG_PATH                Path to the target directory"
    echo "   \$POSSIBLE_VALUES            Array of possible sources for the symlink, located in \$CONFIG_PATH. Use space as delimiter."
    echo "   \$TARGET                     Name of the symlink target, located in \$CONFIG_PATH"
    echo "   \$SOURCE1                    Name of the first source for the symlink, located in \$CONFIG_PATH"
    echo "   \$SOURCE2                    Name of the second source for the symlink, located in \$CONFIG_PATH"
    echo
    echo "Commandline arguments take precedence over environment variables."
    echo
    echo "Return codes:"
    echo "   0                            Script finished successfully"
    echo "   1                            Error while parsing arguments"
    echo "   2                            Error while executing script"
    echo "   3                            Error while setting symlink"
    echo
    echo "Report bugs to <contact@dnegi.dev>"
    exit 1
}

if ! TEMP=$(getopt -o 'c:d:hp:t:' --long 'config:,dir:,source1:,source2:,target:,help,possible-value:' -- "$@"); then
        echo 'Terminating...' >&2
        exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case "$1" in
        '-d'|'--dir')
            CONFIG_PATH="${2%/}"
            shift 2
            continue
        ;;
        '-p'|'--possible-value')
            POSSIBLE_VALUES+=("$2")
            shift 2
            continue
        ;;
        '-t'|'--target')
            TARGET=$2
            shift 2
            continue
        ;;
        '--source1')
            SOURCE1="$2"
            shift 2
            continue
        ;;
        '--source2')
            SOURCE2="$2"
            shift 2
            continue
        ;;
        '-h'|'--help')
            display_help
            shift
            continue
        ;;
        '--')
            shift
            break
        ;;
        *)
            echo "Error while parsing arguments!"
            exit 1
        ;;
    esac
done

error_output() {
    error_msg=$2
    exit_code=$1

    echo "---------"
    echo "$error_msg"
    echo "---------"

    echo ""
    echo "Script aborted at:"
    date "+%Y-%m-%d %H:%M:%S %z"
    echo ""
    exit "$exit_code"
}

echo ""
echo "Script started at:"
date "+%Y-%m-%d %H:%M:%S %z"
echo ""


if [ -z "$CONFIG_PATH" ];then
    error_output 2 "Set \$CONFIG_PATH or pass argument with --config \"/example/path/file/\"!" 
fi

if [ -z "$TARGET" ];then
    error_output 2 "Set \$TARGET or pass argument with --target \"example.file\"!"
fi

if ! hash basename
then
    error_output 2 "Could not find or execute \"basename\" command. The command is part of the GNU coreutils!"
fi

if ! hash readlink
then 
    error_output 2 "Could not find or execute \"readlink\" command. The command is part of the GNU coretuils!"
fi

if [ ${#POSSIBLE_VALUES[@]} -eq 0 ] ;then
    if [ -z "$SOURCE1" ] || [ -z "$SOURCE2" ];then
        error_output 2 "Set \$POSSIBLE_VALUES or pass multiple arguments with \"-p example_source1 -p example_source2\""
    fi
else
    if [ -n "$SOURCE1" ] || [ -n "$SOURCE2" ];then
        error_output 2 "It is not possible to use \$POSSIBLE_VALUES or -p together with --source1, --source2 or \$SOURCE1 \$SOURCE2!"
    fi
    for POSSIBLE_VALUE in "${POSSIBLE_VALUES[@]}";do
        if [ -e "$CONFIG_PATH"/"$POSSIBLE_VALUE" ];then
            if [ -z "$SOURCE1" ];then
                echo "Found $POSSIBLE_VALUE in $CONFIG_PATH. Setting saving it in \$SOURCE1"
                SOURCE1="$POSSIBLE_VALUE"
            elif [ -z "$SOURCE2" ];then
                echo "Found $POSSIBLE_VALUE in $CONFIG_PATH. Setting saving it in \$SOURCE2"
                SOURCE2="$POSSIBLE_VALUE"
            else
                error_output 3 "Found more than two possible sources. Use --source1 <file1> --source2 <file2> to explicitly set the sources for the symlink!"
            fi
        fi
    done
fi

if ! CURRENT_TARGET=$(readlink "$CONFIG_PATH"/"$TARGET");then
    if [ ! -s "$CONFIG_PATH"/"$CURRENT_TARGET" ];then
        error_output 2 "\$CURRENT_TARGET $CURRENT_TARGET does not exists or has size of zero. Please create it before running this script!"
    else
        error_output 2 "\$CURRENT_TARGET is not a symbolic link!"
    fi
fi

CURRENT_TARGET_FILE=$(basename -- "$CURRENT_TARGET")
echo "Set \$CURRENT_TARGET_FILE to $CURRENT_TARGET_FILE"

if [ "$CURRENT_TARGET_FILE" = "$SOURCE1" ];then
    if ln -sf "$CONFIG_PATH"/"$SOURCE2" "$CONFIG_PATH"/"$TARGET"
    then
        echo "Set $TARGET symlink to $CONFIG_PATH/$SOURCE2"
    else
        error_output 3 "$TARGET symlink could not be set to $CONFIG_PATH/$SOURCE2"
    fi
elif [ "$CURRENT_TARGET_FILE" = "$SOURCE2" ] ;then
    if ln -sf "$CONFIG_PATH"/"$SOURCE1" "$CONFIG_PATH"/"$TARGET"
    then
        echo "Set $TARGET symlink to $CONFIG_PATH/$SOURCE1"
    else
        error_output 3 "$TARGET symlink could not be set to $CONFIG_PATH/$SOURCE1"
    fi
else
    error_output 3 "No match between existing symlink and given source options"
fi

echo ""
echo "Script finished at:"
date "+%Y-%m-%d %H:%M:%S %z"
echo ""
