## multiprocdown - Fasten download processes with parallelism

Author: Rosario Andolina <andolinarosario@gmail.com>
Copyright (C) 2017  Rosario Andolina

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

### dependecies:

	* curl
	* awk

### optionals dependecies:

	* pulseaudio|mplayer|vlc: audio support
	* gnuplot: graphic support

### installation:

	```bash
	cmake -DCMAKE_INSTALL_PREFIX=<your_build_directory>
	make && make install```
	
	the default cmake install prefix is /usr/local, if you like to
	install in your own personal directory please use cmake.
	If you'll use "make DESTDIR=<your_build_directory> install", multiprocdow
	will fail while loocking for audio files needed for audio support
	for example:
		```bash
		your_build_dir=${HOME}/multiprocdown/usr
		cmake -DCMAKE_INSTALL_PREFIX="${you_build_dir}"
		make && make install```


### Usage: multiprocdown -u URL | --url[=]URL [OPTIONS]...

**multiprocdown** is a multiprocess download utility very useful for
big files. It uses curl, downloading N chunk of the file in parallel

Mandatory arguments to long options are mandatory for short options too.

**Required mutual exclusive**:

  **-u**, **--url**[=]URL          the URL of the file to be downloaded

 ** -l**, **--load-snapshot**[=]SNAP_FILE
                           load a saved snapshot to exhume the download

**Options**:

  **-n**, **--nthreads**[=]N       [10] the number of threads used for parallel
                             download

  **-o**, **--output**[=]F_OUT     the output file name

  **-v**, **--verbose**            print more info on stdout

  **-d**, **--use-dd**             use dd to write the chunks relating to each thread on
                             the same file, in this way, while downloading a video
                             you can see a preview (see **-f**,**--first** option)

  **--md5**[=]VALUE            calculates the md5sum of the output file and
                             compares with VALUE

  **--sha1**[=]VALUE           calculates the sha1sum of the output file and
                             compares with VALUE

  **-g**, **--enable-graph**       enables a progress graph.

  **-f**, **--first**[[=]FORMAT]      download first the initial part of the file and then
                              the rest, according to the FORMAT. `dd` is used by default

  **-s**, **--save-snapshot**[[=]SNAP_FILE]
                           if the script exit save a snapshot of the current download
                             the download may be exhumed by loading the snapshot, if
                             the url is still valid. See **-l**, **--load-snapshot**

  **-a**, **--anonimous**          if possible uses `tor` proxyes

  **-h**, **--help**               print this message and exit unsuccesfully

  **-V**, **--version**            print program name and version and exit unsuccesfully


Option **-g**, **--enable-graph** display a bar plot showing the progress percetage
of every single thread. `gnuplot` is required.

The **-f**, **--first** option is useful when you whant to watch a video while
downloading. The progress graph will be disabled

the SNAP_FILE, if not specified, will have `.snp` extention and the same
name of the output file

FORMAT is a semicolon separated sequence of chunks rate in percentage, if
no FORMAT is provided the default is 20:20:20:20:20 that means five chunks
of 20% of the file dimension each

FORMAT examples:

5:5:10:30:50       download 5% first with N threads and then 5% N threads etc.
1:5:10:20:20:44    is good if you want to see video files large pier
                     while downloading.
the FORMAT sequence will be stoped when the sum of the chunks rate exceeds 100
the possible difference will be added to the last chunk
