#!/bin/bash

#	multiprocdown - Fasten download processes with parallelism

#	Author: Rosario Andolina <andolinarosario@gmail.com>
#	Copyright (C) 2017  Rosario Andolina

#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.

#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.

#	You should have received a copy of the GNU General Public License along
#	with this program; if not, write to the Free Software Foundation, Inc.,
#	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# error flags
readonly VALUE_ERROR=1           # no value in options that requires one
readonly UK_OPT_ERROR=2          # unknown option
readonly REQ_OPT_ERROR=3         # missing required option
readonly USAGE=4                 # print usage
readonly CL_ERROR=5              # Content-Length is 0 or header is missing
readonly KILLED_ERROR=6          # killed with SIGHUP | SIGINT | SIGTERM
readonly OPT_CONFLICT_ERROR=8    # conflict with options
readonly FNF_ERROR=9             # file not found error
readonly NOS_ERROR=10            # not snapshot file error
readonly GP_ERROR=11             # gnuplot not found
readonly TOR_ERROR=12            # connection through Tor isn't possible

# tor flags
readonly TOR_INST_NOTRUN=1        # tor is installed but service not running
readonly TOR_INST_RUN=2          # tor is installed and service running
readonly TOR_NOTINST=3           # tor is't installed
torflag=0

readonly PROGNAME=$(basename $0)
readonly VERSION=2.1
readonly ERROR_SOUND="/home/rosario/programmi/bash/scarica/breaking-some-glass.ogg"
readonly NOTIFY_SOUND="/home/rosario/programmi/bash/scarica/demonstrative.ogg"
readonly TEMPDIR=/tmp/$PROGNAME
readonly Blue='\033[01;34m'
readonly White='\033[01;37m'
readonly Red='\033[01;31m'
readonly Green='\033[01;32m'
readonly E='\033[01;41m'
readonly W='\033[01;43m'
readonly Reset='\033[00m'

mkdir -p $TEMPDIR

pplot=$TEMPDIR/progress.data
[[ -e $pplot ]] && rm $pplot

gplt_script=$TEMPDIR/gplt_script.plt
[[ -e $gplt_script ]] && rm $gplt_script

alias cvlc="cvlc -q --no-loop --play-and-exit"

url=""
declare -i nthreads=10         # threads number
output=""                      # output file name
verbose=false
usedd=false
md5=""                         # md5 value
sha1=""                        # sha1 value
checksum=""
graph=false
first=false
chunks_rate=(100)              # the FORMAT of --first option
declare -i nchunks=1           # default chunks num with --first option
declare -i chunksize
savesnap=false                 # save snapshot if true
snapfileS=""                   # snapshot file to save
thsnaps=()                     # snapshot threads start byte
thsnapbc=()                    # snapshot threads bytes copied
loadsnap=false
snapfileL=""                   # snapshot file to load
loadedst=()                    # loaded threads snapshot start and stop
usetor=false                   # connect through Tor
proxy=""


#_______________________________________________________________________
function print_usage
{
    echo
    echo "Usage: $PROGNAME -u URL | --url[=]URL [OPTIONS]..."
    echo 
    echo "\"$PROGNAME\" is a multiprocess download utility very useful for"
    echo "big files. It uses curl, downloading N chunk of the file in parallel"
    echo
    echo "Mandatory arguments to long options are mandatory for short options too."
    echo
    echo "Required mutual exclusive:"
    echo
    echo "  -u, --url[=]URL          the URL of the file to be downloaded"
    echo
    echo "  -l, --load-snapshot[=]SNAP_FILE"
    echo "                           load a saved snapshot to exhume the download"
    echo
    echo "Options:"
    echo 
    echo "  -n, --nthreads[=]N       [10] the number of threads used for parallel"
    echo "                             download"
    echo
    echo "  -o, --output[=]F_OUT     the output file name"
    echo
    echo "  -v, --verbose            print more info on stdout"
    echo
    echo "  -d, --use-dd             use dd to write the chunks relating to each thread on"
    echo "                             the same file, in this way, while downloading a video"
    echo "                             you can see a preview (see -f,--first option)"
    echo
    echo "  --md5[=]VALUE            calculates the md5sum of the output file and"
    echo "                             compares with VALUE"
    echo
    echo "  --sha1[=]VALUE           calculates the sha1sum of the output file and"
    echo "                             compares with VALUE"
    echo
    echo "  -g, --enable-graph       enables a progress graph."
    echo 
    echo "  -f, --first[=FORMAT]      download first the initial part of the file and then"
    echo "                              the rest, according to the FORMAT. dd is used by default"
    echo
    echo "  -s, --save-snapshot[=SNAP_FILE]"
    echo "                           if the script exit save a snapshot of the current download"
    echo "                             the download may be exhumed by loading the snapshot, if"
    echo "                             the url is still valid. See -l, --load-snapshot"
    echo
    echo "  -a, --anonimous          if possible uses Tor proxyes"
    echo
    echo "  -h, --help               print this message and exit unsuccesfully"
    echo
    echo "  -V, --version            print program name and version and exit unsuccesfully"
    echo
    echo
    echo "Option -g, --enable-graph display a bar plot showing the progress percetage"
    echo "of every single thread. \"gnuplot\" is required."
    echo 
    echo "The -f, --first option is useful when you whant to watch a video while"
    echo "downloading. The progress graph will be disabled"
    echo
    echo "the SNAP_FILE, if not specified, will have .snp extention and the same"
    echo "name of the output file"
    echo
    echo "FORMAT is a semicolon separated sequence of chunks rate in percentage, if"
    echo "no FORMAT is provided the default is 20:20:20:20:20 that means five chunks"
    echo "of 20% of the file dimension each"
    echo
    echo "FORMAT examples:"
    echo
    echo "5:5:10:30:50       download 5% first with N threads and then 5% N threads etc."
    echo "1:5:10:20:20:44    is good if you want to see video files large pier"
    echo "                     while downloading."
    echo "the FORMAT sequence will be stoped when the sum of the chunks rate exceeds 100"
    echo "the possible difference will be added to the last chunk"
    echo
}

