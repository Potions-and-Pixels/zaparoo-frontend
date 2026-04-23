# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
# SPDX-FileCopyrightText: 2026 Callan Barrett
#
# Rust/Cargo integration via Corrosion. Builds zaparoo_launcher_rs as a
# staticlib and links it into a thin C++ executable (launcher) so that Qt's
# CMake machinery (qt_import_qml_plugins) handles all static-plugin and
# qmldir-resource-init wiring correctly — the documented CXX-Qt static-Qt
# topology (topology B: C++ exe + Rust staticlib).

include_guard(GLOBAL)

include(FetchContent)

# Corrosion v0.5.0 cannot parse rustup's "(active, default)" format in
# `rustup toolchain list --verbose`. Work around by resolving the actual
# toolchain binary paths via `rustup which`, bypassing the broken discovery.
# When cross-compiling for MiSTer ARM32, tell Corrosion the Rust target triple
# explicitly. Corrosion's mapping from CMAKE_SYSTEM_PROCESSOR="arm" is
# ambiguous; MiSTer is ARMv7 hard-float (armv7-unknown-linux-gnueabihf).
if(CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_PROCESSOR STREQUAL "arm")
    if(NOT Rust_CARGO_TARGET)
        set(Rust_CARGO_TARGET "armv7-unknown-linux-gnueabihf"
            CACHE STRING "Cargo target triple for ARM32 cross-build" FORCE)
    endif()
endif()

if(NOT Rust_COMPILER)
    find_program(_rustup NAMES rustup
        HINTS "$ENV{HOME}/.cargo/bin" "$ENV{CARGO_HOME}/bin"
              "/root/.cargo/bin")
    if(_rustup)
        execute_process(
            COMMAND "${_rustup}" which rustc
            OUTPUT_VARIABLE _rustup_rustc OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        execute_process(
            COMMAND "${_rustup}" which cargo
            OUTPUT_VARIABLE _rustup_cargo OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
    endif()
    if(_rustup_rustc AND EXISTS "${_rustup_rustc}")
        set(Rust_COMPILER "${_rustup_rustc}" CACHE FILEPATH "Path to rustc" FORCE)
    endif()
    if(_rustup_cargo AND EXISTS "${_rustup_cargo}")
        set(Rust_CARGO "${_rustup_cargo}" CACHE FILEPATH "Path to cargo" FORCE)
    endif()
endif()

FetchContent_Declare(
    Corrosion
    GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
    GIT_TAG v0.5.0
)
FetchContent_MakeAvailable(Corrosion)

# Import the Rust workspace staticlib. Corrosion creates a CMake IMPORTED
# STATIC LIBRARY target named "zaparoo_launcher_rs" (the [lib] name).
corrosion_import_crate(
    MANIFEST_PATH "${CMAKE_SOURCE_DIR}/rust/Cargo.toml"
    CRATES zaparoo-launcher-rs
)

# ── Environment variables for cxx_qt_build's build.rs ───────────────────────
# QMAKE: cxx_qt_build (via qt-build-utils) uses qmake to locate Qt headers
# and libraries. For ARM32 cross-builds the system qmake points to x86_64 Qt;
# override with the cross-compiled qmake.
get_target_property(_rs_qt6_core_type Qt6::Core TYPE)
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    set(_rs_qmake "/opt/qt6-arm32/bin/qmake6")
else()
    find_program(_rs_qmake NAMES qmake6 qmake REQUIRED)
endif()

corrosion_set_env_vars(zaparoo_launcher_rs
    "QMAKE=${_rs_qmake}"
)
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    corrosion_set_env_vars(zaparoo_launcher_rs "ZAPAROO_MISTER=1")
endif()
if(ZAPAROO_DEV)
    corrosion_set_env_vars(zaparoo_launcher_rs "ZAPAROO_DEV_BUILD=1")
endif()

# ── C++ executable ───────────────────────────────────────────────────────────
# Using qt_add_executable (not add_executable) so that Qt's CMake sets up
# the target with all the properties needed by qt_import_qml_plugins.
qt_add_executable(launcher "${CMAKE_SOURCE_DIR}/src/app/main.cpp")

target_compile_definitions(launcher
    PRIVATE ZAPAROO_VERSION="${CMAKE_PROJECT_VERSION}"
)

# For static Qt (ARM32): define QT_STATIC so main.cpp's #ifdef fires.
# Qt itself defines this in its headers, but the compiler may not see it
# before the first #include unless we make it explicit here too.
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    target_compile_definitions(launcher PRIVATE QT_STATIC)
endif()

if(ZAPAROO_DEV)
    target_compile_definitions(launcher PRIVATE ZAPAROO_DEV_BUILD)
endif()

# Load Qt QML plugin CMake configs so that qt_import_qml_plugins can find
# and link the correct static plugin archives. These are not loaded by
# find_package(Qt6 ...) by default.
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    get_filename_component(_rs_qt_prefix "${Qt6_DIR}/../../.." ABSOLUTE)
    file(GLOB _rs_qml_plugin_configs
        "${_rs_qt_prefix}/lib/cmake/Qt6Qml/QmlPlugins/Qt6*Config.cmake"
    )
    foreach(_rs_config IN LISTS _rs_qml_plugin_configs)
        include("${_rs_config}" OPTIONAL)
    endforeach()
    include("${_rs_qt_prefix}/lib/cmake/Qt6Gui/Qt6QLinuxFbIntegrationPluginConfig.cmake" OPTIONAL)
    foreach(_rs_qml_plugin IN ITEMS
            qtquickcontrols2plugin
            qtquickcontrols2basicstyleplugin
            qtquickcontrols2implplugin
            qtquicktemplates2plugin
            quickwindow)
        include("${_rs_qt_prefix}/lib/cmake/Qt6Qml/QmlPlugins/Qt6${_rs_qml_plugin}Config.cmake" OPTIONAL)
    endforeach()
endif()

target_link_libraries(launcher
    PRIVATE
        zaparoo_launcher_rs
        zaparoo_ui_appplugin
        Qt6::Quick
        Qt6::QuickControls2
)

# Critical: documented Qt static-plugin machinery. Runs qmlimportscanner,
# traverses the QML module dependency graph, and emits correct
# Q_IMPORT_QML_PLUGIN calls + --whole-archive link lines for every Qt
# static QML plugin and qmldir resource init .o.
qt_import_qml_plugins(launcher)

# For static Qt (ARM32): the Controls chain _init OBJECT targets carry the
# Q_IMPORT_QML_PLUGIN static-init factories. Not propagated automatically
# from a cross-compiled Qt toolchain, so link them explicitly.
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    if(TARGET Qt6::QLinuxFbIntegrationPlugin)
        target_link_libraries(launcher PRIVATE
            Qt6::QLinuxFbIntegrationPlugin
            Qt6::QLinuxFbIntegrationPlugin_init
        )
    endif()
    foreach(_rs_qml_plugin IN ITEMS
            qtquickcontrols2plugin
            qtquickcontrols2basicstyleplugin
            qtquickcontrols2implplugin
            qtquicktemplates2plugin
            quickwindow)
        if(TARGET Qt6::${_rs_qml_plugin})
            target_link_libraries(launcher PRIVATE
                Qt6::${_rs_qml_plugin}
                Qt6::${_rs_qml_plugin}_init
            )
        endif()
    endforeach()
endif()

set_target_properties(launcher PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
