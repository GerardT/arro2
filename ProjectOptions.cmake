include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(arro2_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(arro2_setup_options)
  option(arro2_ENABLE_HARDENING "Enable hardening" ON)
  option(arro2_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    arro2_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    arro2_ENABLE_HARDENING
    OFF)

  arro2_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR arro2_PACKAGING_MAINTAINER_MODE)
    option(arro2_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(arro2_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(arro2_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(arro2_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(arro2_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(arro2_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(arro2_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(arro2_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(arro2_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(arro2_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(arro2_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(arro2_ENABLE_PCH "Enable precompiled headers" OFF)
    option(arro2_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(arro2_ENABLE_IPO "Enable IPO/LTO" ON)
    option(arro2_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(arro2_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(arro2_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(arro2_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(arro2_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(arro2_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(arro2_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(arro2_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(arro2_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(arro2_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(arro2_ENABLE_PCH "Enable precompiled headers" OFF)
    option(arro2_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      arro2_ENABLE_IPO
      arro2_WARNINGS_AS_ERRORS
      arro2_ENABLE_USER_LINKER
      arro2_ENABLE_SANITIZER_ADDRESS
      arro2_ENABLE_SANITIZER_LEAK
      arro2_ENABLE_SANITIZER_UNDEFINED
      arro2_ENABLE_SANITIZER_THREAD
      arro2_ENABLE_SANITIZER_MEMORY
      arro2_ENABLE_UNITY_BUILD
      arro2_ENABLE_CLANG_TIDY
      arro2_ENABLE_CPPCHECK
      arro2_ENABLE_COVERAGE
      arro2_ENABLE_PCH
      arro2_ENABLE_CACHE)
  endif()

  arro2_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (arro2_ENABLE_SANITIZER_ADDRESS OR arro2_ENABLE_SANITIZER_THREAD OR arro2_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(arro2_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(arro2_global_options)
  if(arro2_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    arro2_enable_ipo()
  endif()

  arro2_supports_sanitizers()

  if(arro2_ENABLE_HARDENING AND arro2_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR arro2_ENABLE_SANITIZER_UNDEFINED
       OR arro2_ENABLE_SANITIZER_ADDRESS
       OR arro2_ENABLE_SANITIZER_THREAD
       OR arro2_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${arro2_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${arro2_ENABLE_SANITIZER_UNDEFINED}")
    arro2_enable_hardening(arro2_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(arro2_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(arro2_warnings INTERFACE)
  add_library(arro2_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  arro2_set_project_warnings(
    arro2_warnings
    ${arro2_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(arro2_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(arro2_options)
  endif()

  include(cmake/Sanitizers.cmake)
  arro2_enable_sanitizers(
    arro2_options
    ${arro2_ENABLE_SANITIZER_ADDRESS}
    ${arro2_ENABLE_SANITIZER_LEAK}
    ${arro2_ENABLE_SANITIZER_UNDEFINED}
    ${arro2_ENABLE_SANITIZER_THREAD}
    ${arro2_ENABLE_SANITIZER_MEMORY})

  set_target_properties(arro2_options PROPERTIES UNITY_BUILD ${arro2_ENABLE_UNITY_BUILD})

  if(arro2_ENABLE_PCH)
    target_precompile_headers(
      arro2_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(arro2_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    arro2_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(arro2_ENABLE_CLANG_TIDY)
    arro2_enable_clang_tidy(arro2_options ${arro2_WARNINGS_AS_ERRORS})
  endif()

  if(arro2_ENABLE_CPPCHECK)
    arro2_enable_cppcheck(${arro2_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(arro2_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    arro2_enable_coverage(arro2_options)
  endif()

  if(arro2_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(arro2_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(arro2_ENABLE_HARDENING AND NOT arro2_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR arro2_ENABLE_SANITIZER_UNDEFINED
       OR arro2_ENABLE_SANITIZER_ADDRESS
       OR arro2_ENABLE_SANITIZER_THREAD
       OR arro2_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    arro2_enable_hardening(arro2_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