#___________________________________________________________________________
# print download duration in human readable format
function human_time
{
    local t=$1
    local i=0
    local convf=(60 60 24 365)
    local sep=("s" "m" "h" "d" "y")
    local out=""
    local r
    while [[ $i -lt ${#convf[@]} && $t -gt 0 ]]; do
        r=$[$t%${convf[$i]}]
        t=$[$t/${convf[$i]}]
        out=" $r${sep[$i]}$out"
        i=$[$i+1]
    done
    [[ $t != 0 ]] && out="$t${sep[$i]}$out"
    echo $out
}

#___________________________________________________________________________
# play error or notification sounds
function Play
{
    local players=(paplay cvlc mplayer)
    for p in $players; do
		echo "$p $1"
        which "$p" &> /dev/null && "$p" "$1" &> /dev/null && break
    done
}

#_______________________________________________________________________
function check_tor
{
    which tor &> /dev/null || torflag=$TOR_NOTINST
    if [[ $torflag -eq 0 ]]; then
        pgrep tor &> /dev/null && torflag=$TOR_INST_RUN || torflag=$TOR_INST_NOTRUN
    fi
}

#_________________________________________________________________________
# exit with a specific error code
function exit_error
{
    case $1 in
        $VALUE_ERROR)
        printf "${E}Error:${Reset} option %s needs a value\nexiting...\n" "$2" 1>&2
        exit $VALUE_ERROR
        ;;
        $UK_OPT_ERROR)
        printf "Unknown option %s\nexiting...\n" "$2" 1>&2
        exit $UK_OPT_ERROR
        ;;
        $REQ_OPT_ERROR)
        printf "${E}Error:${Reset} option %s is required\nexiting...\n" "$2" 1>&2
        exit $REQ_OPT_ERROR
        ;;
        $USAGE)
        print_usage 1>&2
        exit $USAGE
        ;;
        $CL_ERROR)
        printf "${E}Error:${Reset} content length is 0\n" 1>&2
        printf "the number of bytes downloaded by a single thread cannot be calculated\n\n" 1>&2
        curl $proxy -sI "$2" 1>&2
        printf "try with wget or curl directly\n\n" 1>&2
        Play $ERROR_SOUND
        exit $CL_ERROR
        ;;
        $KILLED_ERROR)
        printf "\n${E}Process killed by %s${Reset}\n" "$2" 1>&2
        exit $KILLED_ERROR
        ;;
        $OPT_CONFLICT_ERROR)
        printf "${E}Error:$Reset option %s and %s are in conflict\n" "$2" "$3" 1>&2
        exit $OPT_CONFLICT_ERROR
        ;;
        $FNF_ERROR)
        printf "${E}Error:$Reset file %s not found\n" "$2" 1>&2
        exit $FNF_ERROR
        ;;
        $NOS_ERROR)
        printf "${E}Error:$Reset file %s isn't a snapshot\n" "$2" 1>&2
        exit $NOS_ERROR
        ;;
        $GP_ERROR)
        printf "${E}Error:$Reset gnuplot not found.\nexiting...\n" 1>&2
        exit $GP_ERROR
        ;;
        $TOR_ERROR)
        printf "${E}Error:$Reset %s\n" "$2" 1>&2
        exit $TOR_ERROR
        ;;
    esac
}

