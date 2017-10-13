
configure_file(scarica2.sh.in ${PACKAGE} @ONLY)

install(PROGRAMS ${PACKAGE} DESTINATION bin)
