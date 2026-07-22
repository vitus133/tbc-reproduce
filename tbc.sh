#!/bin/bash

##### Constants

export IMAGE_PULL="quay.io/vgrinber/tools:dpll"

export TIME_RECEIVER_NIC="eno8703"
export UPSTREAM_PORT="eno8303"

module="zl3073x"
gnss_1pps_pkg_lab="REF4P"
gnss_10mhz_pkg_lab="REF2N"
ptp_1pps_input_pkg_lab="REF0N"
ptp_1khz_input_pkg_lab="REF0P"

DPLL_COMMAND="sudo podman run --privileged --network=host $IMAGE_PULL dpll"
##### pin ID helper
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
##### Variables
GNSS_1PPS_ID=$(get_pin_id $module $gnss_1pps_pkg_lab)
GNSS_10MHZ_ID=$(get_pin_id $module $gnss_10mhz_pkg_lab)
PTP_1PPS_ID=$(get_pin_id $module $ptp_1pps_input_pkg_lab)
PTP_1KHZ_ID=$(get_pin_id $module $ptp_1khz_input_pkg_lab)
PDID_EEC=$($DPLL_COMMAND device show -j | jq '.device[] | select(."module-name" ==  "zl3073x") |select(.type == "eec") | .id')
PDID_PPS=$($DPLL_COMMAND device show -j | jq '.device[] | select(."module-name" ==  "zl3073x") |select(.type == "pps") | .id')



##### Functions

help () {

        echo "	commands:"
	echo "	inp - shows input pins status"
	echo "	start - starts PTP daemons with configurations specified in the Procfile"
	echo "	stop - stops the daemons"
        echo "	init - initial state"
	echo "	logs - show daemon logs from the last 5 seconds. Add '-f' to continue flushing"
        echo "	up, down - set TR port up or down"
        echo "	lock - try to lock dpll on NIC reference"
        echo "	hold - disable NIC outputs to DPLL"
        echo "	kill - same as stop"
        echo "	showadj - show phase adjustments"
        echo "	adjust - set phase adjustments from file"
	echo "	dev - show the table of devices, types and lock statuses"
}




# inp shows input pins status
inp() {
	 $DPLL_COMMAND pin show -j |jq -r '.pin[] |select(."module-name" == "zl3073x") | select(."parent-device"[0].direction == "input") | "\(.id) | \(."package-label") | \(."parent-device"[0].prio) | \(."parent-device"[0].state) | \(."parent-device"[0].operstate) | \(."parent-device"[1].prio) | \(."parent-device"[1].state) | \(."parent-device"[1].operstate) | \(."board-label")"'| column -s '|' -t
}


# Start
# start() starts PTP daemons with configurations specified in the Procfile
start () {
	 sudo podman run -e IMAGE_PULL=$IMAGE_PULL -d --replace --name ptp-stack   --privileged --network=host   -v "$(pwd)":"/app" -w /app  $IMAGE_PULL bash -c "honcho start"

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
	sudo podman logs $flags  ptp-stack
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

showadj () {
        $DPLL_COMMAND pin show -j | jq -r '.pin[] | select(."module-name" == "zl3073x") | select(."phase-adjust" != 0) | "\(.id) | \(."package-label") | \(."board-label") | \(."phase-adjust")"' | column -s '|' -t
}

adjust () {
        FILE="delays.txt"

        if [[ ! -f "$FILE" ]]; then
                echo "Error: $FILE not found."
                exit 1
        fi

        while read -r pkg_label delay; do
                [[ -z "$pkg_label" || "$pkg_label" == \#* ]] && continue

                id=$(get_pin_id $module "$pkg_label")
                if [[ -z "$id" ]]; then
                        echo "Error: could not find pin ID for package-label $pkg_label"
                        continue
                fi

                echo "Setting $pkg_label (id $id) with a delay of $delay ps..."
                $DPLL_COMMAND pin set id $id phase-adjust -- $delay             

                echo "--------------------------"

        done < "$FILE"
}

# dev show the table of devices, types and lock statuses
dev () {
	 $DPLL_COMMAND device show -j | jq -r 'def tohex: tonumber|floor|if .==0 then "0" else [.,""]|until(.[0]==0; [(.[0]/16|floor), ("0123456789abcdef"[.[0]%16:.[0]%16+1]+.[1])])|.[1] end; .device[] | "0x\(."clock-id"| tohex ) | \(."clock-id") | \(."module-name") | \(.type) | \(."lock-status") | \(.id)"' |column -s '|' -t
}

###### Main
main () {
	echo "EEC device id $PDID_EEC"
	echo "PPS device id $PDID_PPS"
	inp
	echo "--------------"
	showadj
}

main

