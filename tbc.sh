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


# ptpInputPin: GNR-D_SDP0 id
PTP_INPUT_PIN_ID="${PTP_INPUT_PIN_ID:-0}"

# Time receiver NIC pin parent IDs
PPID_EEC=2
PPID_PPS=3

# Functions
# prints command to disable the input by ID passed as $1, parent IDs - $2 and $3
mk_disable_input_cmd () {
        id=$1
		parent_eec=$2
		parent_pps=$3
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$parent_eec" --arg PPID_PPS "$parent_pps" \
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"state":"disconnected"},{"parent-id":$PPID_PPS,"state":"disconnected"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /net-next/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}


# prints command to enable the input by ID passed as $1 and eec / pps priorities passed as $2 and $3
mk_enable_input_cmd () {
        id=$1
        eec_prio=$2
        pps_prio=$3
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" --arg eec_prio "$eec_prio" --arg pps_prio "$pps_prio"\
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"prio":$eec_prio,"state":"selectable"},{"parent-id":$PPID_PPS,"prio":$pps_prio,"state":"selectable"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /net-next/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}

# prints command to enable the output by ID passed as $1 and eec / pps priorities passed as $2 and $3
mk_enable_output_cmd () {
	id=$1
	parent_eec=$2
	parent_pps=$3
	JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$parent_eec" --arg PPID_PPS "$parent_pps" '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"direction":"output","state":"connected"},{"parent-id":$PPID_PPS,"direction":"output","state":"connected"}]}')
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll python3 cli.py --spec /net-next/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
	echo $CMD
}

# prints command to enable the pps input by ID passed as $1 without changing priority
mk_enable_pps_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS"\
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"state":"disconnected"},{"parent-id":$PPID_PPS,"state":"selectable"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /net-next/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}
mk_enable_input_cmd_2 () {
        id=$1
        eec_prio=$2
        pps_prio=$3
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" --arg eec_prio "$eec_prio" --arg pps_prio "$pps_prio"\
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"prio":$eec_prio,"state":"selectable"},{"parent-id":$PPID_PPS,"prio":$pps_prio,"state":"selectable"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /net-next/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}

mk_disable_output_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" \
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"state":"disconnected"},{"parent-id":$PPID_PPS,"state":"disconnected"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /net-next/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}


# Runs command given as a string in $1
run_command () {
       local CMD=$1
	eval $CMD
        rv=$?
        if [ $rv -ne 0 ]; then
        echo "Error"
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
	#disable GNSS of all three cards
	cmd=$(mk_disable_input_cmd $GNSS_ID $PPID_EEC $PPID_PPS)
	echo "disable ens4f0 GNSS input: $cmd"
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
		echo "Failed to run command: $cmd"
		return 1
	fi

	cmd=$(mk_disable_input_cmd 6 0 1)
	echo "disable ens5f0 GNSS input: $cmd"
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
		echo "Failed to run command: $cmd"
		return 1
	fi

	cmd=$(mk_disable_input_cmd 52 6 7)
	echo "disable ens8f0 GNSS input: $cmd"
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
		echo "Failed to run command: $cmd"
		return 1
	fi

	# # Enable leading card SMA1 and SMA2 outputs
	cmd=$(mk_enable_output_cmd 34 2 3)
	echo "enable ens4f0 SMA1 output: $cmd"
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
		echo "Failed to run command: $cmd"
		return 1
	fi

	cmd=$(mk_enable_output_cmd 35 2 3)
	echo "enable ens4f0 SMA1 output: $cmd"
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
		echo "Failed to run command: $cmd"
		return 1
	fi

	cmd=$(mk_disable_input_cmd $SDP20_ID $PPID_EEC $PPID_PPS)
	echo $cmd
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
			echo "Failed to run command: $cmd"
		return 1
	fi
    cmd=$(mk_disable_output_cmd $SDP21_ID)
        echo $cmd
    res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi
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

#  Enable SDP22, disable SDP23
    CMD=$(mk_enable_input_cmd_2 $SDP22_ID 255 0)
    echo $CMD
        res=$(run_command "$CMD")
        if [[ "$res" != "None" ]]; then
            echo "Failed to run command: $cmd"
                return 1
        fi

    cmd=$(mk_disable_output_cmd $SDP23_ID)
        echo $cmd
    res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi
}

kill () {
	parent=$(ps -o pgid= -p $(ps -ef |grep ptp4l |grep bash | awk '{print $2}'))
	sudo kill -9 -$parent
}

hold () {
	cmd=$(mk_disable_input_cmd $SDP22_ID $PPID_EEC $PPID_PPS)
	echo $cmd
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
			echo "Failed to run command: $cmd"
		return 1
	fi

	cmd=$(mk_enable_output_cmd $SDP23_ID $PPID_EEC $PPID_PPS)
	echo $cmd
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
			echo "Failed to run command: $cmd"
			return 1
	fi
}

# showphaseadj () {
# 	 sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll-cli dumpPins |jq -cr 'select(.phaseAdjust != 0) |"\(.id)\t\(.boardLabel)\t\(.phaseAdjust)"'
# }
# adjust () {
# 	FILE="delays.txt"

# 	# Check if file exists before starting
# 	if [[ ! -f "$FILE" ]]; then
#     		echo "Error: $FILE not found."
#     		exit 1
# 	fi

# 	# Use IFS to handle tabs/spaces and -r to prevent backslash escapes
# 	while read -r index name delay; do
    
#     		echo "Setting $name with a delay of $delay ps..."
#    		sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll-cli setPin -i $index  -j $delay 
    
#     		echo "--------------------------"

# 	done < "$FILE"
# }

