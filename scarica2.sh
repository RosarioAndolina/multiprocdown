#!/bin/bash

readonly VALUE_ERROR=1           # no value in options that requires one
readonly UK_OPT_ERROR=2          # unknown option
readonly REQ_OPT_ERROR=3         # missing required option
readonly USAGE=4                 # print usage
readonly CL_ERROR=5              # Content-Length is 0 or header is missing
readonly KILLED_ERROR=6          # killed with SIGHUP | SIGINT | SIGTERM

readonly PROGNAME=$(basename $0)
readonly VERSION=2
readonly ERROR_SOUND="/home/rosario/Scaricati/breaking-some-glass.ogg"
readonly NOTIFY_SOUND="/home/rosario/Scaricati/demonstrative.ogg"
readonly Blue='\033[01;34m'
readonly White='\033[01;37m'
readonly Red='\033[01;31m'
readonly Green='\033[01;32m'
readonly E='\033[01;41m'
readonly W='\033[01;43m'
readonly Reset='\033[00m'

alias cvlc="cvlc -q --no-loop --play-and-exit"

function print_usage
{
	echo
	echo "Usage: $PROGNAME -u URL | --url[=]URL [OPTIONS]..."
	echo 
	echo "\"$PROGNAME\" is a multiprocess download utility very useful for"
	echo "big files. It uses curl in parallel, downloading N chunk of"
	echo "the file and then ricombine the chunks in one file."
	echo
	echo "Required:"
	echo
	echo "  -u URL, --url[=]URL        the URL of the file to be downloaded"
	echo
	echo "Options:"
	echo 
	echo "  -n N, --nthreads[=]N       [18] the number of threads used for parallel"
	echo "                               download. The file will be divided in"
	echo "                               in N chunks"
	echo
	echo "  -o F_OUT, --output[=]F_OUT"
	echo "                             the output file name"
	echo
	echo "  -v, --verbose              print more info in stdout"
	echo
	echo "  -d, --use-dd               use dd to write the chunks on a single file"
	echo "                               downloading a video you can see a preview"
	echo
	echo "  --md5[=]VALUE              calculates the md5sum of the output file and"
	echo "                               compares with VALUE"
	echo
	echo "  --sha1[=]VALUE             calculates the sha1sum of the output file and"
	echo "                               compares with VALUE"
	echo
	echo "  -h, --help                 print this message and exit"
	echo
	echo "  -V, --version              print program name and version"
	echo
}

function Play
{
	local players=(paplay cvlc mplayer)
	for p in $players; do
		which "$p" >> /dev/null 2>&1 && "$p" "$1" >> /dev/null 2>&1 && break
	done
}

function exit_error
{
	case $1 in
		$VALUE_ERROR)
		printf "${E}Error:${Reset} option %s needs a value\nexiting...\n" $2 1>&2
		exit $VALUE_ERROR
		;;
		$UK_OPT_ERROR)
		printf "Unknown option %s\nexiting...\n" $2 1>&2
		exit $UK_OPT_ERROR
		;;
		$REQ_OPT_ERROR)
		printf "${E}Error:${Reset} option %s is required\nexiting...\n" $2 1>&2
		exit $REQ_OPT_ERROR
		;;
		$USAGE)
		print_usage 1>&2
		exit $USAGE
		;;
		$CL_ERROR)
		printf "${E}Error:${Reset} content length is 0\n" 1>&2
		printf "the number of bytes downloaded by a single thread cannot be calculated\n\n" 1>&2
		curl -sI $2 1>&2
		printf "try with wget or curl directly\n\n" 1>&2
		Play $ERROR_SOUND
		exit $CL_ERROR
		;;
		$KILLED_ERROR)
		printf "\n${E}Process killed by %s${Reset}\n" $2 1>&2
		exit $KILLED_ERROR
		;;
	esac
}

function clean_up
{
	if [[ $usedd == true ]]; then
		[[ -e "/tmp/${PROGNAME}*.log" ]] && rm /tmp/${PROGNAME}*.log
	else
		local f2rm
		for f2rm in ${output}.part* ; do
			[[ -e $f2rm ]] && rm $f2rm
		done
	fi
	exec 200<&-
	exit_error $KILLED_ERROR $1
}

