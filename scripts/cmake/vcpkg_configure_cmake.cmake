# DEPRECATED BY ports/vcpkg-cmake/vcpkg_cmake_configure
#[===[.md:
# vcpkg_configure_cmake

Configure CMake for Debug and Release builds of a project.

## Usage
```cmake
vcpkg_configure_cmake(
    SOURCE_PATH <${SOURCE_PATH}>
    [PREFER_NINJA]
    [DISABLE_PARALLEL_CONFIGURE]
    [NO_CHARSET_FLAG]
    [GENERATOR <"NMake Makefiles">]
    [OPTIONS <-DUSE_THIS_IN_ALL_BUILDS=1>...]
    [OPTIONS_RELEASE <-DOPTIMIZE=1>...]
    [OPTIONS_DEBUG <-DDEBUGGABLE=1>...]
    [MAYBE_UNUSED_VARIABLES <option-name>...]
)
```

## Parameters
### SOURCE_PATH
Specifies the directory containing the `CMakeLists.txt`.
By convention, this is usually set in the portfile as the variable `SOURCE_PATH`.

### PREFER_NINJA
Indicates that, when available, Vcpkg should use Ninja to perform the build.
This should be specified unless the port is known to not work under Ninja.

### DISABLE_PARALLEL_CONFIGURE
Disables running the CMake configure step in parallel.
This is needed for libraries which write back into their source directory during configure.

This also disables CMAKE_DISABLE_SOURCE_CHANGES.

### NO_CHARSET_FLAG
Disables passing `utf-8` as the default character set to `CMAKE_C_FLAGS` and `CMAKE_CXX_FLAGS`.

This is needed for libraries that set their own source code's character set.

### GENERATOR
Specifies the precise generator to use.

This is useful if some project-specific buildsystem has been wrapped in a cmake script that won't perform an actual build.
If used for this purpose, it should be set to `"NMake Makefiles"`.

### OPTIONS
Additional options passed to CMake during the configuration.

### OPTIONS_RELEASE
Additional options passed to CMake during the Release configuration. These are in addition to `OPTIONS`.

### OPTIONS_DEBUG
Additional options passed to CMake during the Debug configuration. These are in addition to `OPTIONS`.

### MAYBE_UNUSED_VARIABLES
Any CMake variables which are explicitly passed in, but which may not be used on all platforms.

### LOGNAME
Name of the log to write the output of the configure call to.

## Notes
This command supplies many common arguments to CMake. To see the full list, examine the source.

## Examples

