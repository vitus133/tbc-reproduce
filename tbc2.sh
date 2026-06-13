#!/bin/bash

##### Constants

export IMAGE_PULL="quay.io/vgrinber/tools:dpll"

export TIME_RECEIVER_NIC="eno1"
export UPSTREAM_PORT="eth7"

module="zl3073x"
gnss_1pps_pkg_lab="REF4P"
ptp_1pps_input_pkg_lab="REF0N"
ptp_1khz_input_pkg_lab="REF0P"

DPLL_COMMAND="sudo podman run --privileged --network=host $IMAGE_PULL dpll"

##### Variables
GNSS_1PPS_ID=$(get_pin_id $module $gnss_1pps_pkg_lab)
PTP_1PPS_ID=$(get_pin_id $module $ptp_1pps_input_pkg_lab)
PTP_1KHZ_ID=$(get_pin_id $module $ptp_1khz_input_pkg_lab)

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

# logs () prints logs from 5s, ooptionally with "-f" if specified
logs () {
	flags=$1
	sudo podman logs --since 5s $flags  ptp-stack
} 

###### Main

echo "GNSS input pin ID is $GNSS_1PPS_ID"
echo "PTP 1PPS input pin ID is $PTP_1PPS_ID"
echo "PTP 1KHz input pin ID is $PTP_1KHZ_ID"