[[ $# -eq 0 ]] && exit_error $USAGE

url=""
nthreads=18
output=""
verbose=false
usedd=false
md5=""
sha1=""
checksum=""
[[ ! -d /tmp/lock ]] && mkdir /tmp/lock
lockfile="/tmp/lock/${PROGNAME}$$.lock"
exec 200>$lockfile

# parsing options
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
		[[ $2 == -* || $2 == --* || $2 == "" ]] && exit_error $VALUE_ERROR $1
		url=$2
		shift
		;;
		--url=*)
		url=${1#*=}
		[[ $url == "" ]] && exit_error $VALUE_ERROR ${1%=*}
		;;
		-n|--nthreads)
		[[ $2 == -* || $2 == --* || $2 == "" ]] && exit_error $VALUE_ERROR $1
		nthreads=$2
		shift
		;;
		--nthreads=*)
		nthreads=${1#*=}
		[[ $nthreads == "" ]] && exit_error $VALUE_ERROR ${1%=*}
		;;
		-o|--output)
		[[ $2 == -* || $2 == --* || $2 == "" ]] && exit_error $VALUE_ERROR $1
		output=$2
		shift
		;;
		--output=*)
		output=${1#*=}
		[[ $output == "" ]] && exit_error $VALUE_ERROR ${1%=*}
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
		*)
		exit_error $UK_OPT_ERROR $1
		;;
	esac
	shift
done

echo
[[ "$url" == "" ]] && exit_error $REQ_OPT_ERROR "-u,--url"

function RunThread 
{
	# this function download a chunk of N bytes of the file and check if
	# it is completely downloaded, otherwise will try to download it 
	# completely. This function will be executed in parallel
	
	local threadID=$1
	local fstart=$2
	local fstop=$3
	local foffset=$fstart
	local flog=/tmp/${PROGNAME}$!.log
	local ddargs="oflag=seek_bytes conv=notrunc,sparse"
	local bytes_copied=0
	
	while [[ $foffset -lt $fstop ]]; do
	    # download (fstop-foffset) bytes of the file in a temp file
		# if the foffset byte is equal to the fstop byte then the chunk
		# is completely downloaded
		if [[ $verbose == true ]]; then
		(
			flock -n 200
			printf "Thread${Blue}%d${Reset} %d - %d\n" $threadID $fstart $fstop
		)200>>$lockfile
		fi
		bytes_copied=$(curl -f --range ${foffset}-${fstop} $url 2>$flog | dd of=$output $ddargs seek=$foffset 2>&1 |awk '/bytes/ { print $1 }')
		# if the connection drop continue the download updating the offset
		foffset=$[$fstart+$bytes_copied]
		#printf "Thread%d bytes down=%d\n" $threadID $bytes_copied
		grep -q error $flog
		if [[ $? -eq 0 ]]; then
			# the server has sent an error message
			# maybe it only accepts a limited number of connections from the same IP address
			(
				flock -n 200
				printf "${White}Thread${Blue}%d${Reset} interrupted by the server. Will restart ASAP\n" $threadID
			)200>>$lockfile
			sleep 0.5
			# counts the number of active connections
			local active_conn=$(pgrep -c curl)
			while [[ $(pgrep -c curl) -ge $active_conn ]]; do
				sleep 1  # sleep until one or more active connections have finished their work
			done
			(
				fock -n 200
				printf "${White}Thread${Blue}%d ${Reset}restarted\n" $threadID
			)200>>$lockfile
		fi
	done
		
}

