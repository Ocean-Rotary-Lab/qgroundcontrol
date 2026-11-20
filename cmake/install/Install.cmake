# ============================================================================
# QGroundControl Installation Configuration
# Handles platform-specific installation and packaging
# ============================================================================

include(InstallRequiredSystemLibraries)

# Note: Installer generation could be conditioned on Release builds
# if(QGC_BUILD_INSTALLER AND CMAKE_INSTALL_CONFIG_NAME MATCHES "^[Rr]elease$")

# ----------------------------------------------------------------------------
# Main Target Installation
# ----------------------------------------------------------------------------
install(
    TARGETS ${CMAKE_PROJECT_NAME}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    BUNDLE  DESTINATION .
)

# ----------------------------------------------------------------------------
# Qt Deployment Script Generation
# ----------------------------------------------------------------------------
set(deploy_include_plugins INCLUDE_PLUGINS qoffscreen qwayland)
# Avoid deploying Qt plugins backed by optional system libraries.
set(deploy_exclude_plugins EXCLUDE_PLUGINS
    qsqlmysql qsqlpsql qsqlodbc qsqloci qsqlibase qsqlmimer qtiff)

qt_generate_deploy_qml_app_script(
    TARGET ${CMAKE_PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
    ${deploy_include_plugins}
    ${deploy_exclude_plugins}
)

install(SCRIPT ${deploy_script})
message(STATUS "QGC: Qt deployment script: ${deploy_script}")

# Strip unused SQL-driver/TIFF plugins whose missing backing libs would abort
# CPackDeb's dpkg-shlibdeps; Unspecified component so it runs for install + CPack.
if(LINUX)
    install(CODE [[
        set(_qgc_prefix "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}")
        file(GLOB _qgc_strip_plugins
            "${_qgc_prefix}/plugins/sqldrivers/libqsqlmysql.*"
            "${_qgc_prefix}/plugins/sqldrivers/libqsqlpsql.*"
            "${_qgc_prefix}/plugins/sqldrivers/libqsqlodbc.*"
            "${_qgc_prefix}/plugins/sqldrivers/libqsqloci.*"
            "${_qgc_prefix}/plugins/sqldrivers/libqsqlibase.*"
            "${_qgc_prefix}/plugins/sqldrivers/libqsqlmimer.*"
            "${_qgc_prefix}/plugins/imageformats/libqtiff.*")
        if(_qgc_strip_plugins)
            message(STATUS "QGC: stripping unused Qt plugins from package: ${_qgc_strip_plugins}")
            file(REMOVE ${_qgc_strip_plugins})
        endif()
    ]])
endif()

# ----------------------------------------------------------------------------
# Linux Installation & AppImage Creation
# ----------------------------------------------------------------------------
if(LINUX)
    configure_file(
        "${QGC_APPIMAGE_DESKTOP_ENTRY_PATH}"
        "${CMAKE_BINARY_DIR}/${QGC_PACKAGE_NAME}.desktop"
        @ONLY
    )
    install(
        FILES "${CMAKE_BINARY_DIR}/${QGC_PACKAGE_NAME}.desktop"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
    )
    install(
        FILES "${QGC_APPIMAGE_ICON_256_PATH}"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps/"
        RENAME ${CMAKE_PROJECT_NAME}.png
    )
    install(
        FILES "${QGC_APPIMAGE_ICON_SCALABLE_PATH}"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps/"
        RENAME ${CMAKE_PROJECT_NAME}.svg
    )
    configure_file(
        "${QGC_APPIMAGE_METADATA_PATH}"
        "${CMAKE_BINARY_DIR}/${QGC_PACKAGE_NAME}.appdata.xml"
        @ONLY
    )
    install(
        FILES "${CMAKE_BINARY_DIR}/${QGC_PACKAGE_NAME}.appdata.xml"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/metainfo/"
    )
    configure_file(
        "${QGC_APPIMAGE_APPRUN_PATH}"
        "${CMAKE_BINARY_DIR}/AppRun"
        COPYONLY
    )

    # Non-fatal lint of the generated .desktop/appstream metadata: runs only when
    # the linters are present, so hosts without them aren't gated.
    find_program(QGC_DESKTOP_FILE_VALIDATE desktop-file-validate)
    if(QGC_DESKTOP_FILE_VALIDATE)
        execute_process(
            COMMAND "${QGC_DESKTOP_FILE_VALIDATE}" "${CMAKE_BINARY_DIR}/${QGC_PACKAGE_NAME}.desktop"
            RESULT_VARIABLE _qgc_desktop_lint
        )
        if(NOT _qgc_desktop_lint EQUAL 0)
            message(WARNING "QGC: desktop-file-validate reported issues for ${QGC_PACKAGE_NAME}.desktop")
        endif()
    endif()
    find_program(QGC_APPSTREAMCLI appstreamcli)
    if(QGC_APPSTREAMCLI)
        execute_process(
            COMMAND "${QGC_APPSTREAMCLI}" validate --no-net "${CMAKE_BINARY_DIR}/${QGC_PACKAGE_NAME}.appdata.xml"
            RESULT_VARIABLE _qgc_appstream_lint
        )
        if(NOT _qgc_appstream_lint EQUAL 0)
            message(WARNING "QGC: appstreamcli validate reported issues for ${QGC_PACKAGE_NAME}.appdata.xml")
        endif()
    endif()

    # Dedicated "appimage" component so `cmake --install` builds the AppImage but
    # CPack can exclude it (CPACK_COMPONENTS_ALL) and skip it during .deb/.rpm staging.
    install(CODE "
        set(CMAKE_PROJECT_NAME \"${CMAKE_PROJECT_NAME}\")
        set(CMAKE_PROJECT_VERSION \"${CMAKE_PROJECT_VERSION}\")
        set(QGC_PACKAGE_NAME \"${QGC_PACKAGE_NAME}\")
        set(QGC_BUILD_DIR \"${CMAKE_BINARY_DIR}\")
        set(CMAKE_SYSTEM_PROCESSOR \"${CMAKE_SYSTEM_PROCESSOR}\")
        set(QGC_RUN_APPIMAGELINT \"${QGC_RUN_APPIMAGELINT}\")
        set(QGC_LINUX_DISTRO_FAMILY \"${QGC_LINUX_DISTRO_FAMILY}\")
    " COMPONENT appimage)
    if(QGC_CREATE_APPIMAGE AND NOT CMAKE_CROSSCOMPILING)
        install(SCRIPT "${CMAKE_SOURCE_DIR}/cmake/install/CreateAppImage.cmake" COMPONENT appimage)
    endif()

    # Native package (.deb/.rpm via CPack, Arch via makepkg) is built by the
    # shared qgc-package dispatch at the end of this file.

endif()

# ============================================================================
# Optional CPack native package — `qgc-package` target, opt-in via
# QGC_CPACK_GENERATOR. Runs alongside the platform's default installer
# (AppImage / NSIS .exe / DMG), which `cmake --install` still produces.
# Must follow all install() rules above: each CreateCPack*.cmake ends in
# include(CPack), which snapshots the install layout.
# ============================================================================
set(_qgc_cpack_module "")
if(QGC_CPACK_GENERATOR STREQUAL "DEB")
    set(_qgc_cpack_module "CPack/CreateCPackDeb.cmake")
elseif(QGC_CPACK_GENERATOR STREQUAL "RPM")
    set(_qgc_cpack_module "CPack/CreateCPackRPM.cmake")
elseif(QGC_CPACK_GENERATOR STREQUAL "TXZ")
    set(_qgc_cpack_module "CPack/CreateCPackArchive.cmake")
endif()

# Warn when the host can't actually build the selected Linux native package.
if(QGC_CPACK_GENERATOR STREQUAL "DEB" AND DEFINED QGC_LINUX_DISTRO_FAMILY
        AND NOT QGC_LINUX_DISTRO_FAMILY STREQUAL "" AND NOT QGC_LINUX_DISTRO_FAMILY STREQUAL "debian")
    message(WARNING "QGC: QGC_CPACK_GENERATOR=DEB on a non-Debian host (${QGC_LINUX_DISTRO}); "
        "cpack needs dpkg-dev/dpkg-shlibdeps to build the .deb.")
elseif(QGC_CPACK_GENERATOR STREQUAL "RPM" AND DEFINED QGC_LINUX_DISTRO_FAMILY
        AND NOT QGC_LINUX_DISTRO_FAMILY STREQUAL "" AND NOT QGC_LINUX_DISTRO_FAMILY STREQUAL "rhel")
    message(WARNING "QGC: QGC_CPACK_GENERATOR=RPM on a non-RPM host (${QGC_LINUX_DISTRO}); "
        "cpack needs rpmbuild to build the .rpm.")
endif()

if(_qgc_cpack_module)
    include("${CMAKE_SOURCE_DIR}/cmake/install/${_qgc_cpack_module}")
    add_custom_target(qgc-package
        COMMAND "${CMAKE_CPACK_COMMAND}" -G "${QGC_CPACK_GENERATOR}"
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
        VERBATIM
        COMMENT "QGC: building ${QGC_CPACK_GENERATOR} package via CPack"
    )
elseif(LINUX AND QGC_LINUX_DISTRO_FAMILY STREQUAL "arch")
    include("${CMAKE_SOURCE_DIR}/cmake/install/CreateArchPackage.cmake")
elseif(LINUX)
    add_custom_target(qgc-package
        COMMAND "${CMAKE_COMMAND}" -E echo
            "QGC: QGC_CPACK_GENERATOR unset; the default installer is produced by 'cmake --install'."
        VERBATIM
        COMMENT "QGC: no CPack generator selected"
    )
endif()
