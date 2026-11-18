#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.


# Create board support packages
#
# Functions:
# create_board_package

create_board_package()
{
	display_alert "Creating board support package" "$BOARD $BRANCH" "info"

	local destination=$SRC/.tmp/${RELEASE}/${CHOSEN_ROOTFS}_${REVISION}_${ARCH}
	rm -rf "${destination}"
	mkdir -p "${destination}"/DEBIAN

	# install copy of boot script & environment file
	local bootscript_src=${BOOTSCRIPT%%:*}
	local bootscript_dst=${BOOTSCRIPT##*:}
	mkdir -p "${destination}"/usr/share/pbsbc01h3/
	cp "${EXTER}/config/bootscripts/${bootscript_src}" "${destination}/usr/share/pbsbc01h3/${bootscript_dst}"
	[[ -n $BOOTENV_FILE && -f ${EXTER}/config/bootenv/$BOOTENV_FILE ]] && \
		cp "${EXTER}/config/bootenv/${BOOTENV_FILE}" "${destination}"/usr/share/pbsbc01h3/pbsbc01h3Env.txt

	# add configuration for setting uboot environment from userspace with: fw_setenv fw_printenv
	if [[ -n $UBOOT_FW_ENV ]]; then
		UBOOT_FW_ENV=($(tr ',' ' ' <<< "$UBOOT_FW_ENV"))
		mkdir -p "${destination}"/etc
		echo "# Device to access      offset           env size" > "${destination}"/etc/fw_env.config
		echo "/dev/mmcblk0	${UBOOT_FW_ENV[0]}	${UBOOT_FW_ENV[1]}" >> "${destination}"/etc/fw_env.config
	fi

	# Replaces: base-files is needed to replace /etc/update-motd.d/ files on Xenial
	# Replaces: unattended-upgrades may be needed to replace /etc/apt/apt.conf.d/50unattended-upgrades
	# (distributions provide good defaults, so this is not needed currently)
	# Depends: linux-base is needed for "linux-version" command in initrd cleanup script
	# Depends: fping is needed for pbsbc01h3monitor to upload pbsbc01h3-hardware-monitor.log
	cat <<-EOF > "${destination}"/DEBIAN/control
	Package: linux-${RELEASE}-root-${DEB_BRANCH}${BOARD}
	Version: $REVISION
	Architecture: $ARCH
	Maintainer: $MAINTAINER <$MAINTAINERMAIL>
	Installed-Size: 1
	Section: kernel
	Priority: optional
	Depends: bash, linux-base, u-boot-tools, initramfs-tools, lsb-release, fping
	Provides: pbsbc01h3-bsp
	Conflicts: pbsbc01h3-bsp
	Suggests: pbsbc01h3-config
	Replaces: zram-config, base-files, pbsbc01h3-tools-$RELEASE
	Recommends: bsdutils, parted, util-linux, toilet
	Description: pbsbc01h3 tweaks for $RELEASE on $BOARD ($BRANCH branch)
	EOF

	# set up pre install script
	cat <<-EOF > "${destination}"/DEBIAN/preinst
	#!/bin/sh

	# tell people to reboot at next login
	[ "\$1" = "upgrade" ] && touch /var/run/.reboot_required

	# convert link to file
	if [ -L "/etc/network/interfaces" ]; then

	    cp /etc/network/interfaces /etc/network/interfaces.tmp
	    rm /etc/network/interfaces
	    mv /etc/network/interfaces.tmp /etc/network/interfaces

	fi

	# fixing ramdisk corruption when using lz4 compression method
	sed -i "s/^COMPRESS=.*/COMPRESS=gzip/" /etc/initramfs-tools/initramfs.conf

	# swap
	if [ -f /etc/sysctl.conf ]; then
	    if grep -q vm.swappiness /etc/sysctl.conf; then
	        sed -i 's/vm\.swappiness.*/vm.swappiness=100/' /etc/sysctl.conf
	    else
	        echo vm.swappiness=100 >>/etc/sysctl.conf
	    fi
	    sysctl -p >/dev/null 2>&1 || true
	elif [ -d /etc/sysctl.d ]; then
	    echo vm.swappiness=100 >/etc/sysctl.d/99-pbsbc01h3-swappiness.conf
	    sysctl --system >/dev/null 2>&1 || true
	fi

	# disable deprecated services
	[ -f "/etc/profile.d/activate_psd_user.sh" ] && rm /etc/profile.d/activate_psd_user.sh
	[ -f "/etc/profile.d/check_first_login.sh" ] && rm /etc/profile.d/check_first_login.sh
	[ -f "/etc/profile.d/check_first_login_reboot.sh" ] && rm /etc/profile.d/check_first_login_reboot.sh
	[ -f "/etc/profile.d/ssh-title.sh" ] && rm /etc/profile.d/ssh-title.sh
	[ -f "/etc/update-motd.d/10-header" ] && rm /etc/update-motd.d/10-header
	[ -f "/etc/update-motd.d/30-sysinfo" ] && rm /etc/update-motd.d/30-sysinfo
	[ -f "/etc/update-motd.d/35-tips" ] && rm /etc/update-motd.d/35-tips
	[ -f "/etc/update-motd.d/40-updates" ] && rm /etc/update-motd.d/40-updates
	[ -f "/etc/update-motd.d/98-autoreboot-warn" ] && rm /etc/update-motd.d/98-autoreboot-warn
	[ -f "/etc/update-motd.d/99-point-to-faq" ] && rm /etc/update-motd.d/99-point-to-faq
	[ -f "/etc/update-motd.d/80-esm" ] && rm /etc/update-motd.d/80-esm
	[ -f "/etc/update-motd.d/80-livepatch" ] && rm /etc/update-motd.d/80-livepatch
	[ -f "/etc/apt/apt.conf.d/50unattended-upgrades" ] && rm /etc/apt/apt.conf.d/50unattended-upgrades
	[ -f "/etc/apt/apt.conf.d/02compress-indexes" ] && rm /etc/apt/apt.conf.d/02compress-indexes
	[ -f "/etc/apt/apt.conf.d/02periodic" ] && rm /etc/apt/apt.conf.d/02periodic
	[ -f "/etc/apt/apt.conf.d/no-languages" ] && rm /etc/apt/apt.conf.d/no-languages
	[ -f "/etc/init.d/armhwinfo" ] && rm /etc/init.d/armhwinfo
	[ -f "/etc/logrotate.d/armhwinfo" ] && rm /etc/logrotate.d/armhwinfo
	[ -f "/etc/init.d/firstrun" ] && rm /etc/init.d/firstrun
	[ -f "/etc/init.d/resize2fs" ] && rm /etc/init.d/resize2fs
	[ -f "/lib/systemd/system/firstrun-config.service" ] && rm /lib/systemd/system/firstrun-config.service
	[ -f "/lib/systemd/system/firstrun.service" ] && rm /lib/systemd/system/firstrun.service
	[ -f "/lib/systemd/system/resize2fs.service" ] && rm /lib/systemd/system/resize2fs.service
	[ -f "/usr/lib/pbsbc01h3/apt-updates" ] && rm /usr/lib/pbsbc01h3/apt-updates
	[ -f "/usr/lib/pbsbc01h3/firstrun-config.sh" ] && rm /usr/lib/pbsbc01h3/firstrun-config.sh
	dpkg-divert --quiet --package linux-${RELEASE}-root-${DEB_BRANCH}${BOARD} --add --rename --divert /etc/mpv/mpv-dist.conf /etc/mpv/mpv.conf
	exit 0
	EOF

	chmod 755 "${destination}"/DEBIAN/preinst

	# postrm script
	cat <<-EOF > "${destination}"/DEBIAN/postrm
	#!/bin/sh
	if [ remove = "\$1" ] || [ abort-install = "\$1" ]; then

	    dpkg-divert --quiet --package linux-${RELEASE}-root-${DEB_BRANCH}${BOARD} --remove --rename	--divert /etc/mpv/mpv-dist.conf /etc/mpv/mpv.conf
	    systemctl disable pbsbc01h3-hardware-monitor.service pbsbc01h3-hardware-optimize.service >/dev/null 2>&1
	    systemctl disable pbsbc01h3-zram-config.service pbsbc01h3-ramlog.service >/dev/null 2>&1

	fi
	exit 0
	EOF

	chmod 755 "${destination}"/DEBIAN/postrm

	# set up post install script
	cat <<-EOF > "${destination}"/DEBIAN/postinst
	#!/bin/sh
	#
	# ${BOARD} BSP post installation script
	#

	systemctl --no-reload enable pbsbc01h3-ramlog.service

	# check if it was disabled in config and disable in new service
	if [ -n "\$(grep -w '^ENABLED=false' /etc/default/log2ram 2> /dev/null)" ]; then

	     sed -i "s/^ENABLED=.*/ENABLED=false/" /etc/default/pbsbc01h3-ramlog

	fi

	# fix boot delay "waiting for suspend/resume device"
	if [ -f "/etc/initramfs-tools/initramfs.conf" ]; then

	    if ! grep --quiet "RESUME=none" /etc/initramfs-tools/initramfs.conf; then
	         echo "RESUME=none" >> /etc/initramfs-tools/initramfs.conf
	    fi

	fi

	EOF

	if [[ $RELEASE == bionic && $BOARD != pbsbc01h34 ]] || [[ $RELEASE == focal && $BOARDFAMILY == sun50iw6 ]] || [[ ( $RELEASE == bookworm ) && $BOARDFAMILY == sun8i ]]; then
		cat <<-EOF >> "${destination}"/DEBIAN/postinst
		# disable glamor 3D acceleration probe on sun8i boards without 3D GPU driver
		mkdir -p /etc/X11/xorg.conf.d
		echo 'Section "OutputClass"
		\tIdentifier \t"sunxi-drm-no-glamor"
		\tMatchDriver \t"sun4i-drm|vkms"
		\tDriver \t\t"modesetting"
		\tOption \t\t"AccelMethod" "none"
		EndSection' >> /etc/X11/xorg.conf.d/01-pbsbc01h3-defaults.conf
		EOF
	elif [[ $RELEASE == bionic && $BOARD == pbsbc01h34 ]]; then
		cat <<-EOF >> "${destination}"/DEBIAN/postinst
		# temporally disable acceleration on some arch in Bionic due to broken mesa packages
		echo 'Section "Device"
		\tIdentifier \t"Default Device"
		\tOption \t"AccelMethod" "glamor"
		EndSection' >> /etc/X11/xorg.conf.d/01-pbsbc01h3-defaults.conf
		EOF
	fi

	# install bootscripts if they are not present. Fix upgrades from old images
	if [[ $FORCE_BOOTSCRIPT_UPDATE == yes ]]; then
	    cat <<-EOF >> "${destination}"/DEBIAN/postinst
	if [ true ]; then

    # this package recreate boot scripts
	EOF
	else
	    cat <<-EOF >> "${destination}"/DEBIAN/postinst
	if [ ! -f /boot/$bootscript_dst ]; then

	# if boot script does not exits its recreated
	EOF
	fi
	cat <<-EOF >> "${destination}"/DEBIAN/postinst
    # move bootscript to /usr/share/pbsbc01h3
    # create a backup
    [ -f /etc/pbsbc01h3-release ] &&  . /etc/pbsbc01h3-release
    [ -z \${VERSION} ] && VERSION=$(echo \`date +%s\`)
    if [ -f /boot/$bootscript_dst ]; then
       cp /boot/$bootscript_dst /usr/share/pbsbc01h3/${bootscript_dst}-\${VERSION} >/dev/null 2>&1
       echo "NOTE: You can find previous bootscript versions in /usr/share/pbsbc01h3 !"
    fi

    # cleanup old bootscript backup
    ls /usr/share/pbsbc01h3/boot.cmd-* >/dev/null 2>&1 | head -n -5 | xargs rm -f --
    ls /usr/share/pbsbc01h3/boot.ini-* >/dev/null 2>&1 | head -n -5 | xargs rm -f --

    echo "Recreating boot script"
    cp /usr/share/pbsbc01h3/$bootscript_dst /boot  >/dev/null 2>&1
    rootdev=\$(sed -e 's/^.*root=//' -e 's/ .*\$//' < /proc/cmdline)
    rootfstype=\$(sed -e 's/^.*rootfstype=//' -e 's/ .*$//' < /proc/cmdline)

    # recreate pbsbc01h3Env.txt only not exists
    if [ ! -f /boot/pbsbc01h3Env.txt ]; then
      cp /usr/share/pbsbc01h3/pbsbc01h3Env.txt /boot/  >/dev/null 2>&1
      echo "rootdev="\$rootdev >> /boot/pbsbc01h3Env.txt
      echo "rootfstype="\$rootfstype >> /boot/pbsbc01h3Env.txt
    fi

    [ -f /boot/boot.ini ] && sed -i "s/setenv rootdev.*/setenv rootdev \\"\$rootdev\\"/" /boot/boot.ini
    [ -f /boot/boot.ini ] && sed -i "s/setenv rootfstype.*/setenv rootfstype \\"\$rootfstype\\"/" /boot/boot.ini
    [ -f /boot/boot.cmd ] && mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr  >/dev/null 2>&1

	fi

	[ ! -f "/etc/network/interfaces" ] && cp /etc/network/interfaces.default /etc/network/interfaces
	ln -sf /var/run/motd /etc/motd
	rm -f /etc/update-motd.d/00-header /etc/update-motd.d/10-help-text
	if [ -f "/boot/bin/$BOARD.bin" ] && [ ! -f "/boot/script.bin" ]; then ln -sf bin/$BOARD.bin /boot/script.bin >/dev/null 2>&1 || cp /boot/bin/$BOARD.bin /boot/script.bin; fi
	if [ ! -f "/etc/default/pbsbc01h3-motd" ]; then
		mv /etc/default/pbsbc01h3-motd.dpkg-dist /etc/default/pbsbc01h3-motd
	fi
	if [ ! -f "/etc/default/pbsbc01h3-ramlog" ]; then
		mv /etc/default/pbsbc01h3-ramlog.dpkg-dist /etc/default/pbsbc01h3-ramlog
	fi
	if [ ! -f "/etc/default/pbsbc01h3-zram-config" ]; then
		mv /etc/default/pbsbc01h3-zram-config.dpkg-dist /etc/default/pbsbc01h3-zram-config
	fi

	if [ -L "/usr/lib/chromium-browser/master_preferences.dpkg-dist" ]; then
		mv /usr/lib/chromium-browser/master_preferences.dpkg-dist /usr/lib/chromium-browser/master_preferences
	fi

	systemctl --no-reload enable pbsbc01h3-hardware-monitor.service pbsbc01h3-hardware-optimize.service pbsbc01h3-zram-config.service >/dev/null 2>&1
	exit 0
	EOF

	chmod 755 "${destination}"/DEBIAN/postinst

	# won't recreate files if they were removed by user
	# TODO: Add proper handling for updated conffiles
	#cat <<-EOF > "${destination}"/DEBIAN/conffiles
	#EOF

	# copy common files from a premade directory structure
	rsync -a "${EXTER}"/packages/bsp/common/* "${destination}"/

	# trigger uInitrd creation after installation, to apply
	# /etc/initramfs/post-update.d/99-uboot
	cat <<-EOF > "${destination}"/DEBIAN/triggers
	activate update-initramfs
	EOF

	# armhwinfo, firstrun, pbsbc01h3monitor, etc. config file
	cat <<-EOF > "${destination}"/etc/pbsbc01h3-release
	# PLEASE DO NOT EDIT THIS FILE
	BOARD=${BOARD}
	BOARD_NAME="$BOARD_NAME"
	BOARDFAMILY=${BOARDFAMILY}
	BUILD_REPOSITORY_URL=${BUILD_REPOSITORY_URL}
	BUILD_REPOSITORY_COMMIT=${BUILD_REPOSITORY_COMMIT}
	DISTRIBUTION_CODENAME=${RELEASE}
	VERSION=${REVISION}
	LINUXFAMILY=${LINUXFAMILY}
	BRANCH=${BRANCH}
	ARCH=${ARCHITECTURE}
	IMAGE_TYPE=$IMAGE_TYPE
	BOARD_TYPE=$BOARD_TYPE
	INITRD_ARCH=${INITRD_ARCH}
	KERNEL_IMAGE_TYPE=${KERNEL_IMAGE_TYPE}
	EOF

	# this is required for NFS boot to prevent deconfiguring the network on shutdown
	sed -i 's/#no-auto-down/no-auto-down/g' "${destination}"/etc/network/interfaces.default

	if [[ ( $LINUXFAMILY == sun8i ) && $BRANCH == legacy ]]; then
		# add mpv config for vdpau_sunxi
		mkdir -p "${destination}"/etc/mpv/
		cp "${EXTER}"/packages/bsp/mpv/mpv_sunxi.conf "${destination}"/etc/mpv/mpv.conf
		echo "export VDPAU_OSD=1" > "${destination}"/etc/profile.d/90-vdpau.sh
		chmod 755 "${destination}"/etc/profile.d/90-vdpau.sh
	fi
	if [[ $LINUXFAMILY == sunxi* ]]; then
		# add mpv config for x11 output - slow, but it works compared to no config at all
		# TODO: Test which output driver is better with DRM
		mkdir -p "${destination}"/etc/mpv/
		cp "${EXTER}"/packages/bsp/mpv/mpv_mainline.conf "${destination}"/etc/mpv/mpv.conf
	fi

	case $RELEASE in
	xenial)
		if [[ $BRANCH == legacy && $LINUXFAMILY == sun8i ]]; then
			# this is required only for old kernels
			# not needed for Stretch since there will be no Stretch images with kernels < 4.4
			mkdir -p "${destination}"/lib/systemd/system/haveged.service.d/
			cp "${EXTER}"/packages/bsp/10-no-new-privileges.conf "${destination}"/lib/systemd/system/haveged.service.d/
		fi
	;;
	esac
	# execute $LINUXFAMILY-specific tweaks
	[[ $(type -t family_tweaks_bsp) == function ]] && family_tweaks_bsp

	# add some summary to the image
	fingerprint_image "${destination}/etc/pbsbc01h3.txt"

	# fixing permissions (basic), reference: dh_fixperms
	find "${destination}" -print0 2>/dev/null | xargs -0r chown --no-dereference 0:0
	find "${destination}" ! -type l -print0 2>/dev/null | xargs -0r chmod 'go=rX,u+rw,a-s'
	[[ -d "${destination}/etc/NetworkManager/dispatcher.d" ]] && chmod 755 "${destination}"/etc/NetworkManager/dispatcher.d/*

	# create board DEB file
	display_alert "Building package" "$CHOSEN_ROOTFS" "info"
	fakeroot dpkg-deb -b "${destination}" "${destination}.deb" >> "${DEST}"/debug/install.log 2>&1
	mkdir -p "${DEB_STORAGE}/${RELEASE}/"
	mv "${destination}.deb" "${DEB_STORAGE}/${RELEASE}/"
	# cleanup
	rm -rf "${destination}"
}
