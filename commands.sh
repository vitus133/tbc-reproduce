#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

nohup sudo bash -c \
"/bin/chrt -f 10 ptp4l -f ptp/ptp4l.1.config -2 --summary_interval -4 -m | awk '{ print strftime(\"%Y-%m-%d %H:%M:%S\"), \$0; fflush(); }' & \
/bin/chrt -f 10 ptp4l -f ptp/ptp4l.0.config -2 --summary_interval -4 -m & \
/bin/chrt -f 10 ts2phc -f ptp/ts2phc.1.config -s generic -a --ts2phc.rh_external_pps 1 & \
podman run --privileged --network=host quay.io/vgrinber/tools:dpll dpll-cli monitor -t all & \
sleep 10 && /bin/chrt -f 10 phc2sys -f ptp/phc2sys.1.config -O -37 -r -n 24 -N 8 -R 16 -u 0 -m -s eno2 &"

