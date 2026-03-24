#!/bin/bash

# NIC data
# id	label		eec	dir		pr	state			pps	dir		pr	state
##--------------------------------------------------------------------------------------------------------------------------------
# ens4f0 0x507c6fffff1fb218
# 21	CVL-SDP22	2	input	8	selectable	3	input	8	selectable
# 22	CVL-SDP20	2	input	255	selectable	3	input	3	selectable
# 27	GNSS-1PPS	2	input	0	connected	3	input	0	connected
# 32	CVL-SDP21	2	output	0	disconnected	3	output	0	connected
# 33	CVL-SDP23	2	output	0	disconnected	3	output	0	connected
# 34	SMA1	2	input	1	selectable	3	input	1	selectable
# 35	SMA2	2	input	2	selectable	3	input	2	selectable


# ens5f0 0x507c6fffff0ac7be
# 0		CVL-SDP22	0	input	8	selectable		1	input	8	selectable
# 1		CVL-SDP20	0	input	255	selectable		1	input	3	selectable
# 6		GNSS-1PPS	0	input	0	selectable		1	input	0	selectable
# 11	CVL-SDP21	0	output	0	disconnected	1	output	0	connected
# 12	CVL-SDP23	0	output	0	disconnected	1	output	0	connected
# 13	SMA1		0	input	1	selectable		1	input	1	selectable
# 14	SMA2		0	input	2	selectable		1	input	2	selectable

# ens8f0 0x507c6fffff0ac7e0
# 46	CVL-SDP22	6	input	8	selectable		7	input	8	selectable
# 47	CVL-SDP20	6	input	255	selectable		7	input	3	selectable
# 52	GNSS-1PPS	6	input	0	selectable		7	input	0	selectable
# 57	CVL-SDP21	6	output	0	disconnected	7	output	0	connected
# 58	CVL-SDP23	6	output	0	disconnected	7	output	0	connected
# 59	SMA1		6	input	1	selectable		7	input	1	selectable
# 60	SMA2		6	input	2	selectable		7	input	2	selectable


TIME_RECEIVER_NIC="${TIME_RECEIVER_NIC:-ens4f0}"
UPSTREAM_PORT="${UPSTREAM_PORT:-ens4f0}"

# Time receiver NIC pin IDs
GNSS_ID=27
SDP23_ID=33
SDP22_ID=21
SDP21_ID=32
SDP20_ID=22
SMA1_ID=34
SMA2_ID=35

# Time receiver NIC pin parent IDs
PPID_EEC=2
PPID_PPS=3

# Functions
set_pin_direction () {
	id=$1
	parent=$2
	direction=$3
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll dpll pin set id $id parent-device $parent direction $direction"
	eval $CMD
	rv=$?
	if [ $rv -ne 0 ]; then
		echo "Error sending command $CMD"
	fi
}
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
	echo "lock - try to lock dpll on NIC reference"
	echo "hold - disable NIC outputs to DPLL"
	echo "kill - kill running daemons"
	# echo "showphaseadj - show phase adjustments"
	# echo "adjust - set phase adjustments from file"
}

init () {
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP22"
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP20"

	# Disable GNSS of all NICs
	set_pin_state $GNSS_ID $PPID_EEC disconnected
	set_pin_state $GNSS_ID $PPID_PPS disconnected
	set_pin_state 6 0 disconnected
	set_pin_state 6 1 disconnected
	set_pin_state 52 6 disconnected
	set_pin_state 52 7 disconnected

	# Enable SMA1 and SMA2 outputs on the leading NIC
	# this will set both output
	set_pin_direction $SMA1_ID $PPID_PPS output
	set_pin_state $SMA1_ID $PPID_PPS connected
	set_pin_direction $SMA2_ID $PPID_PPS output
	set_pin_state $SMA2_ID $PPID_PPS connected

	# Disable SDP20 / 21 as we don't use them
	set_pin_state $SDP20_ID $PPID_EEC disconnected
	set_pin_state $SDP20_ID $PPID_PPS disconnected
	set_pin_state $SDP21_ID $PPID_EEC disconnected
	set_pin_state $SDP21_ID $PPID_PPS disconnected

	# Disable SDP23 EEC / 22 (init)
	set_pin_state $SDP22_ID $PPID_EEC disconnected
	set_pin_state $SDP22_ID $PPID_PPS disconnected
	set_pin_state $SDP23_ID $PPID_EEC disconnected
    # Leave SDP23 PPS enabled for timestamps
	set_pin_state $SDP23_ID $PPID_PPS connected

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
	set_pin_state $SDP22_ID $PPID_PPS selectable
}

kill () {
	sudo pkill ptp4l ; sudo pkill ts2phc; sudo pkill phc2sys
}

hold () {
	# Disable SDP22
	set_pin_state $SDP22_ID $PPID_PPS disconnected
}

