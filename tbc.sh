#!/bin/bash

# NIC data
## Default pins state
## Id   Board Label	Parent eec	Direction eec	Prio	State			Parent pps	Direction pps	Prio	State
##--------------------------------------------------------------------------------------------------------------------------------
# ens4f0 0x507c6fffff1fb218
## 21	CVL-SDP22	2			input			255		selectable		3		input		5	selectable
## 22	CVL-SDP20	2			input			255		selectable		3		input		4	selectable
## 27	GNSS-1PPS	2			input			0		connected		3		input		0	connected
## 32	CVL-SDP21	2			output			0		disconnected	3		output		0	connected
## 33	CVL-SDP23	2			output			0		disconnected	3		output		0	connected
## 34	SMA1		2			input			3		selectable		3		input		3	selectable
## 35	SMA2		2			input			2		selectable		3		input		2	selectable
# ens5f0 0x507c6fffff0ac7be
## 0	CVL-SDP22	0			input			255		selectable		1		input		5	selectable
## 1	CVL-SDP20	0			input			255		selectable		1		input		4	selectable
## 6	GNSS-1PPS	0			input			0		selectable		1		input		0	selectable
## 11	CVL-SDP21	0			output			0		disconnected	1		output		0	connected
## 12	CVL-SDP23	0			output			0		disconnected	1		output		0	connected
## 13	SMA1		0			input			3		selectable		1		input		3	selectable
## 14	SMA2		0			input			2		selectable		1		input		2	selectable
# ens8f0 0x507c6fffff0ac7e0
## 46	CVL-SDP22	6			input			255		selectable		7		input		5	selectable
## 47	CVL-SDP20	6			input			255		selectable		7		input		4	selectable
## 52	GNSS-1PPS	6			input			0		selectable		7		input		0	selectable
## 57	CVL-SDP21	6			output			0		disconnected	7		output		0	connected
## 58	CVL-SDP23	6			output			0		disconnected	7		output		0	connected
## 59	SMA1		6			input			3		selectable		7		input		3	selectable
## 60	SMA2		6			input			2		selectable		7		input		2	selectable


TIME_RECEIVER_NIC="${TIME_RECEIVER_NIC:-ens4f0}"
UPSTREAM_PORT="${UPSTREAM_PORT:-ens4f0}"

# Time receiver NIC pin IDs
GNSS_ID="${GNSS_ID:-27}"
SDP23_ID="${SDP23_ID:-33}"
SDP22_ID="${SDP22_ID:-21}"
SDP21_ID="${SDP21_ID:-32}"
SDP20_ID="${SDP20_ID:-22}"

# Time receiver NIC pin parent IDs
PPID_EEC=2
PPID_PPS=3

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
	set_pin_state $SDP23_ID $PPID_PPS disconnected

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
	# Disable SDP23, enable SDP22
	set_pin_state $SDP23_ID $PPID_PPS disconnected
	set_pin_state $SDP22_ID $PPID_PPS selectable
}

kill () {
	parent=$(ps -o pgid= -p $(ps -ef |grep ptp4l |grep bash | awk '{print $2}'))
	sudo kill -9 -$parent
}

hold () {
	# Disable SDP22, Enable SDP23
	set_pin_state $SDP22_ID $PPID_PPS disconnected
	set_pin_state $SDP23_ID $PPID_PPS connected

}

