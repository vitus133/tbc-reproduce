ptp4l_1:  /bin/chrt -f 10 /home/core/.local/bin/ptp4l -f ptp/ptp4l.1.config -2 --summary_interval -4 -m
ptp4l_0:  /bin/chrt -f 10 /home/core/.local/bin/ptp4l -f ptp/ptp4l.0.config -2 --summary_interval -4 -m
ts2phc:   /bin/chrt -f 10 /home/core/.local/bin/ts2phc -f ptp/ts2phc.1.config -s generic -a --ts2phc.rh_external_pps 1
phc2sys:  sleep 10 && /bin/chrt -f 10 /home/core/.local/bin/phc2sys -f ptp/phc2sys.1.config -O -37 -r -n 24 -N 8 -R 16 -u 0 -m -s eno8703
