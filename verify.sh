#!/usr/bin/env bash
# Builds each release in this directory's `releases` from its commit on its
# target, with Framework's stamp, and checks it against the shipped image.
#
#   verify.sh [<repository>]
#
# The commits are read from <repository>, the EC repository this branch's
# worktree belongs to by default. A pass proves a target builds what
# Framework ships, which is what bounds a local image built on it to the
# commits on top.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=${1:-$here}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"; git -C "$repo" worktree prune' EXIT

failed=0
while read -r project commit target ro rw; do
	case $project in '#'* | '') continue ;; esac
	checkout=$scratch/$commit/ec
	git -C "$repo" worktree add -q --detach "$checkout" "$commit"
	image=$("$here/build.sh" --target "$target" --repro "$checkout" "$project")
	read -r built_ro built_rw < <(python3 -I "$here/image_hashes.py" "$image")
	if [ "$built_ro $built_rw" = "$ro $rw" ]; then
		echo "match    $project ${commit:0:7} on $target"
	else
		echo "MISMATCH $project ${commit:0:7} on $target: RO $([ "$built_ro" = "$ro" ] && echo ok || echo differs), RW $([ "$built_rw" = "$rw" ] && echo ok || echo differs)"
		failed=1
	fi
done < "$here/releases"
exit $failed
