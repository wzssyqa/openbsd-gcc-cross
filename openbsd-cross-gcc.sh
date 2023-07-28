#!/bin/sh

TOPDIR=`pwd`
SPATH=${PATH}

function download_rootfs() {
	mkdir -p loongson.archive
	[ -e "loongson.archive/base73.tgz" ] || wget https://cdn.openbsd.org/pub/OpenBSD/7.3/loongson/base73.tgz -O loongson.archive/base73.tgz
	[ -e "loongson.archive/comp73.tgz" ] || wget https://cdn.openbsd.org/pub/OpenBSD/7.3/loongson/comp73.tgz -O loongson.archive/comp73.tgz
	mkdir -p octeon.archive
	[ -e "octeon.archive/base73.tgz" ] || wget https://cdn.openbsd.org/pub/OpenBSD/7.3/octeon/base73.tgz -O octeon.archive/base73.tgz
	[ -e "octeon.archive/comp73.tgz" ] || wget https://cdn.openbsd.org/pub/OpenBSD/7.3/octeon/comp73.tgz -O octeon.archive/comp73.tgz
}

function unarchive_rootfs() {
	sudo rm -rf loongson.rootfs && mkdir -p loongson.rootfs
	tar --directory=loongson.rootfs -xf loongson.archive/base73.tgz
	tar --directory=loongson.rootfs -xf loongson.archive/comp73.tgz
	sudo rm -rf octeon.rootfs && mkdir -p octeon.rootfs
	tar --directory=octeon.rootfs -xf octeon.archive/base73.tgz
	tar --directory=octeon.rootfs -xf octeon.archive/comp73.tgz
}

function get_binutils() {
	if [ ! -d "binutils-gdb/.git" ];then
		rm -rf binutils-gdb
		git clone git://sourceware.org/git/binutils-gdb.git
	else
		git -C binutils-gdb checkout .
		git -C binutils-gdb clean -fd
		git -C binutils-gdb pull
	fi
}

function build_binutils() {
	rm -rf ${TOPDIR}/loongson.cross ${TOPDIR}/octeon.cross
	rm -rf binutils-gdb/build-openbsd-*
	mkdir -p binutils-gdb/build-openbsd-loongson && cd binutils-gdb/build-openbsd-loongson
	../configure --target=mips64el-openbsd --prefix=${TOPDIR}/loongson.cross --disable-sim --disable-gdb
	make -j`nproc`
	make install
	cd ${TOPDIR}
	mkdir -p binutils-gdb/build-openbsd-octeon && cd binutils-gdb/build-openbsd-octeon
	../configure --target=mips64-openbsd --prefix=${TOPDIR}/octeon.cross/ --disable-sim --disable-gdb
	make -j`nproc`
	make install
	cd ${TOPDIR}
}

function get_gcc() {
	if [ ! -d "gcc/.git" ];then
		rm -rf gcc
		git clone git://gcc.gnu.org/git/gcc.git
	else
		git -C gcc checkout .
		git -C gcc clean -fd
		git -C gcc pull
	fi
	patch --directory=gcc -p1 < patches/gcc-openbsd.diff
}

function build_gcc() {
	rm -rf gcc/build-openbsd-*
 
	export PATH="${SPATH}:${TOPDIR}/loongson.rootfs/bin"
	mkdir -p gcc/build-openbsd-loongson && cd gcc/build-openbsd-loongson
	../configure --target=mips64el-openbsd --enable-languages=c,c++ --with-sysroot=${TOPDIR}/loongson.rootfs --prefix=${TOPDIR}/loongson.cross
	make -j`nproc`
	make install
	cd ${TOPDIR}
 
	export PATH="${SPATH}:${TOPDIR}/octeon.rootfs/bin"
	mkdir -p gcc/build-openbsd-octeon && cd gcc/build-openbsd-octeon
	../configure --target=mips64-openbsd --enable-languages=c,c++ --with-sysroot=${TOPDIR}/octeon.rootfs --prefix=${TOPDIR}/octeon.cross
	make -j`nproc`
	make install
	cd ${TOPDIR}
 
	export PATH="${SPATH}"
	echo "You can use the mips64(el)-openbsd-gcc now by"
	echo "   export PATH=\$PATH:${TOPDIR}/octeon.rootfs/bin"
	echo "or"
	echo "   export PATH=\$PATH:${TOPDIR}/loongson.rootfs/bin"
}

download_rootfs
unarchive_rootfs
get_binutils
build_binutils
get_gcc
build_gcc
