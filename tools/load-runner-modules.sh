#!/usr/bin/env bash
# load-runner-modules.sh - load the netfilter match modules a fresh GitHub runner lacks.
#
# Without them firewall.service fails the switch with "Extension rpfilter
# revision 0 not supported". The IPv6 reverse-path module is ip6t_rpfilter;
# ip6_rpfilter does not exist (2026-10-31).
set -uo pipefail

modules=(ip_tables iptable_filter iptable_nat xt_pkttype xt_LOG ipt_rpfilter ip6t_rpfilter)
mode=${1:---load}
builtin_list="/lib/modules/$(uname -r)/modules.builtin"

present() {
  lsmod | grep -q "^$1 " || grep -q "/$1\.ko" "$builtin_list" 2>/dev/null
}

fail=0
for m in "${modules[@]}"; do
  [ "$mode" = "--check" ] || sudo modprobe "$m" 2>/dev/null
  present "$m" && continue
  echo "FAIL runner module '$m' is not loaded"
  fail=1
done
[ "$fail" -eq 0 ] && echo "OK   runner netfilter modules present"
exit "$fail"
