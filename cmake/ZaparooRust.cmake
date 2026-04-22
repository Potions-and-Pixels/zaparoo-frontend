# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
# SPDX-FileCopyrightText: 2026 Callan Barrett
#
# Rust/Cargo integration via Corrosion. Builds launcher-rs alongside the C++
# launcher; the two binaries are independent. Cutover to Rust (Phase 6) deletes
# src/core and src/app and removes this file's ZAPAROO_BUILD_RUST guard.

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

# Import the Rust workspace. CRATES selects the packages to build; only the
# launcher binary is needed for now. Corrosion creates a CMake target named
# after the binary declared in Cargo.toml: "launcher-rs".
corrosion_import_crate(
    MANIFEST_PATH "${CMAKE_SOURCE_DIR}/rust/Cargo.toml"
    CRATES zaparoo-launcher-rs
)

# Ensure all Zaparoo CMake targets are built before cargo invokes the linker.
# corrosion_link_libraries() would normally do this, but we use explicit
# -Clink-arg= flags instead (see below), so the dependency must be manual.
add_dependencies(_cargo-build_launcher-rs
    zaparoo_core
    zaparoo_coreplugin
    zaparoo_ui_app
    zaparoo_ui_appplugin
    zaparoo_ui_components
    zaparoo_ui_componentsplugin
    zaparoo_ui_theme
    zaparoo_ui_themeplugin
)