#______________________________________________________________________________
# save shapshot if killed
function save_snapshot
{
    [[ $savesnap == false ]] && return
    rm -f $snapfileS
    local bc offset
    echo "#$PROGNAME snapshot file" >>"$snapfileS"
    echo "$output" >> "$snapfileS"
    echo "$url" >> "$snapfileS"
    echo "$usedd" >> "$snapfileS"
    echo "${chunks_rate[@]}" >> "$snapfileS"
    echo "$[$cc-1]" >> "$snapfileS"
    echo "$snapstart" >> "$snapfileS"
    echo "$nthreads" >> "$snapfileS"
    bc=0
    for ((i=0;i<$nthreads;i++)); do
        tid=$[$i+1]
        if [[ $usedd == true ]]; then
            bc=$(tail -n1 $TEMPDIR/thread${tid}.data |awk '/bytes/ { print $1}') # bytes copied
            if [[ $bc == "" ]]; then
                bc=$(tail -n2 $TEMPDIR/thread${tid}.data |awk '/bytes/ { print $1}') # bytes copied
            fi
            thsnapbc[$i]=$[${thsnapbc[$i]}+$bc]
            thsnaps[$i]=$[${thsnaps[$i]}+${thsnapbc[$i]}-1]
        else
            [[ -e "${output}.part${tid}.tmp" ]] && bc=$(du -b "${output}.part${tid}.tmp" |awk '{ print $1 }')
            bc=$[$bc + $(du -b "${output}.part$tid" |awk '{ print $1 }')]
            thsnaps[$i]=$[${thsnaps[$i]}+$bc]
        fi
        bc=0
    done
    echo "${thsnaps[@]}" >> $snapfileS
    echo "${thsnapbc[@]}" >> $snapfileS

}

#______________________________________________________________________________
# remove and/or close opened files when killed
function clean_up
{
    #local f2rm
    if [[ $usedd == true ]]; then
        rm -f $TEMPDIR/${PROGNAME}*.log
    elif [[ $savesnap == false ]]; then
        rm -f "${output}.part*"
    fi
    
    exec 200<&-
    rm -f $lockfile
    exit_error $KILLED_ERROR $1
}

#______________________________________________________________________________
function get_chunks_rate
{
    local i=0
    local sum=0
    while read token; do
        sum=$[$sum+$token]
        [[ $sum -gt 100 ]] && break   # chunks are considered good while sum is less than 100
        chunks_rate[$i]=$token
        i=$[$i+1]
    done <<< $(echo $1 |tr ':' '\n')
}

#______________________________________________________________________________
# new download algorithm
function RunThread 
{
    # this function download a chunk of N bytes and write in the output
    # file using "dd". In this way all the chunks will be downloaded
    # together in parallel on the same file. Check if the chunk is completely
    # downloaded, otherwise will try to download it completely
    
    local threadID=$1
    local fstart=$2                     # the start byte
    local fstop=$3                      # the stop byte
    local foffset=$fstart               # the offset byte to continue an incomplete download
                                        # initialized to start byte
    local flog=$TEMPDIR/${PROGNAME}T${threadID}.log   # curl log file, needed for checking errors
    local fdata=$TEMPDIR/thread${threadID}.data     # file of data to plot threads statistics
    local ddargs="oflag=seek_bytes conv=notrunc,sparse status=progress"
    #local proxy=""
    local bytes_copied=0
    
    trap "rm -f $flog; exit $KILLED_ERROR" INT TERM
    # acquire lock to write messages on stdout
    if [[ $verbose == true ]]; then
    (
        flock -n 200
        printf "\rThread${Blue}%d${Reset} %d - %d\n" $threadID $fstart $fstop
    )200>>$lockfile
    fi
    [[ -e $fdata ]] && rm $fdata
    while [[ $foffset -lt $fstop ]]; do
        # download (fstop-foffset)
        # if the foffset byte is equal to the fstop byte then the thread's chunk
        # is completely downloaded
        
        # curl donwnload the chunk and dd write on $output in the foffset position
        # the dd's progress informations will be written to a file. stdbuf -oL force the flush on stdout line by line
        # the flush is needed because threads progress will be plotted using gnuplot if required
        curl -f --range ${foffset}-${fstop} $proxy "$url" 2>$flog | dd of="$output" $ddargs seek=$foffset 2>&1 | stdbuf -oL tr '\r' '\n' >> $fdata
        
        # if the connection drop continue the download updating the offset
        bytes_copied=$(tail -n1 $fdata | stdbuf -oL awk '/bytes/ { print $1 }')
        foffset=$[$fstart+$bytes_copied-1]
        grep -q error $flog
        if [[ $? -eq 0 ]]; then
            # the server has sent an error message
            # maybe it only accepts a limited number of connections from the same IP address
            (
                flock -n 200
                printf "\r${White}Thread${Blue}%d${Reset} interrupted by the server. Will restart ASAP\n" $threadID
            )200>>$lockfile
            sleep 0.5
            # counts the number of active connections
            local active_conn=$(pgrep -c curl)
            while [[ $(pgrep -c curl) -ge $active_conn ]]; do
                sleep 1  # sleep until one or more active connections have finished their work
            done
            (
                flock -n 200
                printf "\r${White}Thread${Blue}%d ${Reset}restarted\n" $threadID
            )200>>$lockfile
        elif [[ $foffset -lt $fstop ]]; then
            (
                flock -n 200
                printf "\r${White}Thread${Blue}%d ${Reset}connection dropped and restarted\n" $threadID
            )200>>$lockfile
        fi
    done
        
}

