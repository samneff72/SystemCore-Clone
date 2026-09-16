#!/bin/bash
# Replacement for robot.service's ExecStartPre. The stock check greps
# `ip link show X up` for "state UP" for 15 s; vcan interfaces report
# "state UNKNOWN" even when up, so on a DIY unit (can_s2..4 = vcan) robot code
# always waited the full 15 s before starting. Accept any interface whose link
# flags include UP.
for i in $(seq 1 15); do
  ok=1
  for c in can_s0 can_s1 can_s2 can_s3 can_s4; do
    flags=$(ip -o link show "$c" 2>/dev/null | sed -n 's/.*<\([^>]*\)>.*/\1/p')
    case ",$flags," in *,UP,*) ;; *) ok=0; echo "diy-can: $c not up";; esac
  done
  [ "$ok" = 1 ] && exit 0
  sleep 1
done
echo "diy-can: not all can_s* buses are UP after 15 s, starting robot code anyway"
exit 0
