#/bin/sh

printf "   %-4s %-15s %-28s  %-36s  %-10s  %-12s  %-10s\n"       "JID"  "IP Address" "Hostname" "Path" "Memory" "Virtual Mem" "Disk"
for JID in `jls | grep -v JID | awk '{print $1}'`
do
a=`jls -j $JID | sed 1d`
b=`ps -J $JID -o rss | awk '{rss += $1} END {print rss}'`
v=`ps -J $JID -o vsz | awk '{cpu += $1} END {print cpu}'`
m=`jls -j $JID | sed 1d | awk '{print $4}'`
d=`zfs list -H -o used $m`

printf "%-90s  %-10s  %-12s  %-10s\n" "$a" "$(( ${b%% *} / 1024)) MB" "$(( ${v%% *} / 1024)) MB" "$d"
done
