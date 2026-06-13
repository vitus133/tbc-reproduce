#!/bin/bash

export TIME_RECEIVER_NIC=eno8703"
export UPSTREAM_PORT="eno8703"

export module="zl3073x"
export gnss_1pps_pkg_lab="REF4P"
export ptp_1pps_input_pkg_lab="REF0N"
export ptp_1khz_input_pkg_lab="REF0P"

export DPLL_COMMAND="sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll"



# Time receiver NIC pin IDs
# export GNSS_ID=$($DPLL_COMMAND pin show -j | jq '.pin[] | select(."module-name" == env.module) | select(."package-label" == env.gnss_1pps_pkg_lab) | .id')



# ptpInputPins:
PTP_INPUT_PIN_ID==$(sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll pin show -j | jq '.pin[] | select(."module-name" == env.module) | select(."package-label" == env.ptp_1pps_input_pkg_lab) | .id')
PTP_1KHZ_INPUT_PIN_ID==$(sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll pin show -j | jq '.pin[] | select(."module-name" == env.module) | select(."package-label" == env.ptp_1khz_input_pkg_lab) | .id')

DPLL_COMMAND="sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll"
# Time receiver NIC pin parent IDs
PPID_EEC=$($DPLL_COMMAND device show -j | jq '.device[] | select(."module-name" ==  "zl3073x") |select(.type == "eec") | .id')
PPID_PPS=$($DPLL_COMMAND device show -j | jq '.device[] | select(."module-name" ==  "zl3073x") |select(.type == "pps") | .id')

# prints command to disable the input by ID passed as $1
mk_disable_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" \
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

# prints command to enable the pps input by ID passed as $1 without changing priority
mk_enable_pps_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS"\
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"state":"disconnected"},{"parent-id":$PPID_PPS,"state":"selectable"}]}')
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
        echo "showphaseadj - show phase adjustments"
	echo "adjust - set phase adjustments from file"
}

init () {
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP0"
	sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP2"
	cmd=$(mk_disable_input_cmd $GNSS_ID)
	res=$(run_command "$cmd")
	if [[ "$res" != "None" ]]; then
		echo "Failed to run command: $cmd"
		return 1
	fi

}

up (){
	sudo ip link set $UPSTREAM_PORT up
}

down (){
	sudo ip link set $UPSTREAM_PORT down
}

lock () {
	sudo bash -c "echo 2 2 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP2"
	sudo bash -c "echo 2 1 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP0"
	sudo bash -c "echo 1 0 0 1 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/period"
	sudo bash -c "echo 2 0 0 0 1000000 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/period"
	cmd=$(mk_enable_pps_input_cmd $PTP_INPUT_PIN_ID)
        res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi

}

kill () {
	 parent=$(ps -o pgid= -p $(ps -ef |grep ptp4l |grep bash | awk '{print $2}') |awk '{print $1}')
         sudo kill -9 -$parent
}

hold () {
        sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP0"
        sudo bash -c "echo 0 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/pins/SDP2"
}

showphaseadj () {
	 sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll-cli dumpPins |jq -cr 'select(.phaseAdjust != 0) |"\(.id)\t\(.boardLabel)\t\(.phaseAdjust)"'
}
adjust () {
	FILE="delays.txt"

	# Check if file exists before starting
	if [[ ! -f "$FILE" ]]; then
    		echo "Error: $FILE not found."
    		exit 1
	fi

	# Use IFS to handle tabs/spaces and -r to prevent backslash escapes
	while read -r index name delay; do
    
    		echo "Setting $name with a delay of $delay ps..."
   		sudo podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll-cli setPin -i $index  -j $delay 
    
    		echo "--------------------------"

	done < "$FILE"
}

