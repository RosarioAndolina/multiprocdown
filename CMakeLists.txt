
cmake_minimum_required(VERSION 2.6)

set(PACKAGE multiprocdow)
set(VERSION 2.1)
project(${PACKAGE})

set(MEDIA_NAMES vlc paplay mplayer)

find_program(CHECK_CURL curl NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_PATH NO_CMAKE_SYSTEM_PATH)
if (${CHECK_CURL} STREQUAL CHECK_CURL-NOTFOUND)
	message(FATAL_ERROR "curl not found. Please install curl.")
endif (${CHECK_CURL} STREQUAL CHECK_CURL-NOTFOUND)

find_program(CHECK_AWK gawk NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_PATH NO_CMAKE_SYSTEM_PATH)
if (${CHECK_AWK} STREQUAL CHECK_AWK-NOTFOUND)
	message(FATAL_ERROR "awk not found. Please install awk.")
endif (${CHECK_AWK} STREQUAL CHECK_AWK-NOTFOUND)

find_program(CHECK_GNUPLOT gnuplot NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_PATH NO_CMAKE_SYSTEM_PATH)
if (${CHECK_GNUPLOT} STREQUAL CHECK_GNUPLOT-NOTFOUND)
	message(STATUS "gnuplot not found. Install gnuplot for adding graphic support.")
endif (${CHECK_GNUPLOT} STREQUAL CHECK_GNUPLOT-NOTFOUND)

find_program(CHECK_MEDIA NAMES ${MEDIA_NAMES} NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_PATH NO_CMAKE_SYSTEM_PATH)
if (${CHECK_MEDIA} STREQUAL CHECK_MEDIA-NOTFOUND)
	message(STATUS "Install vlc | mplayer | pulseaudio for adding audio support.")
endif (${CHECK_MEDIA} STREQUAL CHECK_MEDIA-NOTFOUND)

add_subdirectory(src)
add_subdirectory(share)
