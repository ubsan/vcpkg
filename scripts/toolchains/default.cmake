if(DEFINED CMAKE_SYSTEM_NAME)
    set(system_name "${CMAKE_SYSTEM_NAME}")
else()
    set(system_name "${CMAKE_HOST_SYSTEM_NAME}")
endif()
if(system_name MATCHES "^Windows(Store)?$")
    include("${CMAKE_CURRENT_LIST_DIR}/windows.cmake")
elseif(system_name STREQUAL "Linux")
    include("${CMAKE_CURRENT_LIST_DIR}/linux.cmake")
elseif(system_name STREQUAL "Android")
    include("${CMAKE_CURRENT_LIST_DIR}/android.cmake")
elseif(system_name STREQUAL "Darwin")
    include("${CMAKE_CURRENT_LIST_DIR}/osx.cmake")
elseif(system_name STREQUAL "iOS")
    include("${CMAKE_CURRENT_LIST_DIR}/ios.cmake")
elseif(system_name STREQUAL "FreeBSD")
    include("${CMAKE_CURRENT_LIST_DIR}/freebsd.cmake")
elseif(system_name STREQUAL "OpenBSD")
    include("${CMAKE_CURRENT_LIST_DIR}/openbsd.cmake")
elseif(system_name STREQUAL "MinGW")
    include("${CMAKE_CURRENT_LIST_DIR}/mingw.cmake")
else()
    message(FATAL_ERROR "Could not find default VCPKG_CHAINLOAD_TOOLCHAIN_FILE for CMAKE_SYSTEM_NAME \"${system_name}\".
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
