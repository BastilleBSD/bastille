#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
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


    if [ "$(jls name | xargs)" = "" ]; then printf "\nNo jail found?\n\n"; exit 1;

    else

    jails=`jls name | xargs | sed 's/ / -J /g'`
    
    

    printf "\n------------------"
    printf "\nJails - RAM usage:"
    printf "\n[kB] - [MB] - [GB]"
    printf "\n------------------\n"
    jls name | while SUM= read -r line; do printf "$line: " && ps -o %mem= -J "$line" | awk '{sum+=$1} END {printf("%.1f%%\n",sum)}' && \
    ps -o rss= -J "$line" | awk '{ total+=$1 } END { printf total " kB - " total/1000 " MB - "  total/1000**2 " GB\n\n" }'; done

    printf "Total RAM usage: "
    ps -o %mem= -J $jails | awk '{sum+=$1} END {printf("%.1f%%\n",sum)}'

    printf "\n------------------"
    printf "\nJails - CPU usage:"
    printf "\n------------------\n"
    jls name | while SUM= read -r line; do printf "$line: " && ps -o %cpu= -J "$line" | awk '{sum+=$1} END {printf("%.1f%%\n",sum)}'; done

    printf "\nTotal CPU usage: "
    ps -o %cpu= -J $jails | awk '{sum+=$1} END {printf("%.1f%%\n",sum)}'

    printf "\n-------------------------"
    printf "\nJails - Disk space usage:"
    printf "\n-------------------------\n"
    jls path | while SUM= read -r line; do du -sh "$line"; done
    printf "\n"
    exit 0;
    fi
    