#______________________________________________________________________________
# old download algorithm
function StartThread
{
    # this function download a chunk of N bytes on the file ffname and check if
    # it is completely downloaded, otherwise will try to download it 
    # completely. This function will be executed in parallel
    
    local threadID=$1
    local fstart=$2
    local fstop=$3
    local fsize=0
    local foffset=$fstart
    local fdropcflag=0                  # flag for dropped connection
    local ffname="${output}.part${threadID}"
    
    if [[ $loadsnap == true ]]; then
        fdropcflag=1
        [[ -e "${ffname}.tmp" ]] && cat "${ffname}.tmp" >> "$ffname"
    else
        touch "$ffname"
    fi
    
    trap "exit $KILLED_ERROR" INT TERM
    while [ $foffset -lt $fstop ]; do
        # download (fstop-foffset) bytes of the file in a temp file
        # if the foffset byte is equal to the fstop byte then the chunk
        # is completely downloaded
        curl -s --range ${foffset}-${fstop} $proxy "$url" > "${ffname}.tmp"
        if [ -e "${ffname}.tmp" ]; then
            grep ERROR "${ffname}.tmp" >> /dev/null
            if [ $? -eq 0 -a "$(file \"${ffname}.tmp\" |awk '{ print $2 }')" == "HTML" ]; then
                # the server has sent an error message
                # maybe it only accepts a limited number of connections from the same IP address
                echo -e "${White}Thread${Blue}$threadID ${Reset}interrupted by the server. Will restart ASAP"
                sleep 0.5
                # counts the number of active connections
                local active_conn=$(pgrep -c curl)
                while [[ $(pgrep -c curl) -ge $active_conn ]]; do
                    sleep 1  # sleep until one or more active connections have finished their work
                done
                echo -e "${White}Thread${Blue}$threadID ${Reset}restarted"
            else
                fsize_temp=$(du -b "${ffname}.tmp" |awk '{ print $1 }')
                foffset=$[$foffset+$fsize_temp]  # -1 because the file starts from byte 0
                cat "${ffname}.tmp" >> "$ffname" # copy the temporary data in the file for the current chunk
                if [[ $foffset -lt $fstop ]]; then
                    # the connection has been dropped
                    echo -e "${White}Thread${Blue}$threadID ${Reset}the connection has been dropped. Recovery connection"
                    fdropcflag=1  # the temp file can't be renamed because incomplete
                fi
            fi
        fi
    done
    if [ $fdropcflag -eq 0 ]; then   # temp. file is complete
        mv "${ffname}.tmp" "$ffname" # just rename the file
    else
        # temp. file was alredy copied in ffname
        rm -f "${ffname}.tmp"
    fi
}

#______________________________________________________________________________
function progress_bar
{
    declare -i actual_fdim=0
    declare -i last_fdim
    declare -i down_rate
    declare -i percent
    local cols=`tput cols`
    local barlength=$[$cols-($cols/3)]
    bar=`printf "%${barlength}s" "" |tr ' ' '#'`
    while true; do
        sleep 1
        last_fdim=$actual_fdim
        actual_fdim=0
        if [[ $usedd == true ]]; then
            actual_fdim=$(du -B 1 "$output" |awk '{ print $1 }')
        else
            for f in ${output}.part*; do
                [[ -e "$f" ]] && actual_fdim+=$(du -b "$f" |awk '{ print $1 }')
            done
        fi
        down_rate=$[($actual_fdim - $last_fdim)/1024]  # /1024 in KB/s
        percent=$[($actual_fdim*100)/$content_length]
        # acquire lock
        (
            flock -n 200
            printf " [%-${barlength}s] %3d%% %6d KB/s\r" "${bar:0:$[(${#bar}*$percent)/100]}" $percent $down_rate
        )200>>$lockfile
        # break if there are no more curl process
        [[ $(pgrep -c curl) -eq 0 ]] && break
    done
}

