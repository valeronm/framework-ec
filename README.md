# Builder

Builds Framework's Zephyr EC firmware in a container whose every input is
pinned, and proves it by rebuilding Framework's shipped releases byte for
byte. Once a release reproduces, an image built from a branch on top of it
can differ from what Framework ships only by that branch's own commits.

This branch holds no EC source. Check it out beside an EC checkout:

    git worktree add ../builder builder

## Why it is needed

The EC branches do not say how a release is built. Each branch's `west.yml`
names chromium's Zephyr, which cannot build Framework's boards, and the CI
file names a Zephyr branch whose public head cannot build them either. The
toolchain is unstated. The inputs pinned here were found by matching builds
against a dump of a laptop's flash.

## Use

Needs podman or docker.

    ./build.sh --target sakura-20260429 ../sakura-3.0.4 sakura
    ./verify.sh

`build.sh` builds the checkout and prints the path of its `ec.bin`. With
`--repro` it stamps Framework's build user and host, as their images carry;
without it the stamp names the machine that built it.

`verify.sh` rebuilds every release in `releases` on its target and checks
it. Run it after changing a pin or the Dockerfile, before trusting an image.

## Adding a target

A target in `targets/` names the Zephyr snapshot, the coreboot-sdk builds
and the module commits one EC branch builds with. It counts only once a
release builds on it to the hashes of the shipped image, which
`image_hashes.py` gives for a dump of the flash; add that line to
`releases`. A flash size `image_hashes.py` has no layout for is refused.

The build date is not pinned, so two builds of one commit differ in it;
`image_hashes.py` masks it.