function StartThread
{
	# this function download a chunk of N bytes of the file and check if
	# it is completely downloaded, otherwise will try to download it 
	# completely. This function will be executed in parallel
	
	local threadID=$1
	local fstart=$2
	local fstop=$3
	local fsize=0
	local foffset=$fstart
	local ffname="${output}.part${threadID}"
	touch $ffname
	local ferrorflag=0
	
	while [ $foffset -lt $fstop ]; do
		# download (fstop-foffset) bytes of the file in a temp file
		# if the foffset byte is equal to the fstop byte then the chunk
		# is completely downloaded
		curl -s --range ${foffset}-${fstop} $url > ${ffname}.tmp
		if [ -e ${ffname}.tmp ]; then
			fsize_temp=$(du -b ${ffname}.tmp |awk '{ print $1 }')
			
			# check the size of the downloaded chunk
			if [ $[$fstart+$fsize+$fsize_temp] -lt $fstop ]; then
			
				# something went wrong, the chunk is not completely downloaded
				grep ERROR ${ffname}.tmp >> /dev/null
				if [ $? -eq 0 -a "$(file ${ffname}.tmp |awk '{ print $2 }')" == "HTML" ]; then
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
					# the connection has been dropped
					cat ${ffname}.tmp >> $ffname # copy the temporary data in the file for the current chunk
					fsize=$(du -b $ffname |awk '{ print $1 }') # get the actual size of the current chunk
					foffset=$[$fstart+$fsize] #update the offset value
					echo -e "${White}Thread${Blue}$threadID ${Reset}the connection has been dropped. Recovery connection"
					ferrorflag=1  # there was an error so the temp file must be copied in append mode
				fi
			else
				# all ok
				if [ $ferrorflag -eq 0 ]; then
					mv ${ffname}.tmp $ffname # just rename the file
				else
					cat ${ffname}.tmp >> $ffname  # add to previously downloaded data
					rm ${ffname}.tmp
				fi
				break
			fi
		fi
	done
}

function progress_bar
{
	declare -i actual_fdim=0
	declare -i last_fdim
	declare -i down_rate
	declare -i percent
	foo="##################################################"
	spaces="[                                                  ]"
	while true; do
		sleep 1
		last_fdim=$actual_fdim
		actual_fdim=0
		if [[ $usedd == true ]]; then
			actual_fdim=$(du -B 1 $output |awk '{ print $1 }')
		else
			for f in ${output}.part*; do
				[[ -e $f ]] && actual_fdim+=$(du -b $f |awk '{ print $1 }')
			done
		fi
		down_rate=$[($actual_fdim - $last_fdim)/1024]  # /1024 in KB/s
		percent=$[($actual_fdim*100)/$content_length]
		bar="${foo:0:$[$percent/2]}"
		(
			flock -n 200
			printf "\r%s %d%s  %d KB/s  " "${spaces/"${spaces:1:$[$percent/2]}"/$bar}" $percent "%" $down_rate
		)200>>$lockfile
		#[[ $actual_fdim -eq $content_length ]] && break
		[[ $(pgrep -c curl) -eq 0 ]] && break
	done
}

function touch_output
{
	if [ -e $output ]; then
		while true; do
			printf "the file %s already exists, do you want to overwrite? [y/n] " $output
			read
			case $REPLY in
				y|yes|Y|Yes|YES)
				rm $output
				break
				;;
				n|no|No|N|NO)
				findex=1
				prefix=${output%%.*}
				postfix=${output##*.}
				while [ -e $output ]; do
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
		#if [[ $usedd == true ]]; then
			#dd if=/dev/zero of=$output bs=1 count=0 seek=${1}c status=none
		#else
			#touch $output
		#fi
		touch $output
	else
		#if [[ $usedd == true ]]; then
			#dd if=/dev/zero of=$output bs=1 count=0 seek=${1}c status=none
		#else
			#touch $output
		#fi
		touch $output
	fi
}

trap "clean_up SIGHUP"  SIGHUP
trap "clean_up SIGINT"  SIGINT
trap "clean_up SIGTERM" SIGTERM

# ask for info to the server without download and get the content lenght
headers=$(curl -sI $url)
set $headers
content_length=0
file_ext=""
while [[ $# -gt 0 ]]; do
	case $1 in
		Content-Length*)
		content_length=${2%*$'\r'*} #get the left part at the first occurrence of \r (excluded)
		;;
		Content-Type*)
		file_ext=$(echo ${2%*$'\r'*} |awk -F '/' '{ print $2 }') #get the file extension
		file_ext=${file_ext%[;,.[:space:]]*}
		;;
	esac
	shift