* [zlib](https://github.com/Microsoft/vcpkg/blob/master/ports/zlib/portfile.cmake)
* [cpprestsdk](https://github.com/Microsoft/vcpkg/blob/master/ports/cpprestsdk/portfile.cmake)
* [poco](https://github.com/Microsoft/vcpkg/blob/master/ports/poco/portfile.cmake)
* [opencv](https://github.com/Microsoft/vcpkg/blob/master/ports/opencv/portfile.cmake)
#]===]

macro(z_vcpkg_configure_cmake_both_set_or_unset var1 var2)
    if(DEFINED ${var1} AND NOT DEFINED ${var2})
        message(FATAL_ERROR "If ${var1} is set, then ${var2} must be set.")
    elseif(NOT DEFINED ${var1} AND DEFINED ${var2})
        message(FATAL_ERROR "If ${var2} is set, then ${var1} must be set.")
    endif()
endmacro()
macro(z_vcpkg_configure_cmake_build_cmakecache out_var where_at build_type)
    set(build_cmakecache_line "build ${where_at}/CMakeCache.txt: CreateProcess\n  process = cmd /c \"cd ${where_at} &&")
    foreach(arg IN LISTS ${build_type}_command)
        string(APPEND build_cmakecache_line " \"${arg}\"")
    endforeach()
    string(APPEND "${out_var}" "${build_cmakecache_line}\"\n\n")
endmacro()



function(vcpkg_configure_cmake)
    cmake_parse_arguments(PARSE_ARGV 0 arg
        "PREFER_NINJA;DISABLE_PARALLEL_CONFIGURE;NO_CHARSET_FLAG;Z_VCPKG_IGNORE_UNUSED_VARIABLES"
        "SOURCE_PATH;GENERATOR;LOGNAME"
        "OPTIONS;OPTIONS_DEBUG;OPTIONS_RELEASE;MAYBE_UNUSED_VARIABLES"
    )

    if(NOT DEFINED arg_SOURCE_PATH)
        message(FATAL_ERROR "SOURCE_PATH must be set")
    endif()

    if(Z_VCPKG_CMAKE_CONFIGURE_GUARD)
        message(FATAL_ERROR "The ${PORT} port already depends on vcpkg-cmake; using both vcpkg-cmake and vcpkg_configure_cmake in the same port is unsupported.")
    endif()
    if(DEFINED CACHE{Z_VCPKG_CMAKE_GENERATOR})
        message(WARNING "vcpkg_configure_cmake already called; this function should only be called once.")
    endif()


    if(NOT DEFINED arg_LOGNAME)
        set(arg_LOGNAME "config-${TARGET_TRIPLET}")
    endif()

    set(manually_specified_variables "")
    if(NOT arg_Z_VCPKG_IGNORE_UNUSED_VARIABLES)
        foreach(option IN LISTS arg_OPTIONS arg_OPTIONS_RELEASE arg_OPTIONS_DEBUG)
            if(option MATCHES "^-D([^:=]*)[:=]")
                list(APPEND manually_specified_variables "${CMAKE_MATCH_1}")
            endif()
        endforeach()
        list(REMOVE_DUPLICATES manually_specified_variables)
        list(REMOVE_ITEM manually_specified_variables ${arg_MAYBE_UNUSED_VARIABLES})
        debug_message("manually specified variables: ${manually_specified_variables}")
    endif()

    set(ninja_can_be_used ON) # Ninja as generator
    set(ninja_host ON) # Ninja as parallel configurator
    if(CMAKE_HOST_WIN32)
        if(DEFINED ENV{PROCESSOR_ARCHITEW6432})
            set(host_architecture "$ENV{PROCESSOR_ARCHITEW6432}")
        else()
            set(host_architecture "$ENV{PROCESSOR_ARCHITECTURE}")
        endif()
        if(host_architecture STREQUAL "x86")
            # Prebuilt ninja binaries are only provided for x64 hosts
            set(ninja_can_be_used OFF)
            set(ninja_host OFF)
        endif()
    endif()
    if(VCPKG_TARGET_IS_UWP)
        # Ninja and MSBuild have many differences when targetting UWP, so use MSBuild to maximize existing compatibility
        set(ninja_can_be_used OFF)
    endif()

    unset(generator)
    unset(arch)

    if(DEFINED arg_GENERATOR)
        set(generator "${arg_GENERATOR}")
    elseif(arg_PREFER_NINJA AND ninja_can_be_used)
        set(generator "Ninja")
    elseif(DEFINED VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
        set(generator "Ninja")
    elseif(NOT VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_MINGW)
        set(generator "Ninja")

    elseif(VCPKG_PLATFORM_TOOLSET STREQUAL "v120")
        set(generator "Visual Studio 12 2013")
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(generator "${generator} Win64")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(generator "${generator} ARM")
        else()
            unset(generator)
        endif()
    elseif(VCPKG_PLATFORM_TOOLSET STREQUAL "v140")
        set(GENERATOR "Visual Studio 14 2015")
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(generator "${generator} Win64")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(generator "${generator} ARM")
        else()
            unset(generator)
        endif()
    elseif(VCPKG_PLATFORM_TOOLSET STREQUAL "v141")
        set(generator "Visual Studio 15 2017")
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(generator "${generator} Win64")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(generator "${generator} ARM")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(arch "ARM64")
        else()
            unset(generator)
        endif()
    elseif(VCPKG_PLATFORM_TOOLSET STREQUAL "v142")
        set(generator "Visual Studio 16 2019")
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(arch "Win32")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(arch "x64")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(arch "ARM")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(arch "ARM64")
        else()
            unset(generator)
        endif()
    endif()

    if(NOT DEFINED generator)
        if(NOT VCPKG_CMAKE_SYSTEM_NAME)
            set(VCPKG_CMAKE_SYSTEM_NAME Windows)
        endif()
        message(FATAL_ERROR "Unable to determine appropriate generator for: "
            "${VCPKG_CMAKE_SYSTEM_NAME}-${VCPKG_TARGET_ARCHITECTURE}-${VCPKG_PLATFORM_TOOLSET}")
    endif()

    # If we use Ninja, make sure it's on PATH
    if(GENERATOR STREQUAL "Ninja" AND NOT DEFINED ENV{VCPKG_FORCE_SYSTEM_BINARIES})
        vcpkg_find_acquire_program(NINJA)
        get_filename_component(NINJA_PATH "${NINJA}" DIRECTORY)
        vcpkg_add_to_path("${NINJA_PATH}")
        vcpkg_list(APPEND arg_OPTIONS "-DCMAKE_MAKE_PROGRAM=${NINJA}")
    endif()

    file(REMOVE_RECURSE
        "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
        "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
    )

    if(DEFINED VCPKG_CMAKE_SYSTEM_NAME)
        vcpkg_list(APPEND arg_OPTIONS "-DCMAKE_SYSTEM_NAME=${VCPKG_CMAKE_SYSTEM_NAME}")
        if(VCPKG_TARGET_IS_UWP AND NOT DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
            set(VCPKG_CMAKE_SYSTEM_VERSION 10.0)
        elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Android" AND NOT DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
            set(VCPKG_CMAKE_SYSTEM_VERSION 21)
        endif()
    endif()

    if(DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
        vcpkg_list(APPEND arg_OPTIONS "-DCMAKE_SYSTEM_VERSION=${VCPKG_CMAKE_SYSTEM_VERSION}")
    endif()

    if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
        vcpkg_list(APPEND arg_OPTIONS -DBUILD_SHARED_LIBS=ON)
    elseif(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
        vcpkg_list(APPEND arg_OPTIONS -DBUILD_SHARED_LIBS=OFF)
    else()
        message(FATAL_ERROR
            "Invalid setting for VCPKG_LIBRARY_LINKAGE: \"${VCPKG_LIBRARY_LINKAGE}\". "
            "It must be \"static\" or \"dynamic\"")
    endif()

    z_vcpkg_configure_cmake_both_set_or_unset(VCPKG_CXX_FLAGS_DEBUG VCPKG_C_FLAGS_DEBUG)
    z_vcpkg_configure_cmake_both_set_or_unset(VCPKG_CXX_FLAGS_RELEASE VCPKG_C_FLAGS_RELEASE)
    z_vcpkg_configure_cmake_both_set_or_unset(VCPKG_CXX_FLAGS VCPKG_C_FLAGS)

    set(vcpkg_set_charset_flag ON)
    if(arg_NO_CHARSET_FLAG)
        set(vcpkg_set_charset_flag OFF)
    endif()

    if(NOT DEFINED VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
        if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/windows.cmake")
        elseif(VCPKG_TARGET_IS_LINUX)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/linux.cmake")
        elseif(VCPKG_TARGET_IS_ANDROID)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/android.cmake")
        elseif(VCPKG_TARGET_IS_OSX)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/osx.cmake")
        elseif(VCPKG_TARGET_IS_IOS)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/ios.cmake")
        elseif(VCPKG_TARGET_IS_FREEBSD)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/freebsd.cmake")
        elseif(VCPKG_TARGET_IS_OPENBSD)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/openbsd.cmake")
        elseif(VCPKG_TARGET_IS_MINGW)
            set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/mingw.cmake")
        endif()
    endif()

    vcpkg_list(APPEND arg_OPTIONS
        "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}"
        "-DVCPKG_TARGET_TRIPLET=${TARGET_TRIPLET}"
        "-DVCPKG_SET_CHARSET_FLAG=${vcpkg_set_charset_flag}"
        "-DVCPKG_PLATFORM_TOOLSET=${VCPKG_PLATFORM_TOOLSET}"
        "-DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON"
        "-DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON"
        "-DCMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY=ON"
        "-DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP=TRUE"
        "-DCMAKE_VERBOSE_MAKEFILE=ON"
        "-DVCPKG_APPLOCAL_DEPS=OFF"
        "-DCMAKE_TOOLCHAIN_FILE=${SCRIPTS}/buildsystems/vcpkg.cmake"
        "-DCMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION=ON"
        "-DVCPKG_CXX_FLAGS=${VCPKG_CXX_FLAGS}"
        "-DVCPKG_CXX_FLAGS_RELEASE=${VCPKG_CXX_FLAGS_RELEASE}"
        "-DVCPKG_CXX_FLAGS_DEBUG=${VCPKG_CXX_FLAGS_DEBUG}"
        "-DVCPKG_C_FLAGS=${VCPKG_C_FLAGS}"
        "-DVCPKG_C_FLAGS_RELEASE=${VCPKG_C_FLAGS_RELEASE}"
        "-DVCPKG_C_FLAGS_DEBUG=${VCPKG_C_FLAGS_DEBUG}"
        "-DVCPKG_CRT_LINKAGE=${VCPKG_CRT_LINKAGE}"
        "-DVCPKG_LINKER_FLAGS=${VCPKG_LINKER_FLAGS}"
        "-DVCPKG_LINKER_FLAGS_RELEASE=${VCPKG_LINKER_FLAGS_RELEASE}"
        "-DVCPKG_LINKER_FLAGS_DEBUG=${VCPKG_LINKER_FLAGS_DEBUG}"
        "-DCMAKE_INSTALL_LIBDIR:STRING=lib"
        "-DCMAKE_INSTALL_BINDIR:STRING=bin"
        "-D_VCPKG_ROOT_DIR=${VCPKG_ROOT_DIR}"
        "-D_VCPKG_INSTALLED_DIR=${_VCPKG_INSTALLED_DIR}"
        "-DVCPKG_MANIFEST_INSTALL=OFF"
    )

    if(DEFINED arch)
        vcpkg_list(APPEND arg_OPTIONS "-A${arch}")
    endif()

    # Sets configuration variables for macOS builds
    foreach(config_var IN ITEMS INSTALL_NAME_DIR OSX_DEPLOYMENT_TARGET OSX_SYSROOT OSX_ARCHITECTURES)
        if(DEFINED VCPKG_${config_var})
            vcpkg_list(APPEND arg_OPTIONS "-DCMAKE_${config_var}=${VCPKG_${config_var}}")
        endif()
    endforeach()

    vcpkg_list(SET rel_command
        "${CMAKE_COMMAND}" "${arg_SOURCE_PATH}"
        ${arg_OPTIONS}
        ${arg_OPTIONS_RELEASE}
        -G "${generator}"
        -DCMAKE_BUILD_TYPE=Release
        "-DCMAKE_INSTALL_PREFIX=${CURRENT_PACKAGES_DIR}"
    )
    vcpkg_list(SET dbg_command
        "${CMAKE_COMMAND}" "${arg_SOURCE_PATH}"
        ${arg_OPTIONS}
        ${arg_OPTIONS_DEBUG}
        -G "${generator}"
        -DCMAKE_BUILD_TYPE=Debug
        "-DCMAKE_INSTALL_PREFIX=${CURRENT_PACKAGES_DIR}/debug")

    if(ninja_host AND CMAKE_HOST_WIN32 AND NOT arg_DISABLE_PARALLEL_CONFIGURE)
        vcpkg_list(APPEND arg_OPTIONS "-DCMAKE_DISABLE_SOURCE_CHANGES=ON")

        vcpkg_find_acquire_program(NINJA)
        get_filename_component(NINJA_PATH "${NINJA}" DIRECTORY)
        vcpkg_add_to_path("${NINJA_PATH}")

        #parallelize the configure step
        set(configure_ninja_contents
            "rule CreateProcess\n  command = $process\n\n"
        )

        if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
            z_vcpkg_configure_cmake_build_cmakecache(configure_ninja_contents ".." "rel")
        endif()
        if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
            z_vcpkg_configure_cmake_build_cmakecache(configure_ninja_contents "../../${TARGET_TRIPLET}-dbg" "dbg")
        endif()

        file(MAKE_DIRECTORY
            "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/vcpkg-parallel-configure"
        )
        file(WRITE
            "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/vcpkg-parallel-configure/build.ninja"
            "${configure_ninja_contents}"
        )

        message(STATUS "Configuring ${TARGET_TRIPLET}")
        vcpkg_execute_required_process(
            COMMAND ninja -v
            WORKING_DIRECTORY
                "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/vcpkg-parallel-configure"
            LOGNAME
                "${arg_LOGNAME}"
        )
        
        list(APPEND config_logs
            "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-out.log"
            "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-err.log")
    else()
        if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
            message(STATUS "Configuring ${TARGET_TRIPLET}-dbg")
            file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
            vcpkg_execute_required_process(
                COMMAND ${dbg_command}
                WORKING_DIRECTORY
                    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
                LOGNAME "${arg_LOGNAME}-dbg"
            )
            list(APPEND config_logs
                "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-dbg-out.log"
                "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-dbg-err.log")
        endif()

        if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
            message(STATUS "Configuring ${TARGET_TRIPLET}-rel")
            file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
            vcpkg_execute_required_process(
                COMMAND ${rel_command}
                WORKING_DIRECTORY
                    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
                LOGNAME "${arg_LOGNAME}-rel"
            )
            list(APPEND config_logs
                "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-rel-out.log"
                "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-rel-err.log")
        endif()
    endif()
    
    # Check unused variables
    set(all_unused_variables)
    foreach(config_log IN LISTS config_logs)
        if (NOT EXISTS "${config_log}")
            continue()
        endif()
        file(READ "${config_log}" log_contents)
        debug_message("Reading configure log ${config_log}...")
        if(NOT log_contents MATCHES "Manually-specified variables were not used by the project:\n\n((    [^\n]*\n)*)")
            continue()
        endif()
        string(STRIP "${CMAKE_MATCH_1}" unused_variables) # remove leading `    ` and trailing `\n`
        string(REPLACE "\n    " ";" unused_variables "${unused_variables}")
        debug_message("unused variables: ${unused_variables}")

        foreach(unused_variable IN LISTS unused_variables)
            if(unused_variable IN_LIST manually_specified_variables)
                debug_message("manually specified unused variable: ${unused_variable}")
                list(APPEND all_unused_variables "${unused_variable}")
            else()
                debug_message("unused variable (not manually specified): ${unused_variable}")
            endif()
        endforeach()
    endforeach()

    if(DEFINED all_unused_variables)
        list(REMOVE_DUPLICATES all_unused_variables)
        list(JOIN all_unused_variables "\n    " all_unused_variables)
        message(WARNING "The following variables are not used in CMakeLists.txt:
    ${all_unused_variables}
Please recheck them and remove the unnecessary options from the `vcpkg_configure_cmake` call.
If these options should still be passed for whatever reason, please use the `MAYBE_UNUSED_VARIABLES` argument.")
    endif()

    set(Z_VCPKG_CMAKE_GENERATOR "${generator}" CACHE INTERNAL "")
endfunction()
