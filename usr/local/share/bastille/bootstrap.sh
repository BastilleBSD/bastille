#!/bin/sh
# 
# Copyright (c) 2018, Christer Edwards <christer.edwards@gmail.com>
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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille bootstrap release.${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

RELEASE=$1

bootstrap() {
    ### create $bastille_base/release/$release directory
    ### fetch $release/base.txz -o $bastille_base/cache/$release/base.txz
    ### extract $release/base.txz to $bastille_base/release/$release
    if [ ! -d ${bastille_jailsdir} ]; then
        mkdir -p ${bastille_jailsdir}
    fi
    if [ ! -d ${bastille_logsdir} ]; then
        mkdir -p ${bastille_logsdir}
    fi
    if [ ! -d ${bastille_cachedir}/${RELEASE} ]; then
        mkdir -p ${bastille_cachedir}/${RELEASE}
    fi

    if [ ! -d ${bastille_releasesdir}/${RELEASE} ]; then
        mkdir -p ${bastille_releasesdir}/${RELEASE}
        sh ${bastille_sharedir}/freebsd_dist_fetch.sh -r ${RELEASE} base lib32

        echo
        echo -e "${COLOR_GREEN}Extracting FreeBSD ${RELEASE} base.txz.${COLOR_RESET}"
        /usr/bin/tar -C ${bastille_releasesdir}/${RELEASE} -xf ${bastille_cachedir}/${RELEASE}/base.txz

        echo -e "${COLOR_GREEN}Extracting FreeBSD ${RELEASE} lib32.txz.${COLOR_RESET}"
        /usr/bin/tar -C ${bastille_releasesdir}/${RELEASE} -xf ${bastille_cachedir}/${RELEASE}/lib32.txz

	    echo -e "${COLOR_GREEN}Bootstrap successful.${COLOR_RESET}"
	    echo -e "${COLOR_GREEN}See 'bastille --help' for available commands.${COLOR_RESET}"
	    echo
    else
        echo -e "${COLOR_RED}Bootstrap appears complete.${COLOR_RESET}"
	exit 1
    fi
}

# Filter sane release names
case "${RELEASE}" in
10.1-RELEASE)
    bootstrap
    echo -e "${COLOR_RED}This release is End of Life. No security updates.${COLOR_RESET}"
	;;
10.2-RELEASE)
    bootstrap
    echo -e "${COLOR_RED}This release is End of Life. No security updates.${COLOR_RESET}"
	;;
10.3-RELEASE)
    bootstrap
    echo -e "${COLOR_RED}This release is End of Life. No security updates.${COLOR_RESET}"
	;;
10.4-RELEASE)
    bootstrap
    echo -e "${COLOR_RED}This release is End of Life. No security updates.${COLOR_RESET}"
	;;
11.0-RELEASE)
    bootstrap
    echo -e "${COLOR_RED}This release is End of Life. No security updates.${COLOR_RESET}"
	;;
11.1-RELEASE)
    bootstrap
    echo -e "${COLOR_RED}This release is End of Life. No security updates.${COLOR_RESET}"
	;;
11.2-RELEASE)
    bootstrap
	;;
12.0-BETA1)
    bootstrap
    echo -e "${COLOR_RED}BETA releases are completely untested.${COLOR_RESET}"
	;;
12.0-BETA2)
    bootstrap
    echo -e "${COLOR_RED}BETA releases are completely untested.${COLOR_RESET}"
	;;
12.0-BETA3)
    bootstrap
    echo -e "${COLOR_RED}BETA releases are completely untested.${COLOR_RESET}"
	;;
12.0-BETA4)
    bootstrap
    echo -e "${COLOR_RED}BETA releases are completely untested.${COLOR_RESET}"
	;;
*)
    echo -e "${COLOR_RED}BETA releases are completely untested.${COLOR_RESET}"
    usage
    ;;
esac