# Qt's CMake IMPORTED targets contain dependency graph metadata that Corrosion
# misinterprets as rustc library-renaming directives, producing a build error.
# Work around this by extracting the actual library directory and passing Qt
# link flags as raw linker arguments instead of CMake targets.
#
# Linking strategy for Zaparoo static archives:
#   - Do NOT use corrosion_link_libraries() for Zaparoo libs: it emits
#     -l<lib> under -Wl,-Bdynamic, causing ld to look for .so files that do
#     not exist, and places -L search paths after the -l flags (too late).
#   - Instead, pass everything as -Clink-arg= flags in one block:
#       1. Zaparoo static group (--start-group ... --end-group) FIRST, so that
#          the group's Qt symbol references are outstanding when Qt is processed.
#       2. Qt libraries AFTER the group, satisfying those references under
#          GNU ld's --as-needed mode.
#       3. -lm after the group for log10 used by Config.cpp.
get_target_property(_rs_qt6_core_type Qt6::Core TYPE)
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    # Static Qt (ARM32).
    get_target_property(_rs_qt_core_loc Qt6::Core IMPORTED_LOCATION)
    get_filename_component(_rs_qt_lib_dir "${_rs_qt_core_loc}" DIRECTORY)

    # Disable PIE: Zaparoo static libs are compiled without -fPIC.
    corrosion_add_target_local_rustflags(launcher-rs "-Crelocation-model=static")

    # Qt QML plugin _init OBJECT libraries.
    # In static Qt builds each QML plugin is split across a static archive (.a)
    # and an OBJECT library (*_init) that holds qml_register_types_* — the
    # symbols demanded by Q_IMPORT_QML_PLUGIN in init.cpp.  These OBJECT files
    # are emitted before the archive group so their demands are visible during
    # the group's first scan pass.
    macro(_rs_link_qt_object_lib _obj_target)
        if(TARGET "${_obj_target}")
            get_target_property(_rs_obj_files "${_obj_target}" IMPORTED_OBJECTS_RELEASE)
            if(_rs_obj_files)
                foreach(_rs_obj IN LISTS _rs_obj_files)
                    corrosion_add_target_local_rustflags(launcher-rs
                        "-Clink-arg=${_rs_obj}")
                endforeach()
            endif()
        endif()
    endmacro()

    foreach(_rs_qml_init IN ITEMS
            qtquickcontrols2plugin_init
            qtquickcontrols2basicstyleplugin_init
            qtquickcontrols2implplugin_init
            qtquicktemplates2plugin_init
            quickwindow_init)
        _rs_link_qt_object_lib(Qt6::${_rs_qml_init})
    endforeach()

    # One --start-group/--end-group wrapping ALL static archives.
    # GNU ld makes multiple passes through the group until no new members are
    # added, resolving circular references between Qt module archives and plugins
    # (e.g. libqlinuxfb.a demands QPlatformNativeInterface from libQt6Gui.a, but
    # libQt6Gui.a was scanned before the plugin in a straight left-to-right link).
    corrosion_add_target_local_rustflags(launcher-rs
        "-Clink-arg=-Wl,--start-group"
        "-Clink-arg=-Wl,-Bstatic"
        # Zaparoo static libraries.
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_core>"
        "-Clink-arg=-lzaparoo_core"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_coreplugin>"
        "-Clink-arg=-lzaparoo_coreplugin"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_app>"
        "-Clink-arg=-lzaparoo_ui_app"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_appplugin>"
        "-Clink-arg=-lzaparoo_ui_appplugin"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_components>"
        "-Clink-arg=-lzaparoo_ui_components"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_componentsplugin>"
        "-Clink-arg=-lzaparoo_ui_componentsplugin"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_theme>"
        "-Clink-arg=-lzaparoo_ui_theme"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_themeplugin>"
        "-Clink-arg=-lzaparoo_ui_themeplugin"
        # Qt module libraries (-L set once; all Qt archives share the same dir).
        "-Clink-arg=-L${_rs_qt_lib_dir}"
        "-Clink-arg=-lQt6Quick"
        "-Clink-arg=-lQt6QuickControls2"
        "-Clink-arg=-lQt6QuickControls2Impl"
        "-Clink-arg=-lQt6QuickControls2Basic"
        "-Clink-arg=-lQt6QuickControls2BasicStyleImpl"
        "-Clink-arg=-lQt6QuickTemplates2"
        "-Clink-arg=-lQt6Qml"
        "-Clink-arg=-lQt6QmlBuiltins"
        "-Clink-arg=-lQt6QmlModels"
        "-Clink-arg=-lQt6WebSockets"
        "-Clink-arg=-lQt6Network"
        "-Clink-arg=-lQt6Gui"
        "-Clink-arg=-lQt6Core"
        # Qt bundled 3rdparty archives (same -L dir as Qt modules above).
        "-Clink-arg=-lQt6BundledLibpng"
        "-Clink-arg=-lQt6BundledFreetype"
        "-Clink-arg=-lQt6BundledHarfbuzz"
        "-Clink-arg=-lQt6BundledPcre2"
        "-Clink-arg=-lQt6BundledZLIB"
    )

    # Platform plugin and QML plugin archives (inside the same --start-group).
    # Extract dir+name from IMPORTED_LOCATION at configure time; TARGET_LINKER_FILE_DIR
    # and TARGET_LINKER_FILE_BASE_NAME do not resolve for Qt IMPORTED targets.
    macro(_rs_link_qt_lib_in_group _lib_target)
        if(TARGET "${_lib_target}")
            get_target_property(_rs_loc "${_lib_target}" IMPORTED_LOCATION)
            if(_rs_loc)
                get_filename_component(_rs_dir "${_rs_loc}" DIRECTORY)
                get_filename_component(_rs_stem "${_rs_loc}" NAME_WLE)
                string(REGEX REPLACE "^lib" "" _rs_name "${_rs_stem}")
                add_dependencies(_cargo-build_launcher-rs "${_lib_target}")
                corrosion_add_target_local_rustflags(launcher-rs
                    "-Clink-arg=-L${_rs_dir}"
                    "-Clink-arg=-l${_rs_name}")
            endif()
        endif()
    endmacro()

    _rs_link_qt_lib_in_group(Qt6::QLinuxFbIntegrationPlugin)
    _rs_link_qt_lib_in_group(Qt6::FbSupportPrivate)
    _rs_link_qt_lib_in_group(Qt6::InputSupportPrivate)
    _rs_link_qt_lib_in_group(Qt6::DeviceDiscoverySupportPrivate)
    foreach(_rs_qml_plugin IN ITEMS
            qtquickcontrols2plugin
            qtquickcontrols2basicstyleplugin
            qtquickcontrols2implplugin
            qtquicktemplates2plugin
            quickwindow)
        _rs_link_qt_lib_in_group(Qt6::${_rs_qml_plugin})
    endforeach()

    # Close the archive group and restore dynamic linking.
    corrosion_add_target_local_rustflags(launcher-rs
        "-Clink-arg=-Wl,--end-group"
        "-Clink-arg=-Wl,-Bdynamic"
        "-Clink-arg=-lm"
    )