#______________________________________________________________________________
function progress_graph
{
    # write gnuplot script
    printf "set boxwidth 0.75\n" >> $gplt_script
    printf "set style fill solid\n" >> $gplt_script
    printf "set title \"%s\"\n" $output >> $gplt_script
    printf "set xrange [0:%s]\n" $[$nthreads+1] >> $gplt_script
    printf "set yrange [0:110]\n" >> $gplt_script
    printf "plot \"%s\" using 1:3:xtic(2) with boxes\n" $pplot >> $gplt_script
    printf "pause 1\n" >> $gplt_script
    printf "reread\n" >> $gplt_script
    
    # write data for gnuplot
    declare -i actual_bytes
    local percent=0
    local chunk_size=$[$content_length/$nthreads]
    local ILchunk_size=$chunk_size
    #printf "chunk_size = %s\n" $chunk_size $test
    local plotdata
    trap "rm -f $pplot; exit $KILLED_ERROR" INT TERM
    while : ;do
        [[ $(pgrep -c curl) -eq 0 ]] && break
        plotdata=""
        actual_bytes=0
        for ((i=1;i<=$nthreads;i++)); do
            [[ $i -eq $nthreads ]] && ILchunk_size=$[$chunk_size+$rest] #&& printf "actual_bytes %d\n" $actual_bytes
            if [[ $usedd == true ]]; then
                actual_bytes=$(tail -n1 $TEMPDIR/thread${i}.data | awk '/bytes/ { print $1 }')
                [[ $loadsnap == true ]] && actual_bytes=$[$actual_bytes+thsnapbc[$[$i-1]]]
            else
                [[ -e "${output}.part$i.tmp" ]] && actual_bytes=$(du -b "${output}.part$i.tmp" |awk '{ print $1 }')
                actual_bytes=$[$actual_bytes+$(du -b "${output}.part$i" |awk '{ print $1 }')]
            fi
            [[ $actual_bytes != 0 ]] && percent=$[($actual_bytes*100)/$ILchunk_size]
            plotdata+="$i T$i $percent   \n"
            #printf "\nthread${Red}$i$Reset ab: %s\t cs: %s\n" $actual_bytes $ILchunk_size
            actual_bytes=0
            ILchunk_size=$chunk_size
        done
        echo -en $plotdata |dd of=$pplot seek=0 status=none
        sleep 1
    done
    rm $pplot
}

#______________________________________________________________________________
function touch_output
{
    if [ -e "$output" ]; then
        while true; do
            printf "the file %s already exists, do you want to overwrite? [y/n] " "$output"
            read
            case $REPLY in
                y|yes|Y|Yes|YES)
                rm "$output"
                break
                ;;
                n|no|No|N|NO)
                findex=1
                prefix="${output%%.*}"
                postfix="${output##*.}"
                while [ -e "$output" ]; do
                    output="${prefix}($findex).${postfix}"
                    #output="${output%%.*}($findex).${output##*.}"
                    findex=$[$findex+1]
                done
                break
                ;;
                *)
                printf "\r"
                ;;
            esac
        done
        touch "$output"
    else
        touch "$output"
    fi
}