done

# if the content lenght is zero print the HTTP headers and exit
[[ $content_length -eq 0 ]] && exit_error $CL_ERROR $url

# get the file name from url if -o option is not present
if [[ "$output" == "" ]]; then
	output=${url##*/}
	[[ $output == "" ]] && output=${url%/*}
	output=${output##*/}
	output=${output%%[&?=#@]*}
	if [[ ${output##*.} == ${output%.*} ]]; then
		# no extension
		printf "${W}Warning:${Reset} file extension not found in the url\ngot from HTTP headers\n"
		output=${output}.$file_ext
	fi
	printf "output file is: ${Blue}%s${Reset}\n" $output
fi

printf "\nHallo %s:\n" $USER
printf "the file that you want to download is %d bytes long\n" $content_length
printf "it will be divided in ${White}%d${Reset} threads\n" $nthreads

division=$[$content_length / $nthreads]
rest=$[$content_length % $nthreads]

if [ $rest == 0 ]; then
    printf "each of which will download %d bytes\n" $division
else
    printf "%d of which will download %d bytes each\n" $[$nthreads-1] $division
    printf "only one thread (the last one) will download %d bytes\n\n" $[$division+$rest]
fi
[[ $usedd == false ]] && file_out=()
touch_output $content_length

start=0
i=1
stop=$[$division-1] # the last byte of the chunk
time_elapsed=$SECONDS
while [ $i -le $nthreads ]; do	
	# start the i-th thread
	if [[ $usedd == true ]]; then
		RunThread $i $start $stop &
	else
		[[ $verbose == true ]] && echo -e "${White}downloading ${Green}${output}.part${i}...$Reset ${start}-${stop} $[$stop-$start+1] bytes"
		StartThread $i $start $stop &
		file_out+=(${output}.part${i}) # a list with the partial output file names
	fi
	i=$[$i+1]
	start=$[$stop+1]   # update the first byte of the chunk
	[[ $i -eq $nthreads ]] && division=$[$division+$rest]
	stop=$[$stop+$division]   # uptdate the last byte of the chunk
done

# progress bar
progress_bar &


wait  # wait and join the threads when finished
echo
time_elapsed=$[$SECONDS-$time_elapsed]

# download completed
Play $NOTIFY_SOUND &
printf "\n Download completed\n"
echo
[[ $verbose == true && $usedd == false ]] && ls -lh |grep $output | awk '{ print "\033[1;32m"$9"  \033[1;34m"$5"\033[00m" }'

if [[ $usedd == false ]]; then
	# join all the chunks in one file
	[[ $verbose == true ]] && printf "All the chunks will be joined together\n\n"
	for f in ${file_out[@]}; do
		cat $f >> $output
		[[ $verbose == true ]] && printf "${Red}removing the file %s$Reset\n" $f
		rm $f
	done
else
	rm /tmp/${PROGNAME}*.log
fi

if [ $time_elapsed -gt 60 ]; then
	echo "Download rate: $[$content_length/($time_elapsed*1024)]KB/s in $[$time_elapsed/60]m $[$time_elapsed%60]s"
else
	echo "Download rate: $[$content_length/($time_elapsed*1024)]KB/s in ${time_elapsed}s"
fi

exec 200<&-

if [[ $checksum != "" ]]; then
	printf "\nchecking %s...\n" $checksum
	if [[ $md5 != "" ]]; then
		[[ $($checksum "$output" |awk '{ print $1 }') == $md5 ]] && printf "${Green}*****OK*****$Reset\n" || printf "${Red}*****NO*****$Reset\n"
	elif [[ $sha1 != "" ]]; then
		[[ $($checksum "$output" |awk '{ print $1 }') == $sha1 ]] && printf "${Green}*****OK*****$Reset\n" || printf "${Red}*****NO*****$Reset\n"
	fi
fi
echo
