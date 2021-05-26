#!/bin/sh
#
# Copyright (c) 2018-2021, Christer Edwards <christer.edwards@gmail.com>
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

ps -ax -o jid,jail,pcpu,pmem,rss,vsz,command | tail +2 | awk '

# There is one proces that shows how idle the cpu is. This we do not need.

$1 == /-/ && $2 == /[idle]/ {
  nextline; 		
}

{
  resources[$1,"name"]  = $2;
  resources[$1,"pcpu"] += $3;
  resources[$1,"pmem"] += $4;
  resources[$1,"rss"]  += $5;
  resources[$1,"vsz"]  += $6;
}

END {

  # If the table resources has more then 5 elements then there are jails.

  if (length(resources) > 5) {
    print "JID","IP_Address","Hostname_or_Jailname","Path","Cpu_(%)","Mem_(%)","Rss_(MB)","Vsz_(MB)","Zfs_disk";

    # Print Jailname resources

    jid = 0;

    cmd = "sysctl kern.hostname";
    cmd | getline hostname;
    split(hostname,line);
    name = line[2];
    close(cmd);

    pcpu = resources[jid,"pcpu"];
    pmem = resources[jid,"pmem"];
    rss = int(resources[jid,"rss"] / 1024);
    vsz = int(resources[jid,"vsz"] / 1024);

    print jid,"-",name,"-",pcpu,pmem,rss,vsz

    # Long jail names are shorten in the command : jls

    cmd_jls = "jls | tail +2"

    while ( (cmd_jls | getline result) > 0 ) {
      split(result,jail);
      jid = jail[1];
      ip = jail[2];
      path = jail[4];
      name = resources[jid,"name"];
      pcpu = resources[jid,"pcpu"];
      pmem = resources[jid,"pmem"];
      rss = int(resources[jid,"rss"] / 1024);
      vsz = int(resources[jid,"vsz"] / 1024);
    
      cmd_zfs = "zfs list -H -o used " path 
      cmd_zfs | getline zfs_size
      close(cmd_zfs)

      print jid,ip,name,path,pcpu,pmem,rss,vsz,zfs_size
    }

    close(cmd_jls);

  }
  else 
    print "There are no jail(s) running.";

}
 
' |  column -t | sed -e 's/_/ /g' 
