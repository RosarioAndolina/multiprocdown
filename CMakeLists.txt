
cmake_minimum_required(VERSION 2.6)

set(PACKAGE multiprocdown)
set(VERSION 2.1)
project(${PACKAGE})

set(opt_progs gnuplot tor vlc paplay mplayer suca)
set(req_progs curl awk dd)

include(FindPrograms.cmake)

find_programs(OPT ${opt_progs} REQ ${req_progs})

add_subdirectory(src)
add_subdirectory(share)
