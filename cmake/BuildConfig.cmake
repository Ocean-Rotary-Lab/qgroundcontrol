# ============================================================================
# BuildConfig.cmake - Read .github/build-config.json
# ============================================================================

set(QGC_BUILD_CONFIG_FILE "${CMAKE_SOURCE_DIR}/.github/build-config.json")

if(NOT EXISTS "${QGC_BUILD_CONFIG_FILE}")
    message(FATAL_ERROR "QGC: BuildConfig: Config file not found: ${QGC_BUILD_CONFIG_FILE}")
endif()

file(READ "${QGC_BUILD_CONFIG_FILE}" QGC_BUILD_CONFIG_CONTENT)

# Extract value from JSON using CMake's native JSON parser; supports dotted paths
function(qgc_config_get_value VAR_NAME JSON_KEY)
    string(REPLACE "." ";" _path "${JSON_KEY}")
    string(JSON _value ERROR_VARIABLE _err GET "${QGC_BUILD_CONFIG_CONTENT}" ${_path})
    if(_err)
        message(FATAL_ERROR "QGC: BuildConfig: Key '${JSON_KEY}' not found in ${QGC_BUILD_CONFIG_FILE}")
    endif()
    set(${VAR_NAME} "${_value}" CACHE STRING "${JSON_KEY}" FORCE)
endfunction()

qgc_config_get_value(QGC_CONFIG_QT_VERSION "qt.version")
qgc_config_get_value(QGC_CONFIG_QT_MINIMUM_VERSION "qt.minimum_version")
qgc_config_get_value(QGC_CONFIG_GSTREAMER_VERSION         "gstreamer.version.default")
qgc_config_get_value(QGC_CONFIG_GSTREAMER_MIN_VERSION     "gstreamer.version.minimum")
qgc_config_get_value(QGC_CONFIG_CMAKE_MINIMUM "build.cmake_minimum_version")
message(STATUS "BuildConfig: Qt ${QGC_CONFIG_QT_VERSION}, GStreamer ${QGC_CONFIG_GSTREAMER_VERSION}")
