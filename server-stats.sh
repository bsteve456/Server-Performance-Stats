#!/bin/bash
# Server stats script
#
# FIX 1: force C locale so tools print 81.9 instead of 81,9 (comma decimal
#        separator was breaking every number we parse).
export LC_ALL=C

echo "===== SERVER STATS ====="
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "OS:   $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo

echo "--- 1. TOTAL CPU USAGE ---"
# Run top twice, 1 sec apart, take the 2nd reading (1st is "since boot" = useless).
# The %Cpu line is comma-separated: "11.9 us, 5.4 sy, 0.0 ni, 81.9 id, ..."
# so field 4 after splitting on commas is the idle value.
IDLE=$(top -bn2 -d 1 | grep '%Cpu' | tail -1 | awk -F, '{gsub(/[^0-9.]/,"",$4); print $4}')
USED=$(awk -v i="${IDLE:-0}" 'BEGIN{printf "%.1f", 100-i}')
echo "Used: $USED%"
echo "Idle: $IDLE%"
echo

echo "--- 2. TOTAL MEMORY USAGE ---"
# Use column 7 (available), NOT column 4 (free). Linux spends spare RAM on
# cache, so "free" is misleadingly low on a healthy machine.
free -m | awk '/^Mem:/ {
    printf "Total:     %s MB\n",  $2
    printf "Used:      %s MB (%.1f%%)\n", $3, $3/$2*100
    printf "Available: %s MB (%.1f%%)\n", $7, $7/$2*100
}'
echo

echo "--- 3. TOTAL DISK USAGE ---"
# -x skips fake filesystems: tmpfs/devtmpfs/efivarfs/squashfs.
# (Without this, snap loop mounts all show "100%" and are pure noise.)
df -hT -x tmpfs -x devtmpfs -x efivarfs -x squashfs
echo

echo "--- 4. TOP 5 PROCESSES BY CPU ---"
# 'comm' instead of the default COMMAND: the full command line for browser
# processes is thousands of characters wide and makes the table unreadable.
ps -eo user,pid,pcpu,pmem,rss,comm --sort=-pcpu --no-headers | head -5 | \
  awk '{printf "  %-9s %-7s %6s%% %6s%% %8.0fMB  %s\n", $1,$2,$3,$4,$5/1024,$6}'
echo

echo "--- 5. TOP 5 PROCESSES BY MEMORY ---"
ps -eo user,pid,pcpu,pmem,rss,comm --sort=-pmem --no-headers | head -5 | \
  awk '{printf "  %-9s %-7s %6s%% %6s%% %8.0fMB  %s\n", $1,$2,$3,$4,$5/1024,$6}'
echo