else()
    # Dynamic Qt (desktop).
    get_target_property(_rs_qt_core_loc Qt6::Core IMPORTED_LOCATION)
    get_filename_component(_rs_qt_lib_dir "${_rs_qt_core_loc}" DIRECTORY)

    # Rust produces PIE binaries by default (-pie), which requires all linked
    # archives to use PIC relocations. The Zaparoo static libs are compiled
    # without -fPIC (matching the C++ executable). Disable PIE for launcher-rs
    # so GNU ld accepts non-PIC R_X86_64_32S relocations from the archives.
    corrosion_add_target_local_rustflags(launcher-rs "-Crelocation-model=static")

    # Rust injects -fuse-ld=lld (LLVM lld) via GCC's -B sysroot path even when
    # the linker driver is c++. Override back to GNU ld (bfd).
    #
    # Zaparoo static group precedes Qt so that the group's Qt symbol references
    # are outstanding when --as-needed processes the Qt DSOs, ensuring Qt is
    # included. -lm follows immediately (Config.cpp uses log10).
    corrosion_add_target_local_rustflags(launcher-rs
        "-Clink-arg=-fuse-ld=bfd"
        "-Clink-arg=-Wl,--start-group"
        "-Clink-arg=-Wl,-Bstatic"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_core>"
        "-Clink-arg=-lzaparoo_core"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_coreplugin>"
        "-Clink-arg=-lzaparoo_coreplugin"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_app>"
        "-Clink-arg=-lzaparoo_ui_app"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_appplugin>"
        "-Clink-arg=-lzaparoo_ui_appplugin"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_components>"
        "-Clink-arg=-lzaparoo_ui_components"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_componentsplugin>"
        "-Clink-arg=-lzaparoo_ui_componentsplugin"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_theme>"
        "-Clink-arg=-lzaparoo_ui_theme"
        "-Clink-arg=-L$<TARGET_LINKER_FILE_DIR:zaparoo_ui_themeplugin>"
        "-Clink-arg=-lzaparoo_ui_themeplugin"
        "-Clink-arg=-Wl,--end-group"
        "-Clink-arg=-Wl,-Bdynamic"
        "-Clink-arg=-lm"
        "-Clink-arg=-L${_rs_qt_lib_dir}"
        "-Clink-arg=-lQt6Quick"
        "-Clink-arg=-lQt6QuickControls2"
        "-Clink-arg=-lQt6Qml"
        "-Clink-arg=-lQt6WebSockets"
        "-Clink-arg=-lQt6Network"
        "-Clink-arg=-lQt6Gui"
        "-Clink-arg=-lQt6Core"
    )
endif()

# Pass Qt include dirs and source dirs to build.rs so the cc crate can compile
# init.cpp. Qt6::Core's first include dir is the module-specific subdir
# (e.g. /usr/include/qt6/QtCore); its parent is the Qt6 root include dir.
get_target_property(_rs_qt_core_incs Qt6::Core INTERFACE_INCLUDE_DIRECTORIES)
list(GET _rs_qt_core_incs 0 _rs_qt_module_dir)
get_filename_component(_rs_qt_include_root "${_rs_qt_module_dir}" DIRECTORY)

corrosion_set_env_vars(launcher-rs
    "ZAPAROO_QT_INCLUDE=${_rs_qt_include_root}"
    "ZAPAROO_CORE_SRC=${CMAKE_SOURCE_DIR}/src/core"
    "ZAPAROO_THIRD_PARTY=${CMAKE_SOURCE_DIR}/third_party"
    "ZAPAROO_APP_SRC=${CMAKE_SOURCE_DIR}/src/app"
)
if(_rs_qt6_core_type STREQUAL "STATIC_LIBRARY")
    corrosion_set_env_vars(launcher-rs "ZAPAROO_MISTER=1")
endif()
if(ZAPAROO_DEV)
    corrosion_set_env_vars(launcher-rs "ZAPAROO_DEV_BUILD=1")
endif()

# Copy the built binary to build/bin/ alongside the C++ launcher. Corrosion
# creates an IMPORTED target so POST_BUILD is unavailable; use DEPENDS instead.
add_custom_target(stage_launcher_rs ALL
    DEPENDS launcher-rs
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:launcher-rs>"
        "${CMAKE_BINARY_DIR}/bin/launcher-rs"
    COMMENT "Staging launcher-rs → build/bin/"
)
