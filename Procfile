ptp4l_1:  chrt -f 10 ptp4l -f /app/ptp/ptp4l.1.config -2 --summary_interval -4 -m
ptp4l_0:  chrt -f 10 ptp4l -f /app/ptp/ptp4l.0.config -2 --summary_interval -4 -m
ts2phc:   chrt -f 10 ts2phc -f /app/ptp/ts2phc.1.config -s generic -a --ts2phc.rh_external_pps 1
phc2sys:  sleep 10 && chrt -f 10 phc2sys -f /app/ptp/phc2sys.1.config -r -n 24 -N 8 -R 16 -u 0 -m -s eth7
monitor:  echo $IMAGE_PULL && sleep inf
