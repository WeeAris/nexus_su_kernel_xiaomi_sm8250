#!/usr/bin/env bash

 #
 # Script For Building Android Kernel
 #

##----------------------------------------------------------##
# Specify Kernel Directory
KERNEL_DIR="$(pwd)"


DEVICE=$1

if [ "${DEVICE}" = "alioth" ]; then
DEFCONFIG=alioth_defconfig
MODEL="Poco F3"
VERSION=BETA
elif [ "${DEVICE}" = "lmi" ]; then
DEFCONFIG=lmi_defconfig
MODEL="Poco F2 Pro"
VERSION=BETA
elif [ "${DEVICE}" = "apollo" ]; then
DEFCONFIG=apollo_defconfig
MODEL="Mi 10T Pro"
VERSION=BETA
elif [ "${DEVICE}" = "munch" ]; then
DEFCONFIG=munch_defconfig
MODEL="Poco F4"
VERSION=BETA
fi

# Files
IMAGE=$(pwd)/out/arch/arm64/boot/Image
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
OUT_DIR=out/
dts_source=arch/arm64/boot/dts/vendor/qcom

# Verbose Build
VERBOSE=0

# Kernel Version
KERVER=$(make kernelversion)

COMMIT_HEAD=$(git log --oneline -1)

# Date and Time
DATE=$(TZ=Europe/Lisbon date +"%Y%m%d-%T")
TM=$(date +"%F%S")

# Specify Final Zip Name
ZIPNAME=Nexus
FINAL_ZIP=${ZIPNAME}-${VERSION}-${DEVICE}-3.0-KERNEL-AOSP-${TM}.zip

##----------------------------------------------------------##
# Specify compiler [ proton, atomx, eva, aosp ]
COMPILER=hana
CLANG_DIR=/home/masaka/code/clang/hana-clang

##----------------------------------------------------------##
# Clone ToolChain
function cloneTC() {
	
	if [ $COMPILER = "proton" ];
	then
	git clone --depth=1  https://github.com/kdrag0n/proton-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"
	
	elif [ $COMPILER = "nexus" ];
	then
	git clone --depth=1  https://gitlab.com/Project-Nexus/nexus-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

	elif [ $COMPILER = "hana" ];
	then
	if [ ! -d clang ]; then
	#ln -sf "/home/masaka/code/clang/hana-clang" "${KERNEL_DIR}/clang"
	PATH="${CLANG_DIR}/bin:$PATH"

	elif [ $COMPILER = "neutron" ];
	then
	if [ ! -d clang ]; then
	mkdir clang && cd clang
	bash <(curl -s https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman) -S
	PATH="${KERNEL_DIR}/clang/bin:$PATH"
	cd ..
	fi

	elif [ $COMPILER = "nex14" ];
	then
	git clone --depth=1  https://gitlab.com/Project-Nexus/nexus-clang.git -b nexus-14 clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

	elif [ $COMPILER = "zyc14" ];
    then
    git clone --depth=1 https://github.com/EmanuelCN/zyc_clang-14 clang
    PATH="${KERNEL_DIR}/clang/bin:$PATH"
	
	elif [ $COMPILER = "eva" ];
	then
	git clone --depth=1 https://github.com/mvaisakh/gcc-arm64.git -b gcc-new gcc64
	git clone --depth=1 https://github.com/mvaisakh/gcc-arm.git -b gcc-new gcc32
	PATH=$KERNEL_DIR/gcc64/bin/:$KERNEL_DIR/gcc32/bin/:/usr/bin:$PATH
	
	elif [ $COMPILER = "aosp" ];
	then
	echo "* Checking if Aosp Clang is already cloned..."
	if [ -d clangB ]; then
	  echo "××××××××××××××××××××××××××××"
	  echo "  Already Cloned Aosp Clang"
	  echo "××××××××××××××××××××××××××××"
	else
	export CLANG_VERSION="clang-r475365"
	echo "* It's not cloned, cloning it..."
        mkdir clangB
        cd clangB || exit
	wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/${CLANG_VERSION}.tgz
        tar -xf ${CLANG_VERSION}.tgz
        cd .. || exit
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git  --depth=1 gcc32
	fi
	PATH="${KERNEL_DIR}/clangB/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
	
	elif [ $COMPILER = "zyc" ];
	then
        mkdir clang
        cd clang
		wget https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt
		V="$(cat Clang-main-lastbuild.txt)"
        wget -q https://github.com/ZyCromerZ/Clang/releases/download/16.0.0-$V-release/Clang-16.0.0-$V.tar.gz
	    tar -xf Clang-16.0.0-$V.tar.gz
	    cd ..
	    PATH="${KERNEL_DIR}/clang/bin:$PATH"
	fi
        # Clone AnyKernel
        if [ -d AnyKernel3 ]; then
		  rm -rf AnyKernel3
		elif [ "${DEVICE}" = "alioth" ]; then
          git clone --depth=1 https://github.com/NotZeetaa/AnyKernel3 -b alioth AnyKernel3
        elif [ "${DEVICE}" = "apollo" ]; then
          git clone --depth=1 https://github.com/NotZeetaa/AnyKernel3 -b apollo AnyKernel3
        elif [ "${DEVICE}" = "munch" ]; then
          git clone --depth=1 https://github.com/NotZeetaa/AnyKernel3 -b munch AnyKernel3
		else
		  git clone --depth=1 https://github.com/NotZeetaa/AnyKernel3 -b lmi AnyKernel3
		fi
		fi
}
	
