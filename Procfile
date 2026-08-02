#ptp4l_0:  chrt -f 10 ptp4l -f /app/ptp/ptp4l.0.config -2 --summary_interval -4 -m
ptp4l_1:   chrt -f 10 ptp4l -f /app/ptp/ptp4l.1.config -2 --summary_interval -4 -m
#strace:    strace --attach=$(pidof ptp4l) --syscall-times=us -f -tt -s 256 -o /app/$(awk '{print $1}' /proc/uptime).ptp4l.trace
#ts2phc:   sleep 60 && chrt -f 10 ts2phc -f /app/ptp/ts2phc.1.config -s generic -a --ts2phc.rh_external_pps 1
phc2sys:   bash -c 'while true; do chrt -f 10 phc2sys -f /app/ptp/phc2sys.1.config -r -n 24 -N 8 -R 16 -u 0 -m -s eno8703; echo "restarting phc2sys in 2s..."; sleep 2; done'
#monitor:  echo $IMAGE_PULL && sleep inf
