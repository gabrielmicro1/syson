#!/usr/bin/env bash
# Build a SysON image with patched backend classes, without the full Maven build.
#
# Compiles the source files listed in PATCHED_SOURCES against the libraries of the
# base image, replaces those classes in their nested jars, and builds an image
# FROM the base image with the updated application jar.
#
# Usage: benchmark-patch/build.sh            (from the repository root or anywhere)
# Env:   JAVAC (default: javac on PATH; must be JDK 21)
#        BASE_IMAGE (default: eclipsesyson/syson:v2026.9.6)
#        IMAGE (default: syson-benchmark:v2026.9.6-bp1)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
BASE_IMAGE="${BASE_IMAGE:-eclipsesyson/syson:v2026.9.6}"
IMAGE="${IMAGE:-syson-benchmark:v2026.9.6-bp1}"
JAVAC="${JAVAC:-javac}"
WORK="$HERE/.build"

# source root : nested jar name prefix : space-separated source files (relative to the root)
PATCHED_SOURCES=(
  "backend/services/syson-sysml-metamodel-services/src/main/java:syson-sysml-metamodel-services:org/eclipse/syson/sysml/metamodel/services/textual/SysMLElementSerializer.java org/eclipse/syson/sysml/metamodel/services/textual/utils/SysMLKeywordSwitch.java"
)

rm -rf "$WORK" && mkdir -p "$WORK/app"
cid="$(docker create "$BASE_IMAGE")"
docker cp "$cid:/syson-application.jar" "$WORK/app/syson-application.jar" >/dev/null
docker rm "$cid" >/dev/null
(cd "$WORK/app" && unzip -q syson-application.jar 'BOOT-INF/lib/*')
CP="$(ls "$WORK"/app/BOOT-INF/lib/*.jar | tr '\n' ':')"

patched_jars=()
for entry in "${PATCHED_SOURCES[@]}"; do
  IFS=: read -r src_root jar_prefix files <<<"$entry"
  out="$WORK/classes/$jar_prefix"
  mkdir -p "$out"
  srcs=()
  for f in $files; do srcs+=("$REPO/$src_root/$f"); done
  "$JAVAC" -nowarn -XDsuppressNotes --release 21 -d "$out" -cp "$CP" "${srcs[@]}"
  jar_path="$(ls "$WORK"/app/BOOT-INF/lib/"$jar_prefix"-[0-9]*.jar)"
  (cd "$out" && zip -q -r "$jar_path" .)
  patched_jars+=("BOOT-INF/lib/$(basename "$jar_path")")
  echo "patched $(basename "$jar_path"): $(cd "$out" && find . -name '*.class' | wc -l | tr -d ' ') classes"
done

# Spring Boot requires nested jars to be stored uncompressed.
(cd "$WORK/app" && zip -q -0 syson-application.jar "${patched_jars[@]}")

cat >"$WORK/Dockerfile" <<EOF
FROM $BASE_IMAGE
COPY app/syson-application.jar /syson-application.jar
EOF
docker build -q -t "$IMAGE" "$WORK" >/dev/null
echo "built $IMAGE"
