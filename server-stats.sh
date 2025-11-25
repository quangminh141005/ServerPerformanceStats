#! /usr/bin/env bash

# server performance stats

set -o errexit # stop if command fail 
set -o nounset # stop if i use a unset varivable
set -o pipefall # fail if part of a pipeline fail

# seperator line
hr() {
    printf '\n==============================================================\n\n'
}

title() {
    hr
    echo ">>> $1"
    hr
}

cpu_usage() {
    title "cpu usage"

    if command -v top >/dev/null 2>&1; then
        cpu_line=$(LC_ALL=C top -bn1 | grep -m1 "Cpu(s)") # LC_ALL=C: output always English, b(non interative), n1(one iteration), m1(stop after the first match)
        # Extract idle % then subtract from 100
        cpu_used=$(echo "$cpu_line" | awk -F',' '
        {
            idle=0
            for (i=1; i<=NF; i++) {
                if ($i ~ /id/) {
                    # take the number before "id"
                    split($i, a, " ") # a is the array to store the variable after split
                    for (j=1; j<length(a); j++) {
                        if (a[j] ~ /^[0-9.]+$/)
                        idle=a[j]
                    }
                }
            }
            if (idle == 0) idle = 0
            printf "%.2f\n", 100-idle
        }')

        echo "Total CPU usage: ${cpu_used}%"
    else
        # if top doesn't exist 
        echo "top command not found; using value from /proc/stat (approximate)."
        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat # read from /proc/stat
        total1=$((user+nice+system+idle+iowait+irq+softirq+steal))
        idle1=$idle
        sleep 1 # wait for the second value to see the changes
        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
        total2=$((user+nice+system+idle+iowait+irq+softirq+steal))
        idle2=$idle
        total_diff=$((total2-total1))
        idle_diff=$((idle2-idle1))
        cpu_used=$(awk -v t="$total_diff" -v i="$idle_diff" 'BEGIN { if(t==0) {print 0} else {print "%.2f", (t-i)/t*100} }') # -v to receive bash variable
        echo "Total CPU usage: ${cpu_used}%"
    fi
}