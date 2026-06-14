#!/bin/bash

##### Constants

export IMAGE_PULL="quay.io/vgrinber/tools:dpll"

export TIME_RECEIVER_NIC="eno1"
export UPSTREAM_PORT="eth7"

module="zl3073x"
gnss_1pps_pkg_lab="REF4P"
gnss_10mhz_pkg_lab="REF2N"
ptp_1pps_input_pkg_lab="REF0N"
ptp_1khz_input_pkg_lab="REF0P"

DPLL_COMMAND="sudo podman run --privileged --network=host $IMAGE_PULL dpll"

##### Variables
GNSS_1PPS_ID=$(get_pin_id $module $gnss_1pps_pkg_lab)
GNSS_10MHZ_ID=$(get_pin_id $module $gnss_10mhz_pkg_lab)
PTP_1PPS_ID=$(get_pin_id $module $ptp_1pps_input_pkg_lab)
PTP_1KHZ_ID=$(get_pin_id $module $ptp_1khz_input_pkg_lab)
PDID_EEC=$($DPLL_COMMAND device show -j | jq '.device[] | select(."module-name" ==  "zl3073x") |select(.type == "eec") | .id')
PDID_PPS=$($DPLL_COMMAND device show -j | jq '.device[] | select(."module-name" ==  "zl3073x") |select(.type == "pps") | .id')



##### Functions
# get_pin_id gets pin ID by module and package label
get_pin_id () {
	module=$1
	pl=$2
	str="export module=$module && export pl=$pl && \
$DPLL_COMMAND pin show -j | jq '.pin[] | select(.\"module-name\" == env.module) | select(.\"package-label\" == env.pl) | .id'"
	eval $str
	rc=$?
	return $rc
}

# inp shows input pins status
inp() {
	 $DPLL_COMMAND pin show -j |jq -r '.pin[] |select(."module-name" == "zl3073x") | select(."parent-device"[0].direction == "input") | "\(.id)\t\(."package-label")\t\(."parent-device"[0].prio)\t\(."parent-device"[0].state)\t\(."parent-device"[0].operstate)\t\(."parent-device"[1].prio)\t\(."parent-device"[1].state)\t\(."parent-device"[1].operstate)\t\(."board-label")"'
}


# Start
# start() starts PTP daemons with configurations specified in the Procfile
start () {
	 sudo podman run -e IMAGE_PULL=$IMAGE_PULL -d --replace --name ptp-stack   --privileged --network=host   -v "$(pwd)":"/app" -w /app  $IMAGE_PULL bash -c "pip install honcho && honcho start"

}

# stop () stops the daemons
stop () {
	 sudo podman stop ptp-stack
}

# kill () - same as stop
kill () {
	stop
}

# logs () prints logs from 5s, ooptionally with "-f" if specified
logs () {
	flags=$1
	sudo podman logs --since 5s $flags  ptp-stack
} 

# disable_pd disables source specified by the Parent device ID for the input specified by ID
# usage: disable_pd {ID} {PDID}
disable_pd() {
	id=$1
	pdid=$2
	$DPLL_COMMAND pin set id $id parent-device $pdid state disconnected 
}

# enable_pd enables source specified by the Parent device ID for the input specified by ID
# usage: enable_pd {ID} {PDID}
enable_pd() {
	id=$1
	pdid=$2
	$DPLL_COMMAND pin set id $id parent-device $pdid state selectable
}

init () {
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP0"
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP2"
        disable_pd $GNSS_1PPS_ID $PDID_EEC
        disable_pd $GNSS_1PPS_ID $PDID_PPS
        disable_pd $GNSS_10MHZ_ID $PDID_EEC
        disable_pd $GNSS_10MHZ_ID $PDID_PPS
        disable_pd $PTP_1PPS_ID $PDID_EEC
        disable_pd $PTP_1PPS_ID $PDID_PPS
        disable_pd $PTP_1KHZ_ID $PDID_EEC
        disable_pd $PTP_1KHZ_ID $PDID_PPS

}

up (){
	sudo ip link set $UPSTREAM_PORT up
}

down (){
	sudo ip link set $UPSTREAM_PORT down
}

lock () {
        enable_pd $PTP_1PPS_ID $PDID_PPS
        enable_pd $PTP_1KHZ_ID $PDID_PPS
	sudo bash -c "echo 2 2 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP2"
	sudo bash -c "echo 2 1 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP0"
	sudo bash -c "echo 1 0 0 1 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/period"
	sudo bash -c "echo 2 0 0 0 1000000 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/period"
}

kill () {
	 parent=$(ps -o pgid= -p $(ps -ef |grep ptp4l |grep bash | awk '{print $2}') |awk '{print $1}')
         sudo kill -9 -$parent
}

hold () {
        sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP0"
        sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP2"
}




###### Main

echo "GNSS input pin ID is $GNSS_1PPS_ID"
echo "PTP 1PPS input pin ID is $PTP_1PPS_ID"
echo "PTP 1KHz input pin ID is $PTP_1KHZ_ID"
echo "EEC device id $PPID_EEC"
inp
