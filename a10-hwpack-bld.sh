#!/bin/sh
#
# Build script for A10 hardware pack
# a10-hwpack-bld.sh product_name

blddate=`date +%Y.%m.%d`
cross_compiler=arm-linux-gnueabihf-
board=$1

#******************************************************************************
#
# try: Execute a command with error checking.  Note that when using this, if a piped
# command is used, the '|' must be escaped with '\' when calling try (i.e.
# "try ls \| less").
#
#******************************************************************************
try ()
{
    #
    # Execute the command and fail if it does not return zero.
    #
    eval ${*} || failure
}

#******************************************************************************
#
# failure: Bail out because of an error.
#
#******************************************************************************
failure ()
{
    #
    # Indicate that an error occurred.
    #
    echo Build step failed!

    #
    # Exit with a failure return code.
    #
    exit 1
}

if [ -z $1 ]; then
    echo "Usage: ./a10-hwpack-bld.sh product_name"
    echo ""
    echo "Products currently supported: mele-a1000 and mele-a1000-vga"
    exit 1
fi

try mkdir -p bld_a10_hwpack_${blddate}
try pushd bld_a10_hwpack_${blddate}

make_log=`pwd`/${board}_${blddate}.log
echo "Build hwpack for ${board} - ${blddate}" > ${make_log}

try mkdir -p ${board}_hwpack/bootloader
try mkdir -p ${board}_hwpack/kernel
try mkdir -p ${board}_hwpack/rootfs

# Generate script.bin
if [ ! -f .script.${board} ]
then
    echo "Checking out config files"
    if [ ! -d a10-config ]; then
        try git clone git://github.com/cnxsoft/a10-config.git >> ${make_log}
    fi
    try pushd a10-config/script.fex >> ${make_log} 2>&1
    echo "Generating ${board}.bin file"
    # cnxsoft: can't use try with fex2bin (wrong exit code)
    fex2bin ${board}.fex > ${board}.bin
    popd >> ${make_log} 2>&1
    touch .script.${board}
fi

if [ ! -f .uboot-allwinner ]
then
    # Build u-boot
    echo "Checking out u-boot source code"
    if [ ! -d uboot-allwinner ]; then
        try git clone https://github.com/hno/uboot-allwinner.git --depth=1 >> ${make_log}
    fi
    try pushd uboot-allwinner >> ${make_log} 2>&1
    echo "Building u-boot"
    try make sun4i CROSS_COMPILE=${cross_compiler} -j2 >> ${make_log} 2>&1
    popd >> ${make_log} 2>&1
    touch .uboot-allwinner
fi

# Build the linux kernel
if [ ! -f .linux-allwinner ]
then
    echo "Checking out linux source code `pwd`"
    if [ ! -d linux-allwinner.git ]; then
        try git clone git://github.com/amery/linux-allwinner.git --depth=1 >> ${make_log}
    fi
    try pushd linux-allwinner >> ${make_log} 2>&1
    try git checkout allwinner-v3.0-android-v2 >> ${make_log} 2>&1
    echo "Building linux"
    # cnxsoft: do we need a separate config per device ?
    try make ARCH=arm sun4i_defconfig >> ${make_log} 2>&1
    try make ARCH=arm oldconfig >> ${make_log} 2>&1
    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j2 uImage >> ${make_log} 2>&1
    echo "Building the kernel modules"
    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j2 INSTALL_MOD_PATH=output modules >> ${make_log} 2>&1
    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j2 INSTALL_MOD_PATH=output modules_install >> ${make_log} 2>&1
    popd >> ${make_log} 2>&1
    touch .linux-allwinner
fi

# Get binary files
echo "Checking out binary files"
if [ ! -d a10-bin ]; then
    try git clone git://github.com/cnxsoft/a10-bin.git >> ${make_log} 2>&1
fi

# Copy files in hwpack directory
echo "Copy files to hardware pack directory"
try cp linux-allwinner/output/lib ${board}_hwpack/rootfs -rf >> ${make_log} 2>&1
try cp a10-bin/armel/* ${board}_hwpack/rootfs -rf >> ${make_log} 2>&1
# Only support Debian/Ubuntu for now
try cp a10-config/rootfs/debian-ubuntu/* ${board}_hwpack/rootfs -rf >> ${make_log} 2>&1
try mkdir -p ${board}_hwpack/rootfs/a10-bin-backup >> ${make_log} 2>&1
try cp a10-bin/armel/* ${board}_hwpack/rootfs/a10-bin-backup -rf >> ${make_log} 2>&1
try cp linux-allwinner/arch/arm/boot/uImage ${board}_hwpack/kernel >> ${make_log} 2>&1
try cp a10-config/script.fex/${board}.bin ${board}_hwpack/kernel >> ${make_log} 2>&1
try cp uboot-allwinner/spl/sun4i-spl.bin ${board}_hwpack/bootloader >> ${make_log} 2>&1
try cp uboot-allwinner/u-boot.bin ${board}_hwpack/bootloader >> ${make_log} 2>&1

# Compress the hwpack files
echo "Compress hardware pack file"
try pushd ${board}_hwpack >> ${make_log} 2>&1
try 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../${board}_hwpack_${blddate}.7z . >> ${make_log} 2>&1
popd >> ${make_log} 2>&1
popd >> ${make_log} 2>&1
echo "Build completed - ${board} hardware pack: ${board}_hwpack_${blddate}.7z" >> ${make_log} 2>&1
echo "Build completed - ${board} hardware pack: ${board}_hwpack_${blddate}.7z"