# print usage and exit
[[ $# -eq 0 ]] && exit_error $USAGE

#check_tor

mkdir -p /tmp/lock
lockfile="/tmp/lock/${PROGNAME}$$.lock"
exec 200>$lockfile

# parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
        exit_error $USAGE
        ;;
        -V|--version)
        printf "\n%s version %s\n\n" $PROGNAME $VERSION
        exit 7
        ;;
        -v|--verbose)
        verbose=true
        ;;
        -u|--url)
        [[ "$2" == -* || "$2" == --* || "$2" == "" ]] && exit_error $VALUE_ERROR $1
        url="$2"
        shift
        ;;
        --url=*)
        url="${1#*=}"
        [[ "$url" == "" ]] && exit_error $VALUE_ERROR "${1%=*}"
        ;;
        -n|--nthreads)
        [[ "$2" == -* || "$2" == --* || "$2" == "" ]] && exit_error $VALUE_ERROR $1
        nthreads=$2
        shift
        ;;
        --nthreads=*)
        nthreads=${1#*=}
        [[ $nthreads == "" ]] && exit_error $VALUE_ERROR ${1%=*}
        ;;
        -o|--output)
        [[ "$2" == -* || "$2" == --* || "$2" == "" ]] && exit_error $VALUE_ERROR $1
        output="$2"
        shift
        ;;
        --output=*)
        output="${1#*=}"
        [[ "$output" == "" ]] && exit_error $VALUE_ERROR ${1%=*}
        ;;
        -d|--use-dd)
        usedd=true
        ;;
        --md5)
        [[ $2 == -* || $2 == --* || $2 == "" ]] && exit_error $VALUE_ERROR $1
        md5=$2
        checksum=md5sum
        shift
        ;;
        --sha1)
        [[ $2 == -* || $2 == --* || $2 == "" ]] && exit_error $VALUE_ERROR $1
        sha1=$2
        checksum=sha1sum
        shift
        ;;
        --md5=*)
        md5=${1#*=}
        [[ $md5 == "" ]] && exit_error $VALUE_ERROR ${1%=*}
        checksum=md5sum
        ;;
        --sha1=*)
        sha1=${1#*=}
        [[ $sha1 == "" ]] && exit_error $VALUE_ERROR ${1%=*}
        checksum=sha1sum
        ;;
        -g|--enable-graph)
        graph=true
        ;;
        -f|--first)
        first=true
        if [[ $2 == -* || $2 == --* || $2 == "" ]]; then
            chunks_rate=(20 20 20 20 20)
            nchunks=5
        else
            get_chunks_rate $2
            nchunks=${#chunks_rate[@]}
            shift
        fi
        ;;
        --first=*)
        [[ ${1#*=} == "" ]] && exit_error $VALUE_ERROR "--first="
        first=true
        get_chunks_rate ${1#*=}
        nchunks=${#chunks_rate[@]}
        ;;
        -s|--save-snapshot)
        savesnap=true
        if [[ $2 == -* || $2 == --* || $2 == "" ]]; then
            :
        else
            snapfileS="$2"
            shift
        fi
        ;;
        --save-snapshot=*)
        [[ "${1#*=}" == "" ]] && exit_error $VALUE_ERROR "--save-snapshot="
        savesnap=true
        snapfileS="${1#*=}"
        ;;
        -l|--load-snapshot)
        [[ $2 == -* || $2 == --* || $2 == "" ]] && exit_error $VALUE_ERROR "-l,--load-snapshot"
        loadsnap=true
        snapfileL="$2"
        shift
        ;;
        --load-snapshot=*)
        [[ "${1#*=}" == "" ]] && exit_error $VALUE_ERROR "--load-snapshot"
        loadsnap=true
        snapfileL="${1#*=}"
        ;;
        -a|--anonimous)
        usetor=true
        ;;
        -*)
        opt=${1#*-}
        for ((i=0;i<${#opt};i++)); do
            case ${opt:$i:1} in
                v)
                verbose=true
                ;;
                d)
                usedd=true
                ;;
                g)
                graph=true
                ;;
                f)
                first=true
                chunks_rate=(20 20 20 20 20)
                nchunks=5
                ;;
                s)
                savesnap=true
                ;;
                u)
                exit_error $VALUE_ERROR "-u"
                ;;
                n)
                exit_error $VALUE_ERROR "-n"
                ;;
                o)
                exit_error $VALUE_ERROR "-o"
                ;;
                l)
                exit_error $VALUE_ERROR "-l"
                ;;
                h)
                exit_error $USAGE
                ;;
                V)
                printf "\n%s version %s\n\n" $PROGNAME $VERSION
                exit 7
                ;;
                a)
                usetor=true
                ;;
                *)
                exit_error $UK_OPT_ERROR "-${opt:$i:1}"
                ;;
            esac
        done
        ;;
        *)
        exit_error $UK_OPT_ERROR $1
        ;;
    esac
    shift
done
echo

if [[ $usetor == true ]]; then
    check_tor
    case $torflag in
        $TOR_NOTINST)
        exit_error $TOR_ERROR "Tor is not installed"
        ;;
        $TOR_INST_NOTRUN)
        exit_error $TOR_ERROR "Tor is installed but not running"
        ;;
        $TOR_INST_RUN)
        proxy="--socks4 127.0.0.1:9050"
        ;;
    esac
fi

