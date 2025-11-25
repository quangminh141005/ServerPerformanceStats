#! /usr/bin/env bash

# server performance stats

set -o errexit # stop if command fail 
set -o nounset # stop if i use a unset varivable
set -o pipefail # fail if part of a pipeline fail

# seperator line
hr() {
    printf '==============================================================\n'
}

title() {
    echo 
    hr
    echo ">>> $1"
    hr 
}

cpu_usage() {
    title "CPU USAGE"

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

# Memory usage
memory_usage() {
    title "MEMORY USAGE"

    if command  -v free >/dev/null 2>&1; then
    # Use mem row(second row) from `free -m`
    read -r _ total used free shared buff_cache available <<< "$(free -m | awk 'NR==2 {print $1, $2, $3, $4, $5, $6, $7}')"
    used_pct=$(awk -v t="$total" -v u="$used" 'BEGIN { if(t==0){print 0} else {printf "%.2f", u/t*100} }')
    free_pct=$(awk -v t="$total" -v f="$free" 'BEGIN { if(t==0){print 0} else {printf "%.2f", f/t*100} }')

    echo "Total memory:   ${total} MB"
    echo "Used:           ${used} MB (${used_pct}%)"
    echo "Free:           ${free} MB (${free_pct}%)"
    echo "Available:      ${available} MB"
    echo "Budffers/Cache: ${buff_cache} MB"
    fi
}

# Disk usage
disk_usage() {
    title "DISK USAGE (All mounted filesystems)"

    if command -v df >/dev/null 2>&1; then
        # Over all total line
        total_line=$(df -h --total 2>/dev/null | awk 'END{print}') # take the last line
        if [ -n "$total_line" ]; then # -n(not empty)
            read -r fs size used avail usepct mount <<< "$total_line"
            echo "Total disk size: $size"
            echo "Used:            $used ($usepct)"
            echo "Available        $avail"
        else 
            echo "Could not get --install; showing per file system"
        fi
    fi
}

# Top process
top_process() {
    title "TOP 5 PROCESS BY CPU"

    if command -v ps >/dev/null 2>&1; then
        # Header + 5 line
        ps -eo pid,comm,%cpu,%mem --sort=%cpu | head -n 6 # show only 6 line of the output
    else 
        echo "ps command not found"
    fi
    
    title "TOP 5 PROCESS BY MEM"

    if command -v ps >/dev/null 2>&1; then 
        ps -eo pid,comm,%mem,%cpu --sort=%mem | head -n 6
    else 
        echo "ps command not found"
    fi
}


# main 
cpu_usage
memory_usage
disk_usage
top_process