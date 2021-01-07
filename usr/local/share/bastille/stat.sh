#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

. /usr/local/share/bastille/common.sh

usage() {
    error_exit "Usage: bastille stat"
}

if [ $# -gt 0 ]; then
    usage
fi

ps -axwww -o jail,%mem,%cpu,rss | grep -v "^-" | tail +2 | sort -k 1,1 | awk \
'
BEGIN { jail_string_length = 0}

{
    if (jail_string_length < length($1))
        jail_string_length = length($1);

    jail_hostname[$1] = $1
    jail[$1,"%mem"] += $2
    jail[$1,"%cpu"] += $3
    jail[$1,"rss"]  += $4
}

END {
    format1 = "%-" jail_string_length + 2 "s %-5s %-5s %-10s \n"
    format2 =  "%-" jail_string_length + 2 "s %-5s %-5s %-10.2f \n"
    print ""

    printf format1,"Hostname","%mem","%cpu","rss MB"

    for (hostname in jail_hostname)
        printf format2,hostname,jail[hostname,"%mem"],jail[hostname,"%cpu"],jail[hostname,"rss"] / 1024
}'

echo