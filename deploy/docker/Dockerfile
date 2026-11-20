# syntax=docker/dockerfile:1
# Single source for the QGC builder images. Pick a variant with --target:
#   docker build -f deploy/docker/Dockerfile --target linux       .   # x86_64 AppImage
#   docker build -f deploy/docker/Dockerfile --target linux-cross .   # aarch64 cross
# run-docker.sh / plan_docker_builds.py drive --target + build-args; non-Ubuntu
# Linux variants reuse the `linux` target with base/bootstrap/backend overridden.

# ---------- base: shared bootstrap for every variant ----------
# Digest-pinned for reproducibility (re-resolve via `docker buildx imagetools
# inspect` when bumping); BASE_REF/SETUP_BASE overridden for non-Ubuntu distros.
ARG BASE_REF=ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54
FROM ${BASE_REF} AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV PATH="/opt/qgc-venv/bin:${PATH}"

# Shared shell helpers (retry, setup-base*, setup-venv, build-type validation).
COPY deploy/docker/lib/ /usr/local/lib/qgc/

# SETUP_BASE picks the bootstrap (apt/dnf/pacman); APT_EXTRA adds variant
# packages (e.g. "gcc-12 g++-12" on 22.04 for full C++20; apt only).
ARG SETUP_BASE=setup-base.sh
ARG APT_EXTRA=""
# SETUP_BASE is interpolated into a shell path; whitelist it to block traversal.
RUN case "${SETUP_BASE}" in \
        setup-base.sh|setup-base-dnf.sh|setup-base-pacman.sh) ;; \
        *) echo "Invalid SETUP_BASE: ${SETUP_BASE}" >&2; exit 1 ;; \
    esac && \
    APT_EXTRA="${APT_EXTRA}" sh "/usr/local/lib/qgc/${SETUP_BASE}"

# Optional compiler pin (22.04 needs gcc-12 for full C++20). Written to the login
# env so it applies at entrypoint cmake-configure time; empty = distro default.
ARG CC_PIN=""
ARG CXX_PIN=""
RUN if [ -n "${CC_PIN}" ]; then \
        printf 'export CC=%s\nexport CXX=%s\n' "${CC_PIN}" "${CXX_PIN}" \
            > /etc/profile.d/qgc-toolchain.sh; \
    fi

# Build-time Python deps for CMake generators + aqt. PIP_CMAKE pulls a modern
# cmake into the venv when the distro's apt cmake is too old (22.04: 3.22 < 3.25).
ARG PIP_CMAKE=""
COPY --from=ghcr.io/astral-sh/uv:0.11.12 /uv /usr/local/bin/uv
COPY tools/pyproject.toml tools/uv.lock /tmp/qgc-tools/
RUN PIP_CMAKE="${PIP_CMAKE}" sh /usr/local/lib/qgc/setup-venv.sh && \
    rm -rf /tmp/qgc-tools /usr/local/bin/uv

# Version config only (read_config + _bootstrap import need a dir named "tools").
# Copied before the slow Qt layer so editing package lists doesn't bust Qt cache.
COPY .github/build-config.json /tmp/tools/setup/
COPY tools/setup/read_config.py /tmp/tools/setup/
COPY tools/_bootstrap.py /tmp/tools/
COPY tools/common/ /tmp/tools/common/

# --system so it applies to the mapped runtime UID (containers run --user).
RUN git config --system --add safe.directory /project/source && \
    mkdir -p /project/source /project/build
WORKDIR /project/build

# Login shell so /etc/profile.d/*.sh (Qt paths, toolchain pins) are sourced.
SHELL ["/bin/bash", "-lc"]

# ---------- linux: native x86_64 AppImage build ----------
# DEP_PLATFORM selects the install_dependencies backend (debian = apt/Ubuntu &
# Debian; fedora = dnf; arch = pacman). Non-Ubuntu distros set it via build args.
FROM base AS linux
ARG DEP_PLATFORM=debian
# Persist for entrypoint.sh: Fedora/Arch builds skip the appimagelint compat check.
ENV QGC_DEP_PLATFORM=${DEP_PLATFORM}
RUN sh /usr/local/lib/qgc/install-qt.sh linux desktop linux_gcc_64 && \
    QT_VERSION=$(python3 /tmp/tools/setup/read_config.py --get qt.version) && \
    { echo "export QT_ROOT_DIR=/opt/Qt/${QT_VERSION}/gcc_64"; \
      echo 'export PATH=$QT_ROOT_DIR/bin:$PATH'; } > /etc/profile.d/qt.sh
COPY tools/setup/install_dependencies/ /tmp/tools/setup/install_dependencies/
RUN python3 /tmp/tools/setup/install_dependencies --platform "${DEP_PLATFORM}" && \
    rm -rf /var/lib/apt/lists/* /var/cache/dnf /var/cache/pacman/pkg /tmp/tools
COPY deploy/docker/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/bash", "-l", "/entrypoint.sh"]
CMD ["Release"]

# ---------- linux-cross: aarch64 cross-compile (host tools + :arm64 sysroot) ----------
# Why this exists (CI already builds arm64 natively on ubuntu-24.04-arm):
#   - Local developer cross-builds without a target board / QEMU.
#   - Reproducible builds against a specific glibc/Qt without an arm64 runner.
FROM base AS linux-cross
LABEL org.opencontainers.image.documentation="deploy/docker/run-docker.sh (variant: aarch64)"
# Host build tools (core category covers cmake/ninja/build-essential/git/rsync/...).
# Target libs come from the sysroot below, not install_dependencies.
COPY tools/setup/install_dependencies/ /tmp/tools/setup/install_dependencies/
RUN python3 /tmp/tools/setup/install_dependencies --platform debian --category core && \
    rm -rf /var/lib/apt/lists/*
# install-sysroot-aarch64.sh does dpkg --add-architecture arm64, arch-pins the
# amd64 sources, and adds ports.ubuntu.com for arm64.
COPY deploy/docker/install-sysroot-aarch64.sh /tmp/install-sysroot-aarch64.sh
RUN SYSROOT=/opt/sysroot bash /tmp/install-sysroot-aarch64.sh && \
    rm -f /tmp/install-sysroot-aarch64.sh && \
    rm -rf /var/lib/apt/lists/*
ENV SYSROOT=/opt/sysroot
# Qt host (linux/linux_gcc_64) + target (linux_arm64/linux_gcc_arm64). aqt serves
# arm64 desktop under host_os=linux_arm64, not linux; versions from build-config.json.
RUN sh /usr/local/lib/qgc/install-qt.sh linux desktop linux_gcc_64 && \
    sh /usr/local/lib/qgc/install-qt.sh linux_arm64 desktop linux_gcc_arm64 && \
    QT_VERSION=$(python3 /tmp/tools/setup/read_config.py --get qt.version) && \
    { echo "export QT_HOST_PATH=/opt/Qt/${QT_VERSION}/gcc_64"; \
      echo "export QT_ROOT_DIR=/opt/Qt/${QT_VERSION}/gcc_arm64"; \
      echo 'export PATH=$QT_HOST_PATH/bin:$PATH'; } > /etc/profile.d/qt-cross.sh && \
    rm -rf /tmp/tools
COPY deploy/docker/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/bash", "-l", "/entrypoint.sh"]
CMD ["Release"]
