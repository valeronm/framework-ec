#!/usr/bin/env bash
# Builds an EC checkout in the pinned environment of one target in targets/,
# with podman or docker, and prints the path of its ec.bin.
#
#   build.sh --target <target> [--repro] <checkout> <project>
#
# --repro stamps the build with Framework's build user and host, as a
# shipped image carries; without it the stamp is this machine's, so a local
# image cannot pass for theirs. An untracked or changed file in the checkout
# appends `+` to the version string, which moves every byte after it.
set -euo pipefail

usage() { echo "usage: $0 --target <target> [--repro] <checkout> <project>" >&2; exit 2; }
target= repro=0
while [ $# -gt 0 ]; do
	case $1 in
	--target) target=${2:-}; shift 2 ;;
	--repro) repro=1; shift ;;
	-*) usage ;;
	*) break ;;
	esac
done
[ -n "$target" ] && [ $# -eq 2 ] || usage
here=$(cd "$(dirname "$0")" && pwd)
pins=$here/targets/$target
[ -f "$pins" ] || { echo "no target $target in $here/targets" >&2; exit 1; }
checkout=$(cd "$1" && pwd)
project=$2

# The release number lives only in the CI matrix, which each version bump edits.
version=$(sed -n "s/.*{ name: $project,.* ver: \"\([^\"]*\)\".*/\1/p" \
	"$checkout/.github/workflows/zephyr-build.yml")
[ -n "$version" ] || { echo "$project has no version in the CI matrix" >&2; exit 1; }

engine=$(command -v podman || command -v docker) || { echo "needs podman or docker" >&2; exit 1; }
build_args=()
while IFS='=' read -r key value; do
	case $key in '' | '#'*) continue ;; esac
	build_args+=(--build-arg "$key=$value")
done < "$pins"
image=fwk-ec-build:$target
"$engine" build -q "${build_args[@]}" -t "$image" "$here" >/dev/null

if [ "$(basename "$engine")" = podman ]; then
	owner=(--userns=keep-id)
else
	owner=(--user "$(id -u):$(id -g)")
fi
if [ $repro -eq 1 ]; then
	stamp=(--hostname ip-172-26-3-226 -e LOGNAME=lotus -e USER=lotus)
else
	stamp=(--hostname "$(hostname)" -e LOGNAME="$(id -un)" -e USER="$(id -un)")
fi
# zmake reads the commit through git, and a worktree's history sits in the
# repository it was added from, at the path its .git file names.
git_dir=$(git -C "$checkout" rev-parse --path-format=absolute --git-common-dir)

"$engine" run --rm "${owner[@]}" "${stamp[@]}" \
	-v "$checkout:/src/platform/ec" -v "$git_dir:$git_dir" -w /src/platform/ec \
	"$image" sh -c 'rm -rf build && python3 -m zmake --modules-dir /opt/modules \
		--zephyr-base /src/third_party/zephyr/main build -t coreboot-sdk -v "$0" "$1"' \
	"$version" "$project" >&2
echo "$checkout/build/zephyr/$project/output/ec.bin"