if [[ $loadsnap == true ]]; then
    [[ $first == true ]] && exit_error $OPT_CONFLICT_ERROR "-f,--first" "-l,--load-snapshot"
    savesnap=true
    # load snapshot from file
    if [[ -e "$snapfileL" ]]; then
        grep -q snapshot "$snapfileL" 2>>/dev/null
        if [[ $? -eq 0 ]]; then
            exec 3<"$snapfileL"           # open the file with FD 3
        else
            #echo "${E}Error:$Reset the file $snapfileL isn't a snapshot"
            #exit 7
            exit_error $NOS_ERROR "$snapfileL"
        fi
    else
        #echo -e "${E}Error:$Reset the file $snapfileL not found"
        #exit 7
        exit_error $FNF_ERROR "$snapfileL"
    fi
    read -r -u 3 line                    # skip first line
    read -r -u 3 output                  # get output file name
    read -r -u 3 url                     # get url
    #read -r -u 3 graph                   # get the graph flag
    read -r -u 3 usedd                   # get the usedd flag
    read -r -u 3 -a chunks_rate          # get chunks_rate
    read -r -u 3 snapchunk               # get current chunk
    read -r -u 3 chunkstart              # the start byte of the current chunk
    read -r -u 3 nthreads                # get nthreads for chunk
    read -r -u 3 -a loadeds              # get threads start
    read -r -u 3 -a thsnapbc             # the bytes copied by the threads before exit
    exec 3<&-                            # close the file
    nchunks=${#chunks_rate[@]}           # set nchunks
fi

# check required options
[[ "$url" == "" ]] && exit_error $REQ_OPT_ERROR "-u,--url"

# set usedd and unset graph if first=true
if [[ $first == true ]]; then
    usedd=true
    graph=false
fi

# check gnuplot if installed
if [[ $graph == true ]]; then
    which gnuplot &> /dev/null || exit_error $GP_ERROR
fi

# initialize thsnapbc
if [[ $savesnap == true && $loadsnap == false ]]; then
    for ((i=0;i<$nthreads;i++)); do
        thsnapbc[$i]=0
    done
fi

# ask for info to the server without download and get the content lenght
content_length=0
content_left=0
while [[ $content_length -eq 0 ]]; do
    headers=$(curl $proxy -sI "$url")
    set $headers
    file_ext=""
    location=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            Content-Length*)
            content_length=${2%*$'\r'*} #get the left part at the first occurrence of \r (excluded)
            printf "content length: %d\n" $content_length
            ;;
            Content-Type*)
            file_ext=$(echo ${2%*$'\r'*} |awk -F '/' '{ print $2 }') #get the file extension
            file_ext=${file_ext%[;,.[:space:]]*}
            ;;
            Location*)
            location=${2%$'\r'*}
            ;;
        esac
        shift
    done
    
    # if the content lenght is zero check if a new location is specified
    if [[ $content_length -eq 0 ]]; then
        if [[ $location == "" ]]; then
            # print the HTTP headers and exit
            exit_error $CL_ERROR "$url"
        else
            printf "${W}Warning:$Reset content length is zero trying to download from another location:\n"
            echo "$location"
            url="$location"
        fi
    fi
done

# calculate the content left if loadsnap == true
if [[ $loadsnap == true ]]; then
    fdim=0
    if [[ $usedd == true ]]; then
        fdim=$(du -B 1 "$output" |awk '{ print $1 }')
    else
        for f in ${output}.part*; do
            [[ -e "$f" ]] && fdim+=$(du -b "$f" |awk '{ print $1 }')
        done
    fi
    content_left=$[$content_length-$fdim]
fi

# get the file name from url if output isn't set
if [[ "$output" == "" ]]; then
    output="${url##*/}"
    [[ "$output" == "" ]] && output="${url%/*}"
    output="${output##*/}"
    output="${output%%[&?=#@]*}"
    if [[ "${output##*.}" == "${output%.*}" ]]; then
        # no file extension
        printf "${W}Warning:${Reset} file extension not found in the url\ngot from HTTP headers\n"
        output="${output}.$file_ext"
    fi
    printf "output file is: ${Blue}%s${Reset}\n\n" "$output"
fi

[[ $loadsnap == false ]] && touch_output

# set snapfileS if not set
[[ $savesnap == "true" && "$snapfileS" == "" ]] && snapfileS="${output}.snp"

printf "\nHallo %s:\n" $USER
if [[ $loadsnap == true ]]; then
    printf "continuing %s download\n" "$output"
else
    printf "the file that you want to download is %d bytes long\n" $content_length
    if [[ $first == true ]]; then
        printf "it will be divided in %d parts and the first part will be downloaded first\n" $nchunks
        printf "every part will be downloaded by %d threads\n" $nthreads
    else
        printf "the process will be divided in ${White}%d${Reset} threads\n" $nthreads
    fi
fi

#trap "save_snapshot; clean_up SIGHUP"  SIGHUP
trap "save_snapshot; clean_up SIGINT"  SIGINT
#trap "save_snapshot; clean_up SIGTERM" SIGTERM

# get the corresponding chunk size in bytes from the chunks_rate in %
chunksize=()
sum=0
for ((i=0;i<nchunks;i++)); do
    chunksize[$i]=$[($content_length*${chunks_rate[$i]})/100]
    #printf "chunksize[%s]: %s\n" $i ${chunksize[$i]}
    sum=$[$sum+${chunksize[$i]}]
done
chunkrest=$[$content_length-$sum]
# update the last chunk size with the rest
[[ $chunkrest != 0 ]] && chunksize[$[$nchunks-1]]=$[${chunksize[$[$nchunks-1]]}+$chunkrest]
#printf "chunkrest: %s\n" $chunkrest

if [[ $loadsnap == false ]]; then
    cc=0                    # the current chunk
    chunkstart=0            # chunk start byte
else
    cc=$snapchunk
fi

