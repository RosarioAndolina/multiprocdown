# cmake script

function(find_programs)
	set(msg_type "" PARENT_SCOPE)
	foreach(arg ${ARGN})
		if(${arg} STREQUAL REQ)
			set(msg_type FATAL_ERROR)
			set(prog_property required)
			continue()
		elseif(${arg} STREQUAL OPT)
			set(msg_type "")
			set(prog_property optional)
			continue()
		endif()
		message(STATUS "Searching program ${arg}...")
		find_program(pname ${arg} NO_CMAKE_PATH
                     NO_CMAKE_ENVIRONMENT_PATH
                     NO_CMAKE_SYSTEM_PATH)
		if(NOT IS_ABSOLUTE ${pname})
			message(${msg_type} "${arg}: ${prog_property} program not found.")
		endif()
		unset(pname CACHE)
	endforeach()
endfunction()

