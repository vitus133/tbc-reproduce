#!/bin/bash

# NIC data
##--------------------------------------------------------------------------------------------------------------------------------
# ens4f0 0x507c6fffff1fb218
# ens5f0 0x507c6fffff0ac7be
# ens8f0 0x507c6fffff0ac7e0


TIME_RECEIVER_NIC=ens4f0
UPSTREAM_PORT=ens4f0

# Time receiver NIC pin IDs
GNSS_ID=29
SDP23_ID=37
SDP22_ID=23
SDP21_ID=36
SDP20_ID=24

# Time receiver NIC pin parent IDs
PPID_EEC=3
PPID_PPS=4

set_pin_state () {
	id=$1
	parent=$2
	state=$3
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll dpll pin set id $id parent-device $parent state $state"
	eval $CMD
	rv=$?
	if [ $rv -ne 0 ]; then
		echo "Error sending command $CMD"
	fi
}
help () {

	echo "commands:"
	echo "init - initial state"
	echo "up, down - set TR port up or down"
	echo "lock - lock the DPLL on the NIC reference"
	echo "hold - disable NIC outputs to DPLL, enable DPLL to NIC"
	echo "kill - kill running daemons"
}

init () {
	# Zero SDP inputs
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP22"
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP20"
	# Disable GNSS of the TR NIC
	set_pin_state $GNSS_ID $PPID_EEC disconnected
	set_pin_state $GNSS_ID $PPID_PPS disconnected

	# Disable SDP20 / 21 as we don't use them
	set_pin_state $SDP20_ID $PPID_EEC disconnected
	set_pin_state $SDP20_ID $PPID_PPS disconnected
	set_pin_state $SDP21_ID $PPID_EEC disconnected
	set_pin_state $SDP21_ID $PPID_PPS disconnected

	# Disable SDP23 / 22 (init)
	set_pin_state $SDP22_ID $PPID_EEC disconnected
	set_pin_state $SDP22_ID $PPID_PPS disconnected
	set_pin_state $SDP23_ID $PPID_EEC disconnected
        # Leave SDP23 enabled for timestamps
	set_pin_state $SDP23_ID $PPID_PPS connected

	# Enable SDP22 PHC pulse 
	sudo bash -c "echo 2 2 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP22"
	sudo bash -c "echo 2 0 0 1 0 >  /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/period"
}

up (){
	sudo ip link set $UPSTREAM_PORT up
}

down (){
	sudo ip link set $UPSTREAM_PORT down
}

lock () {
	# enable SDP22
	# set_pin_state $SDP23_ID $PPID_PPS disconnected
	set_pin_state $SDP22_ID $PPID_PPS selectable
}

kill () {
	sudo pkill ptp4l; sudo pkill ts2phc; sudo pkill phc2sys
}

hold () {
	# Disable SDP22
	set_pin_state $SDP22_ID $PPID_PPS disconnected
	# set_pin_state $SDP23_ID $PPID_PPS connected

}

