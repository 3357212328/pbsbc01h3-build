#!/bin/bash

BOARD=$(cat /etc/hostname)

if [ ${BOARD} = "pbsbc01h34" ];then
	DEV="/dev/video0"
elif [ ${BOARD} = "pbsbc01h3rk3399" ]; then
	DEV="/dev/video5"
fi

export DISPLAY=:0.0
su pbsbc01h3 -c "gst-launch-1.0 rkisp device=${DEV} io-mode=1 analyzer=1 enable-3a=1 path-iqf=/etc/cam_iq.xml \
	! video/x-raw,format=NV12,width=1280,height=720, framerate=30/1 ! videoconvert ! autovideosink"