time_elapsed=$SECONDS
# chunks loop
while [[ $cc -lt $nchunks ]]; do
    [[ $verbose == true ]] && printf "downloading chunk %d\n" $cc
    [[ $usedd == false ]] && file_out=()   # a list with the partial output file names (old algo)
    [[ $savesnap == true ]] && snapstart=$chunkstart
    division=$[${chunksize[$cc]} / $nthreads]     # the single thread chunk
    rest=$[${chunksize[$cc]} % $nthreads]
    start=$chunkstart                      # the first byte of the thread
    stop=$[$start+$division-1]             # the last byte of the thread
    i=1                                    # thread index
    # threads loop for the current chunk
    while [ $i -le $nthreads ]; do
        sid=$[$i-1]
        thsnaps[$sid]=$start          # update the threads start and stop informations for the snapshot
        # start the i-th thread
        if [[ $usedd == true ]]; then
            if [[ $loadsnap == true && $snapchunk == $cc ]]; then
                RunThread $i ${loadeds[$sid]} $stop &      # use loaded start from snapshot
            else
                RunThread $i $start $stop &
            fi
        else
            if [[ $loadsnap == true && $snapchunk == $cc ]]; then
                [[ $verbose == true ]] && echo -e "${White}downloading ${Green}${output}.part${i}...$Reset ${start}-${stop} $[$stop-$start+1] bytes"
                StartThread $i ${loadeds[$sid]} $stop &    # use loaded start from snapshot
                file_out+=("${output}.part${i}")
            else
                [[ $verbose == true ]] && echo -e "${White}downloading ${Green}${output}.part${i}...$Reset ${start}-${stop} $[$stop-$start+1] bytes"
                StartThread $i $start $stop &    # the old algorithm
                file_out+=("${output}.part${i}")
            fi
        fi
        i=$[$i+1]
        start=$[$stop+1]   # update the first byte of the thread
        [[ $i -eq $nthreads ]] && division=$[$division+$rest]
        stop=$[$stop+$division]   # update the last byte of the thread
    done
    chunkstart=$[$chunkstart+${chunksize[$cc]}]     # update the chunk's start byte
    cc=$[$cc+1]        # update the current chunk num.
    
    # progress bar
    progress_bar &

    if [[ $graph == true ]]; then
        progress_graph &
        while : ; do
            [[ -e $pplot ]] && break
        done
        gnuplot $gplt_script &> /dev/null
    fi

    wait  # wait and join the threads when finished
done
echo
time_elapsed=$[$SECONDS-$time_elapsed]

# download completed
Play $NOTIFY_SOUND &
printf "\n Download completed\n"

[[ $verbose == true && $usedd == false ]] && ls -lh |grep "$output" | awk '{ print "\033[1;32m"$9"  \033[1;34m"$5"\033[00m" }'

if [[ $usedd == false ]]; then
    # join all the chunks in one file
    [[ $verbose == true ]] && printf "All the chunks will be joined together\n\n"
    for f in ${file_out[@]}; do
        cat "$f" >> "$output"
        [[ $verbose == true ]] && printf "${Red}removing the file %s$Reset\n" "$f"
        rm "$f"
    done
else
    rm $TEMPDIR/${PROGNAME}*.log
    rm $TEMPDIR/thread*.data
fi
[[ $loadsnap == true && $usedd == false ]] && rm "$snapfileL"
actual_fsize=$(du -b "$output" |awk '{ print $1 }')
if [[ $actual_fsize != $content_length ]]; then
    printf "Ooooops something went wrong\nfile size mismatch\n\n"
elif [[ $loadsnap == true ]]; then
    rm -f "$snapfileL"
fi

# calculate download rate
if [[ $loadsnap == true ]]; then
    down_rate=$[$content_left/($time_elapsed*1024)]
else
    down_rate=$[$content_length/($time_elapsed*1024)]
fi

echo "Download rate: $down_rate KB/s in $(human_time $time_elapsed)"

#if [[ $time_elapsed -gt 60 && $time_enlapsed != 0 ]]; then
    #echo "Download rate: $[$content_length/($time_elapsed*1024)]KB/s in $[$time_elapsed/60]m $[$time_elapsed%60]s"
#else
    #echo "Download rate: $[$content_length/($time_elapsed*1024)]KB/s in ${time_elapsed}s"
#fi

exec 200<&-   # close the lock file

if [[ $checksum != "" ]]; then
    printf "\nchecking %s...\n" $checksum
    if [[ $md5 != "" ]]; then
        [[ $($checksum "$output" |awk '{ print $1 }') == $md5 ]] && printf "${Green}*****OK*****$Reset\n" || printf "${Red}*****NO*****$Reset\n"
    elif [[ $sha1 != "" ]]; then
        [[ $($checksum "$output" |awk '{ print $1 }') == $sha1 ]] && printf "${Green}*****OK*****$Reset\n" || printf "${Red}*****NO*****$Reset\n"
    fi
fi
rm $lockfile
echo
