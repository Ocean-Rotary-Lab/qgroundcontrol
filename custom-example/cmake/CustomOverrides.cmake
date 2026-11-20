# ============================================================================
# Custom Build Configuration Overrides
# Template for customizing QGroundControl branding and feature set
# ============================================================================

# ----------------------------------------------------------------------------
# Application Branding
# ----------------------------------------------------------------------------
set(QGC_APP_NAME "Custom-QGroundControl" CACHE STRING "App Name" FORCE)

# ----------------------------------------------------------------------------
# Custom Icons and Graphics
# ----------------------------------------------------------------------------

# Linux AppImage Icon
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/custom_qgroundcontrol.svg")
    set(QGC_APPIMAGE_ICON_SCALABLE_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/custom_qgroundcontrol.svg" CACHE FILEPATH "AppImage Icon SVG Path" FORCE)
endif()

# ----------------------------------------------------------------------------
# Feature Set Customization
# ----------------------------------------------------------------------------

# Single flight stack UI: only register the custom PX4-based plugin factory.
# All firmware plugin code is always compiled; UI adapts at runtime via
# FirmwarePluginManager::supportedFirmwareClasses().
set(QGC_DISABLE_APM_PLUGIN_FACTORY ON CACHE BOOL "Disable APM Plugin Factory" FORCE)

# Implement custom PX4 plugin factory
set(QGC_DISABLE_PX4_PLUGIN_FACTORY ON CACHE BOOL "Disable PX4 Plugin Factory" FORCE)
