# One image per target in targets/, built by build.sh with that target's pins
# as build arguments. A release builds byte for byte only with exactly these
# inputs, and verify.sh checks that before an image built here is trusted.
FROM docker.io/library/debian:trixie-slim@sha256:1e1a22175fbf1b32157ddaf0219e1db4e5401fab2b94ed285add64d18587cd2d

# Plain http: the archive keyring signs the packages, and ca-certificates
# arrives through this mirror. The EC's toolchain preprocesses the
# devicetree with the host's clang.
ARG SNAPSHOT=20261030T000000Z
RUN rm /etc/apt/sources.list.d/debian.sources \
 && printf 'Types: deb\nURIs: http://snapshot.debian.org/archive/%s/%s\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\n' \
      debian "$SNAPSHOT" "trixie trixie-updates" \
      debian-security "$SNAPSHOT" trixie-security \
      > /etc/apt/sources.list.d/snapshot.sources \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl zstd git cmake ninja-build device-tree-compiler gperf clang \
      python3 python3-yaml python3-pykwalify python3-packaging python3-pyelftools \
      python3-colorama python3-jsonschema python3-libfdt python3-setuptools \
 && rm -rf /var/lib/apt/lists/*

# Zephyr stamps its `git describe` into the image, and the checkouts belong
# to root while builds run as the caller.
RUN git config --system --add safe.directory '*'

ARG UBOOT_COMMIT=ece349ade2973e220f524ce59e59711cc919263f
RUN git init -q /opt/u-boot \
 && git -C /opt/u-boot fetch -q --depth 1 https://source.denx.de/u-boot/u-boot.git $UBOOT_COMMIT \
 && git -C /opt/u-boot checkout -q FETCH_HEAD \
 && ln -s /opt/u-boot/tools/binman/binman /usr/local/bin/binman

# ChromiumOS's coreboot-sdk, built daily into a public bucket; a target names
# the builds its releases match.
ARG SDK_ARM SDK_ARM_SHA256 SDK_PICOLIBC SDK_PICOLIBC_SHA256
RUN sdk=https://storage.googleapis.com/chromiumos-sdk/toolchains \
 && curl -fsSLo /tmp/arm.tar.zst "$sdk/$SDK_ARM" \
 && curl -fsSLo /tmp/picolibc.tar.zst "$sdk/$SDK_PICOLIBC" \
 && printf '%s  %s\n' "$SDK_ARM_SHA256" /tmp/arm.tar.zst "$SDK_PICOLIBC_SHA256" /tmp/picolibc.tar.zst \
    | sha256sum -c \
 && mkdir -p /opt/coreboot-sdk/arm-eabi /opt/coreboot-sdk/picolibc-arm-eabi \
 && tar -C /opt/coreboot-sdk/arm-eabi --zstd -xf /tmp/arm.tar.zst \
 && tar -C /opt/coreboot-sdk/picolibc-arm-eabi --zstd -xf /tmp/picolibc.tar.zst \
 && rm /tmp/*.tar.zst

# Each EC branch's west.yml names chromium's Zephyr, which cannot build it;
# Framework's fork at the snapshot named like the branch is what releases use.
# Zephyr orders the driver API sections by the absolute paths of the header
# directories it scans, so the EC has to sit before Zephyr, as in ChromeOS's
# src/platform and src/third_party.
ARG ZEPHYR_COMMIT CMSIS_COMMIT NANOPB_COMMIT CRYPTOC_COMMIT
RUN fetch() { git init -q "$1" && git -C "$1" fetch -q --depth 1 "$2" "$3" && git -C "$1" checkout -q FETCH_HEAD; } \
 && fetch /src/third_party/zephyr/main https://github.com/FrameworkComputer/zephyr.git "$ZEPHYR_COMMIT" \
 && fetch /opt/modules/cmsis https://chromium.googlesource.com/chromiumos/third_party/zephyr/cmsis "$CMSIS_COMMIT" \
 && fetch /opt/modules/nanopb https://chromium.googlesource.com/chromiumos/third_party/zephyr/nanopb "$NANOPB_COMMIT" \
 && fetch /opt/modules/cryptoc https://chromium.googlesource.com/chromiumos/third_party/cryptoc "$CRYPTOC_COMMIT" \
 && ln -s /src/platform/ec /opt/modules/ec

ENV COREBOOT_SDK_ROOT_arm=/opt/coreboot-sdk/arm-eabi \
    COREBOOT_SDK_ROOT_picolibc_arm=/opt/coreboot-sdk/picolibc-arm-eabi \
    PYTHONPATH=/src/platform/ec/zephyr/zmake \
    HOME=/tmp
