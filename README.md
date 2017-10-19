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
* tor: download anonimously

### installation:

**Multiprocdown** can be installed using cmake in the usual way

```bash
cmake
make && make install
```
The defalud cmake install prefix is `/usr/local` but you can chose another one. For example:

```bash
cmake -DCMAKE_INSTALL_PREFIX="/usr"
make && make install

# or

cmake -DCMAKE_INSTALL_PREFIX=<you-build-dir>
make && make install

# or

cmake -DCMAKE_INSTALL_PREFIX="/usr"
make && make DESTDIR=<you-build-dir> install
```

### Usage

```bash
multiprocdown -u URL | -l SNAP_FILE [OPTIONS]...
```

**multiprocdown** is a multiprocess download utility very useful for
big files. It uses `curl`, downloading N chunk of the file in parallel

Mandatory arguments to long options are mandatory for short options too.

#### **Required mutual exclusive**:

---

**-u**, **--url**[=]URL

the URL of the file to be downloaded

---

**-l**, **--load-snapshot**[=]SNAP_FILE
  
load a saved snapshot to exhume the download

---

#### **Options**:

---

**-n**, **--nthreads**[=]N

[10] the number of threads used for parallel download. Ignored with -l option.

---

**-o**, **--output**[=]F_OUT

the output file name. Ignored with -l option

---

**-v**, **--verbose**

print more info on stdout

---

**-d**, **--use-dd**

use `dd` to write the chunks relating to each thread on the same file, 
in this way, while downloading a video
you can see a preview (see **-f**,**--first** option)

Ignored with -l option.

---

**--md5**[=]VALUE

calculates the md5sum of the output file and compares with VALUE

---

**--sha1**[=]VALUE
calculates the sha1sum of the output file and compares with VALUE

---

**-g**, **--enable-graph**

enables graphic support showing a graph with the progress of each tread.
Ignored with -l option.

---

**-f**, **--first**[[=]FORMAT]
download first the initial part of the file and then the rest, according to the FORMAT. `dd` is used by default.
Ignored with -l option.
---

**-s**, **--save-snapshot**[[=]SNAP_FILE]

if the script exit save a snapshot of the current download
the download may be exhumed by loading the snapshot, if
the url is still valid. See **-l**, **--load-snapshot**

---

**-a**, **--anonimous**

if possible uses `tor` proxyes

---

**-h**, **--help**

print this message and exit unsuccesfully

---

**-V**, **--version**

print program name and version and exit unsuccesfully

---

Option **-g**, **--enable-graph** display a bar plot showing the progress percetage
of every single thread. `gnuplot` is required.

The **-f**, **--first** option is useful when you whant to watch a video while
downloading. The progress graph will be disabled

the SNAP_FILE, if not specified, will have `.snp` extention and the same
name of the output file

---

FORMAT is a semicolon separated sequence of chunks rate in percentage, if
no FORMAT is provided the default is **20:20:20:20:20** that means five chunks
of 20% of the file dimension each

### FORMAT examples:

| FORMAT | DESCRIPTION |
| --- | --- |
| 5:5:10:30:50 | download 5% first with N threads and then 5% with N threads etc. | 
| 1:5:10:20:20:44 | is good if you want to see video files large pier while downloading. | 
| 5:5:10:10:20:20 | the sum is 70 so the 30% missed will be added at the last chunk. Equivalent to 5:5:10:10:20:50 |
| 10:10:20:30:40 | the sum exceeds 100 in the last chunk so the 40% chunk will be discarded remaning with 10:10:20:30 that is equivalent to 10:10:20:60 |

the FORMAT sequence will be stoped when the sum of the chunks rate exceeds 100
the possible difference will be added to the last chunk
