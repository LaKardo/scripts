#!/bin/bash

CHATID=482554110

BASE_DIR="/tmp/kernel"
KERNEL_DIR="$BASE_DIR/kernel_r8q"
TOOLCHAIN_DIR="$BASE_DIR/toolchain"
REPACK_DIR="$BASE_DIR/AnyKernel3"
ZIP_DIR="$BASE_DIR/zip"
KBUILD_OUTPUT="$KERNEL_DIR/out"

IMAGE="$KBUILD_OUTPUT/arch/arm64/boot/Image.gz"
DTB="$KBUILD_OUTPUT/dtb.img"

DEFCONFIG="soviet-star_defconfig"

BASE_AK_VER="SOVIET-STAR-"
DATE=`date +"%Y%m%d-%H%M"`
AK_VER="$BASE_AK_VER$VER"
ZIP_NAME="$AK_VER"-"$DATE"

export BOT_MSG_URL="https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument"

git_clone(){
    mkdir -p /tmp/kernel
    cd $BASE_DIR
    echo
    tg_post_msg "<b>Cloning kernel sources</b>"
    echo
    git clone --recursive --shallow-submodules --depth 1 --jobs 8 https://github.com/LaKardo/android_kernel_r8q kernel_r8q
    echo
    mkdir -p /tmp/kernel/AnyKernel3
    cd $REPACK_DIR
    echo
    tg_post_msg "<b>Cloning AnyKernel3</b>"
    echo
    git clone --recursive --shallow-submodules --depth 1 --jobs 8 https://github.com/LaKardo/AnyKernel3 -b r8q AnyKernel3
    echo
    mkdir -p /tmp/kernel/toolchain
    cd $TOOLCHAIN_DIR
    tg_post_msg "<b>Cloning toolchain</b>"
    git clone --recursive --shallow-submodules --depth 1 --jobs 8 https://github.com/kdrag0n/proton-clang proton-clang
    cd /tmp
    echo
    tg_post_msg "<b>Cloning finished succsesfully</b>"
    echo
}

exports() {
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_BUILD_USER=LaKardo
	export KBUILD_BUILD_HOST=KREMLIN

	export CLANG_PATH=$TOOLCHAIN_DIR/proton-clang/bin
	export PATH=${CLANG_PATH}:${PATH}
	export CROSS_COMPILE=${CLANG_PATH}/aarch64-linux-gnu-
	export CROSS_COMPILE_ARM32=${CLANG_PATH}/arm-linux-gnueabi-

	export KBUILD_COMPILER_STRING=$("$CLANG_PATH"/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
}

tg_post_msg() {
	curl -s -X POST $BOT_MSG_URL -d chat_id=$CHATID \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

tg_post_build() {
	curl --progress-bar -F document=@"$1" $BOT_BUILD_URL \
	-F chat_id=$CHATID  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"
}

make_kernel() {
	git_clone
	exports
	tg_post_msg "<b>NEW CI Build Triggered</b>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>"
	echo
	BUILD_START=$(date +"%s")
	cd $KERNEL_DIR
	make O=$KBUILD_OUTPUT CC=clang $DEFCONFIG -j8
	make O=$KBUILD_OUTPUT CC=clang -j8  2>&1 | tee error.log
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	check_img
}

check_img() {
	if [ -f $KBUILD_OUTPUT/arch/arm64/boot/Image.gz ]
	    then
	    cat $KBUILD_OUTPUT/arch/arm64/boot/dts/vendor/qcom/*.dtb > $KBUILD_OUTPUT/dtb.img
		make_zip
	else
		tg_post_build "error.log"
		tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
	fi
}

make_zip() {
	cp $IMAGE $REPACK_DIR
	cp $DTB $REPACK_DIR/dtb
	cd $REPACK_DIR
	zip -r9 `echo $ZIP_NAME`.zip *
	mv  `echo $ZIP_NAME`*.zip $ZIP_DIR
	echo
	tg_post_build $ZIP_DIR/$ZIP_NAME.zip
	echo
	tg_post_msg "<b>Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
	echo
}

make_kernel
