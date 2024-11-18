#!/usr/bin/env bash
# shellcheck disable=all

#-------------- options --------------

set -e          # stop on any command fail
set -E          # generate ERR exception on aliases, functions, and commands in if/while/until conditions
set -u          # stop on any unbound variable
set -o pipefail # stop on any fail with pipe
set -o errtrace # print call trace on errors

local old_xtrace=$(shopt -po xtrace) # save xtrace builtin option
$old_xtrace                          # restore it!

#-------------- GLOBS --------------

compgen -G '/**/*.gz'   # expand the glob
compgen -G '*.bak'

#-------------- REDIRECTIONS --------------

exec >&2                # all output to stderr
cmd 3>&1 1>&2 2>&3      # swap stdin and stderr
cmd > >(stdout pipe)  2> >(stderr pipe) # process stdout/stderr in subshells

# VARIABLES

ref="name"
name="John"
length=2

#-------------- References ------------------------
echo ${!ref}       #=> "John"

arref='names'
names=( John Mike Mark )
array="${arref}[@]"
for n in "${!array}"; do
  echo $n
done

#-------------- Heredocs/Herestrings ---------------
cat <<END
name=$name
END
==> name=John

cat <<"END"
name=$name
END
==> name=$name

cat <<-END
[tab]  hello
END
==> '  hello'

cat <<<"name=$name"
==> name=John

# multiline assignment
read -r -d '' VAR << END
line 1
line 2
END


