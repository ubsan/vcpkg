
if(CMAKE_SYSTEM_NAME MATCHES "^Windows(Store)?$")
    include("${CMAKE_CURRENT_LIST_DIR}/windows.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    include("${CMAKE_CURRENT_LIST_DIR}/linux.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Android")
    include("${CMAKE_CURRENT_LIST_DIR}/android.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    include("${CMAKE_CURRENT_LIST_DIR}/osx.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    include("${CMAKE_CURRENT_LIST_DIR}/ios.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
    include("${CMAKE_CURRENT_LIST_DIR}/freebsd.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
    include("${CMAKE_CURRENT_LIST_DIR}/openbsd.cmake")
elseif(CMAKE_SYSTEM_NAME STREQUAL "MinGW")
    include("${CMAKE_CURRENT_LIST_DIR}/mingw.cmake")
else()
    message(FATAL_ERROR "Could not find default VCPKG_CHAINLOAD_TOOLCHAIN_FILE for CMAKE_SYSTEM_NAME \"${CMAKE_SYSTEM_NAME}\".
Supported CMAKE_SYSTEM_NAMEs are:
    - Windows
    - WindowsStore
    - Linux
    - Android
    - Darwin
    - iOS
    - FreeBSD
    - OpenBSD
    - MinGW"
    )
endif()
