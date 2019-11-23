#!/bin/bash
set -Eeuxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PRESETS_DIR="$DIR/presets"
PRESET=$1
PRESET_DIR="$PRESETS/$PRESET"
BUILD_DIR="$DIR/build"

create_env() {
	mkdir -p "$BUILD_DIR/isoroot"
}

destroy_env() {
}

load_config() {
	source "$PRESET_DIR/config.sh"
	SOURCE_IMG_BASENAME="$(basename "$SOURCE_IMG")"
}

download_img() {
	wget --continue "$SOURCE_IMG"
}

extract_img() {
	xorriso -osirrox on -indev "$SOURCE_IMG_BASENAME" -extract / "$BUILD_DIR/isoroot"
}

inject_files() {
	pushd "$BUILD_DIR/isoroot"
	chmod +w -R install.*/
	gunzip isofiles/install.*/initrd.gz
	bash
	echo preseed.cfg | cpio -H newc -o -A -F isofiles/install.*/initrd
	gzip install.*/initrd
	chmod -w -R install.*/
	popd
}

pack_img() {
	pushd "$BUILD_DIR/isoroot"
	md5sum `find -follow -type f` > md5sum.txt
	popd
}

create_env
load_config

pushd "$BUILD_DIR"
download_img
extract_img
inject_files
pack_img
popd

destroy_env