#-------------- Slice ----------------------------
echo ${name/J/j}       #=> "john" (substitution)
echo ${name:0:2}       #=> "Jo" (slicing)
echo ${name::2}        #=> "Jo" (slicing)
echo ${name::-1}       #=> "Joh" (slicing)
echo ${name:(-1)}      #=> "n" (slicing from right)
echo ${name:(-2):1}    #=> "h" (slicing from right)
echo ${name:0:length}  #=> "Jo"
echo ${#name}          #=> 4 (length)

#-------------- Defaults -------------------------
echo "${food:-Cake}"  # => $food or "Cake"
FOO=${FOO:=val}       # Set $FOO to val if not set
${FOO:+val}           # val if $FOO is set
${FOO:?message}       # Show error message and exit if $FOO is not set

#-------------- Substitution -------------------------
STR="/path/to/foo.cpp"
echo ${STR%.cpp}     # /path/to/foo     | remove suffix
echo ${STR#*/}       # path/to/foo.cpp  | remove short prefix
echo ${STR##*/}      # foo.cpp          | remove longest prefix
echo ${STR/foo/bar}  # /path/to/bar.cpp | replace
echo ${STR/%foo/bar} # /path/to/bar.cpp | replace suffix/prefix...
echo ${STR//o/X}     # /path/tX/fXX.cpp | replace all

SRC="/path/to/foo.cpp"
BASE=${SRC##*/}   #=> "foo.cpp" (basepath)
DIR=${SRC%$BASE}  #=> "/path/to/" (dirpath)

NL="abc\nxyz\n"
NL=${NL//$'\n'/} # "abcxyz"    | Remove all newlines.
NL=${NL%$'\n'}   # "abc\nxyz"  | Remove a trailing newline.

#-------------- Case manipulation -------------------------
STR="HELLO WORLD!"
echo "${STR,}"   #=> "hELLO WORLD!" (lowercase 1st letter)
echo "${STR,,}"  #=> "hello world!" (all lowercase)
STR="hello world!"
echo "${STR^}"   #=> "Hello world!" (uppercase 1st letter)
echo "${STR^^}"  #=> "HELLO WORLD!" (all uppercase)

#-------------- Cycles -------------------------
for i in {5..50..5}; do ..; done # 5 to 50 step 5
for ((i = 0 ; i < 100 ; i++)); do ..; done

#-------------- Conditions -------------------------
[[ -z "$STRING" ]]      # Empty string
[[ -n "$STRING" ]]      # Not empty string
[[ STRING == STRING ]]  # Equal
[[ STRING != STRING ]]  # Not Equal
[[ NUM -eq NUM ]]       # Equal
[[ NUM -ne NUM ]]       # Not equal
[[ NUM -lt NUM ]]       # Less than
[[ NUM -le NUM ]]       # Less than or equal
[[ NUM -gt NUM ]]       # Greater than
[[ NUM -ge NUM ]]       # Greater than or equal
[[ STRING =~ REGEXP ]]  # POSIX Regexp NB: Do not quote regexp!
[[ STR == *SUBSTR* ]]   # STR contains SUBSTR. NB: STR can be an array!
(( NUM < NUM ))         # Numeric conditions
[[ -o noclobber ]]      # If OPTIONNAME is enabled
[[ ! EXPR ]]            # Not
[[ X ]] && [[ Y ]]      # And
[[ X ]] || [[ Y ]]      # Or
[[ -e FILE ]]           # File Exists
[[ -r FILE ]]           # File Readable
[[ -h FILE ]]           # Is Symlink
[[ -d FILE ]]           # Is Directory
[[ -w FILE ]]           # Is Writable
[[ -s FILE ]]           # File Size is > 0 bytes
[[ -f FILE ]]           # Is File
[[ -x FILE ]]           # Is Executable
[[ FILE1 -nt FILE2 ]]   # 1 is more recent than 2
[[ FILE1 -ot FILE2 ]]   # 2 is more recent than 1
[[ FILE1 -ef FILE2 ]]   # Same files

#-------------- PIPES  -------------------------
false | true
echo "${PIPESTATUS[0]} ${PIPESTATUS[1]}" # 1 0

#-------------- Arrays -------------------------
Fruits=('Apple' 'Banana' 'Orange')
Fruits[2]="Orange"

echo ${Fruits[0]}           # Element #0
echo ${Fruits[@]}           # All elements, space-separated
echo ${#Fruits[@]}          # Number of elements
echo ${#Fruits}             # String length of the 1st element
echo ${#Fruits[3]}          # String length of the Nth element
echo ${Fruits[@]:3:2}       # Range (from position 3, length 2)

Fruits=("${Fruits[@]}" "Watermelon")    # Push
Fruits+=('Watermelon')                  # Also Push
Fruits=("${Fruits[@]:1}")               # Pop the FIRST element
Fruits=( ${Fruits[@]/Ap*/} )            # Remove by regex match
unset Fruits[2]                         # Remove one item
Fruits=("${Fruits[@]}" "${Veggies[@]}") # Concatenate
lines=(`cat "logfile"`)                 # Read from file
for i in "${Fruits[@]}"; do ..; done # Iteration
IFS=', ' read -r -a array <<< "$string" # String -> Array

#-------------- Hashes -------------------------
declare -A sounds
sounds[dog]="bark"

echo "${sounds[dog]}" # Dog's sound
echo "${sounds[@]}"   # All values
echo "${!sounds[@]}"  # All keys
echo "${#sounds[@]}"  # Number of elements
unset "sounds[dog]"   # Delete dog
declare -A ha=(["key1"]="value1", ["key2"]="value2")

for val in "${sounds[@]}"; do ..; done  # iterate over values
for key in "${!sounds[@]}"; do ..; done # iterate over keys

#-------------- getopts -----------------------#
# first ':' sets silent error checking. Unless bash will print errors (option not found, etc)
# Argument list is unchanged.
while getopts ":nt:" opt; do          # n - no args, t - need arg
  case "${opt}" in
    n)
      echo "-n specified!"
      ;;
    t)
      echo "-t ${OPTARG} specified!"
      ;;
    :) # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      ;;
    ?) # If unknown (any other) option:
      echo "Don't know option ${OPTARG}"
      ;;
  esac
done
echo "last index was: ${OPTIND}" # bash automatically increments it. To call getopts cycle again set it to 1

#-------------- Usefull -----------------------
# The : built-in can be used to avoid repeating variable=
# in a case statement. The $_ variable stores the last
# argument of the last command
case "$OSTYPE" in
    "darwin"*)
        : "MacOS"
    ;;
    "linux"*)
        : "Linux"
    ;;
esac
# Finally, set the variable.
os="$_"

#-------------- Other tricks -------------------------
"$SECONDS"            # Number of seconds the scipt is running
val=$((RANDOM%=200))  # Random number 0..200
read -n 1 ans         # Just one character
read -p 'Enter number: ' -s -t 10 ans # Use prompt, do not show entered symbols, timeout in 10 sec
while read x; do echo "$x"; done < <(cat file) # process input in `while read` without subshell

# Path to curent script
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Convert decimal string in var MYVAR to a number even with leading 0
$((10#MYVAR))

# escape any tring!!!
estr=$(printf "%q" "$str")

# float math!!!!
awk "BEGIN { print 25/7 }"


# Is the executable in the PATH? (two options)
command -v executable_name &>/dev/null
type -p executable_name &>/dev/null
# get the FIRST occurence of the pattern:
# Usage: regex "string" "regex"
regex() {
    [[ $1 =~ $2 ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}

# read a file contents into a variable
file_data="$(<"file")"

# read a file contents into an array
mapfile -t file_data < "file"
# read first 10 lines of a file into an array
mapfile -tn 10 file_data < "file"


# ------ Get forst/last day of previous month -------
first_day=$(date -d "`date +%Y%m01` -1 month" +%Y%m%d)
last_day=$(date -d "`date +%Y%m01` -1 day" +%Y%m%d)    # out format can be changed


# ------ Trap many signals -------
# stolen from here: https://stackoverflow.com/questions/2175647/is-it-possible-to-detect-which-trap-signal-in-bash
trap_with_arg() {
    func="$1" ; shift
    for sig ; do
        trap "$func $sig" "$sig"
    done
}

trap_with_arg func_trap INT TERM EXIT

# ------ Check if script is sourced or not -------
(return 0 2>/dev/null) && _SOURCED_=true || _SOURCED_=false
if ! ${_SOURCED_:-false}; then
  # Not sourced
fi

# ------ Require some programs to be installed ------
function require() {
    for function_to_hash in "${@}"; do
        local function_exists="$(command -v "${function_to_hash:-}" 2>/dev/null || :)"
        if [[ -z "${function_exists:-}" ]]; then
            echo "missing command ${function_to_hash:-}"; exit 1
        fi
        hash -p "${function_exists}" "${function_to_hash}"
    done
}


# ------ COLORS -----------
#
# \e[CODE;[CODE;...]m = apply sequence of codes
#
#
CODES:
0 	Reset / Normal 	all attributes off
1 	Bold or increased intensity
3 	Italic 	Not widely supported. Sometimes treated as inverse.
4 	Underline 	
5 	Slow Blink 	less than 150 per minute
7 	[[reverse video]] 	swap foreground and background colors
10 	Primary(default) font 	
11–19 	Alternate font 	Select alternate font n-10
21  Bold off
22 	Normal color or intensity 	Neither bold nor faint
24 	Underline off 	Not singly or doubly underlined
25 	Blink off 	
27 	Inverse off 	
30–37 	Set foreground color 	See color table below
38 	Set foreground color 	Next arguments are 5;<n> or 2;<r>;<g>;<b>
39 	Default foreground color 	implementation defined (according to standard)
40–47 	Set background color 
48 	Set background color 	Next arguments are 5;<n> or 2;<r>;<g>;<b>
49 	Default background color 	implementation defined (according to standard)


\e[38;5;<NUM>m 	Set text foreground color (0-255)
\e[48;5;<NUM>m 	Set text background color (0-255)
# all codes:
for code in {0..255}
    do echo -e "\e[38;5;${code}m"'\\e[38;5;'"$code"m"\e[0m"
done

\e[0;30m 	Black
\e[0;31m 	Red
\e[0;32m 	Green
\e[0;33m 	Yellow
\e[0;34m 	Blue
\e[0;35m 	Purple
\e[0;36m 	Cyan
\e[0;37m 	White

"\e]11;#003000\a" # Change DEFAULT background color of teh terminal to RGB #003000

\e[2K                          - Clear Line
\e[<L>;<C>H or \\033[<L>;<C>f  - Put the cursor at line L and column C.
\e[<N>A                        - Move the cursor up N lines
\e[<N>B                        - Move the cursor down N lines
\e[<N>C                        - Move the cursor forward N columns
\e[<N>D                        - Move the cursor backward N columns
\e[2J                          - Clear the screen, move to (0,0)
\e[K                           - Erase to end of line
\e[s                           - Save cursor position
\e[u                           - Restore cursor position

#--------------- Check colors / UTF support ------------------

SUPPORTED_NUM_COLORS=$(tput colors)

is-tty-unicode() {  # true=0 / false=1
  local X

  test -c /dev/tty &&
  if test -t 0
  then IFS=$';\x1B[' read -p $'\r\xE2\x80\x8B\x1B[6n\r   \r' -d R -rst 1 _ _ _ X _ 2>&1
  fi <>/dev/tty && test "$X" = 1
}


# ============= AWK tricks ================

# get a group from regexp. Note: it is used INSTEAD of /.../ filter
# array index 0 = FULL match, 1 = 1st group, etc.
gawk 'match($0, /Node\[([^,]+)/, arr) { print arr[1]}'

# Join every 2 lines using ',' as separator:
awk 'NR%2 {printf "%s,",$0;next} {print;}' file
# or simpler:
paste - - -d, <file

# Print every N-th line:
awk -v n="$ct" 'NR % n {print}' file

#Print the LAST line:
awk 'END{print}' file

# wc implementation
awk '{ C += length($0) + 1; W += NF } END { print NR, W, C }'

# replace fields separators from '\t' to '|'
awk 'BEGIN { IFS="\t"; OFS = "|" } { $1 = $1; print }'

# delete duplicated lines (SORTED)
sort file | awk 'Last != $0 { print } { Last = $0 }'

# ignore empty lines
gawk 'BEGIN { RS="\n *\n" } { .... }'

# Arguments
BEGIN {
    print "ARGC =", ARGC
    for (k = 0; k < ARGC; k++)
        print "ARGV[" k "] = [" ARGV[k] "]"
}
# => awk -v One=1 -v Two=2 -f args.awk one file1 VAR=3
# ARGC = 6
# ARGV[0] = [awk]
# ARGV[1] = [one]
# ARGV[2] = [file1]
# ARGV[3] = [VAR=3]

# ENV
BEGIN {print ENVIRON["USER"]}  # myusername

# Key VARS:
FS: Field separator. Field=part of line. In POSIX - sible char, in gawk CAN be regexp ('.' is NOT a regexp)
RS: Record separator. Record=line. Empty = EOL
# a b c\n1 2 3  => Fileds [a b c], [1 2 3]; Records: [a],[b],[c],[1],[2],[3]
OFS,ORS: output field and recoed separators
NF: Number of fields (in the current record)
NR: Current record number
FILENAME: filename, being processed ('-' for stdin). Undefiled in BEGIN section

awk -v VAR=123 '{print VAR}' # set general purpose variables
awk -v I=5 '{print $I}'      # print 5-th column only

# AWK Selectors
(FNR == 3),(FNR == 10)      # Select lines 3..10
/^BEGIN/,/^END/             # Select lines from starting with 'BEGIN ...' to starting with 'END ...'
/abc*/                      # lines containing abc* regexp

