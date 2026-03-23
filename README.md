# T-BC holdover reproducer
In window 1

```bash
. tbc.sh
init
./commands.sh
```
In window 2:
```
tail -f nohup.out
```
1. Wait for ptp4l to lock (offset < 10ns), then back to window 1 and run 

```
lock
```
2. wait for DPLL to lock and stabilize (the offset oscillates around zero in a single digit nanosecond range)

To enter holdover:
```
down && hold
```
To exit holdover:

```
up
```
Wait for ptp4l offset to get below 10ns, then repeat 1 and 2


To kill ptp4l, ts2phc, phc2sys processes
```
kill
```