##------------------------------------------------------##
# Export Variables
function exports() {
	
        # Export KBUILD_COMPILER_STRING
        if [ ! -d ${KERNEL_DIR}/clang ];
           then
               export KBUILD_COMPILER_STRING=$(${CLANG_DIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
        elif [ -d ${KERNEL_DIR}/gcc64 ];
           then
               export KBUILD_COMPILER_STRING=$("$KERNEL_DIR/gcc64"/bin/aarch64-elf-gcc --version | head -n 1)
        elif [ -d ${KERNEL_DIR}/clangB ];
            then
               export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clangB/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
        fi
        
        # Export ARCH and SUBARCH
        export ARCH=arm64
        export SUBARCH=arm64
               
        # KBUILD HOST and USER
        export KBUILD_BUILD_HOST=Fedora
        export KBUILD_BUILD_USER="Wee Aris"
        
        # CI
        if [ "$CI" ]
           then
               
           if [ "$CIRCLECI" ]
              then
                  export KBUILD_BUILD_VERSION=${CIRCLE_BUILD_NUM}
                  export CI_BRANCH=${CIRCLE_BRANCH}
           elif [ "$DRONE" ]
	      then
		  export KBUILD_BUILD_VERSION=${DRONE_BUILD_NUMBER}
		  export CI_BRANCH=${DRONE_BRANCH}
           fi
		   
        fi
	export PROCS=$(nproc --all)
	export DISTRO=$(source /etc/os-release && echo "${NAME}")
	}
        

##----------------------------------------------------------##
# Compilation

METHOD=$2

function compile() {
START=$(date +"%s")
	# Push Notification
	#post_msg "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Europe/Lisbon date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>"
	
	# Compile
	if [ ! -d ${KERNEL_DIR}/clang ];
	   then
           make O=out CC=clang ARCH=arm64 ${DEFCONFIG}
		   if [ "$METHOD" = "lto" ]; then
		     scripts/config --file ${OUT_DIR}/.config \
             -e LTO_CLANG
           fi
	       make -kj$(nproc --all) O=out \
	       ARCH=arm64 \
	       LLVM=1 \
	       LLVM_IAS=1 \
	       CROSS_COMPILE=aarch64-linux-gnu- \
	       CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
	       V=$VERBOSE 2>&1 | tee error.log
	elif [ -d ${KERNEL_DIR}/gcc64 ];
	   then
           make O=out ARCH=arm64 ${DEFCONFIG}
	       make -kj$(nproc --all) O=out \
	       ARCH=arm64 \
	       CROSS_COMPILE_COMPAT=arm-eabi- \
	       CROSS_COMPILE=aarch64-elf- \
	       AR=llvm-ar \
	       NM=llvm-nm \
	       OBJCOPY=llvm-objcopy \
	       OBJDUMP=llvm-objdump \
	       STRIP=llvm-strip \
	       OBJSIZE=llvm-size \
	       V=$VERBOSE 2>&1 | tee error.log
        elif [ -d ${KERNEL_DIR}/clangB ];
           then
           make O=out CC=clang ARCH=arm64 ${DEFCONFIG}
		   if [ "$METHOD" = "lto" ]; then
		     scripts/config --file ${OUT_DIR}/.config \
             -e LTO_CLANG
           fi
           make -kj$(nproc --all) O=out \
	       ARCH=arm64 \
	       LLVM=1 \
	       LLVM_IAS=1 \
	       CLANG_TRIPLE=aarch64-linux-gnu- \
	       CROSS_COMPILE=aarch64-linux-android- \
	       CROSS_COMPILE_COMPAT=arm-linux-androideabi- \
	       V=$VERBOSE 2>&1 | tee error.log
	fi
	
	# Verify Files
	if ! [ -a "$IMAGE" ];
	   then
	       #push "error.log" "Build Throws Errors"
	       exit 1
	   else
	       #post_msg " Kernel Compilation Finished. Started Zipping "
		   find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb
		   DTB=$(pwd)/out/arch/arm64/boot/dtb
	fi
	}

##----------------------------------------------------------------##
function zipping() {
	# Copy Files To AnyKernel3 Zip
	mv $IMAGE AnyKernel3
    mv $DTBO AnyKernel3
    mv $DTB AnyKernel3

	# Zipping and Push Kernel
	cd AnyKernel3 || exit 1
        zip -r9 ${FINAL_ZIP} *
        #MD5CHECK=$(md5sum "$FINAL_ZIP" | cut -d' ' -f1)
		md5sum "$FINAL_ZIP" >"$FINAL_ZIP".md5sum
        #push "$FINAL_ZIP" "Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s) | For <b>$MODEL ($DEVICE)</b> | <b>${KBUILD_COMPILER_STRING}</b> | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
		mv ${ZIPNAME}-${VERSION}-${DEVICE}-* ../../image_output
		echo "Zipped Succuss"
		cd ..
        rm -rf AnyKernel3
        }
    
##----------------------------------------------------------##

cloneTC
exports
compile
END=$(date +"%s")
DIFF=$(($END - $START))
zipping

##----------------*****-----------------------------##
