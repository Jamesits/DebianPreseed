#!/bin/bash
set -Eeuo pipefail

# for debugging
#set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PRESETS_DIR="$DIR/presets"
PRESET=$1
PRESET_DIR="$PRESETS_DIR/$PRESET"
BUILD_DIR="$DIR/build"

create_env() {
	rm -rf --one-file-system "$BUILD_DIR/isoroot"
	rm -f "${DEST_IMG_BASENAME}"
	mkdir -p "$BUILD_DIR/isoroot"
}

destroy_env() {
	echo "done"
}

load_config() {
	source "$PRESET_DIR/config.sh"
	SOURCE_IMG_BASENAME="$(basename "$SOURCE_IMG")"
	DEST_IMG_NAME="${SOURCE_IMG_BASENAME%.*}-${PRESET}"
	DEST_IMG_BASENAME="${DEST_IMG_NAME}.${SOURCE_IMG_BASENAME##*.}"

	echo "${SOURCE_IMG_BASENAME} => ${DEST_IMG_BASENAME}"
}

download_img() {
	wget --continue "$SOURCE_IMG"
}

extract_img() {
	dd if="$SOURCE_IMG_BASENAME" bs=1 count=432 of="isohdpfx.bin"
	xorriso -osirrox on -indev "$SOURCE_IMG_BASENAME" -extract / "$BUILD_DIR/isoroot"
}

inject_files() {
	pushd "$BUILD_DIR/isoroot"
	chmod +w -R install.*/
	cp "$PRESET_DIR/preseed.cfg" .
	for f in install.*/initrd.gz install.*/*/initrd.gz; do
		echo "Processing ${f}..."
		ORIG_NAME="${f%.*}"
		gunzip "$f"
		echo preseed.cfg | cpio -H newc -o -A -F "${ORIG_NAME}"
		gzip "${ORIG_NAME}"
	done
	rm preseed.cfg
	chmod -w -R install.*/
	popd
}

pack_img() {
	pushd "$BUILD_DIR/isoroot"
	md5sum `find -follow -type f` > md5sum.txt
	popd
	xorriso -as mkisofs -r -checksum_algorithm_iso md5,sha1,sha256,sha512 -V "Debian preseeded"  -o "$BUILD_DIR/${DEST_IMG_BASENAME}" -J -joliet-long -cache-inodes -isohybrid-mbr isohdpfx.bin -b isolinux/isolinux.bin -c isolinux/boot.cat -boot-load-size 4 -boot-info-table -no-emul-boot -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus isoroot
}

load_config
create_env

pushd "$BUILD_DIR"
download_img
extract_img
inject_files
pack_img
popd

destroy_env
