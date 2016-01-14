#!/bin/bash -e

################################################################################
# firefox-tmp-pro.sh
# Run firefox using a temporary profile
#
# Creates a permission safe folder for the invoker in /tmp/ using mktemp
# Launches a new instance of firefox and cleans up the /tmp/ directort on exit
# Optionally installs add-ons and/or start in private browsing mode
#
# Author: Mark Mulligan (muxync)
# Website: https://github.com/muxync/scripts
# License: The MIT License (MIT) https://creativecommons.org/licenses/MIT
#
# Copyright (c) 2016 Mark Mulligan <muxync@muxync.net>
#
################################################################################

## User Configuration
TMP_DIR="/tmp"
FIREFOX_DIR="firefox-tmp-pro-XXXXXX"

## Internal Configuration and Tests
ADBLOCK_PLUS="https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi"
DISCONNECT="https://addons.mozilla.org/firefox/downloads/latest/464050/addon-464050-latest.xpi"
ERRORZILLA_PLUS="https://addons.mozilla.org/firefox/downloads/latest/5398/addon-5398-latest.xpi"
FLAGFOX="https://addons.mozilla.org/firefox/downloads/latest/5791/addon-5791-latest.xpi"
HTTPS_EVERYWHERE="https://addons.mozilla.org/firefox/downloads/latest/229918/addon-229918-latest.xpi"
NOSCRIPT="https://addons.mozilla.org/firefox/downloads/latest/722/addon-722-latest.xpi"
QRCODER="https://addons.mozilla.org/firefox/downloads/latest/333648/addon-333648-latest.xpi"
REDDIT_ES="https://addons.mozilla.org/firefox/downloads/latest/387429/addon-387429-latest.xpi"
TAB_MIX_PLUS="https://addons.mozilla.org/firefox/downloads/latest/1122/addon-1122-latest.xpi"
UBLOCK_ORIGIN="https://addons.mozilla.org/firefox/downloads/latest/607454/addon-607454-latest.xpi"
SCRIPT=$(basename ${BASH_SOURCE[0]})
ADDON_ARRAY=()

# Check getopt compatibility
if $(getopt --test >/dev/null 2>&1) ; [ $? -ne 4 ]; then
    echo "${SCRIPT}: old version of getopt detected using 'getopt --test'"
    echo "${SCRIPT}: install GNU getopt (util-linux) and try again"
    exit 1
fi

# Help Message
USAGE="usage: ${SCRIPT} [-h] [-a] [-d] [-e] [-f] [-s] [-n] [-q] [-r] [-t]
                          [-b] [-u URL] [-p]

optional arguments:
  -h, --help            show this help message and exit
  -a, --adblockplus     install Adblock Plus add-on
  -d, --disconnect      install Disconnect add-on
  -e, --errorzillaplus  install ErrorZilla Plus add-on
  -f, --flagfox         install Flagfox add-on
  -s, --httpseverywhere
                        install HTTPS Everywhere add-on
  -n, --noscript        install NoScript Security Suite add-on
  -q, --qrcoder         install QrCodeR add-on
  -r, --reddites        install Reddit Enhancement Suite add-on
  -t, --tabmixplus      install Tab Mix Plus add-on
  -b, --ublockorigin    install uBlock Origin add-on
  -u URL, --url URL     install add-on by URL
  -p, --private         start in private browsing mode"

# Configure getopt
OPTS_SHORT="hadefsnqrtbu:p"
OPTS_LONG="help,adblockplus,disconnect,errorzillaplus,flagfox,httpseverywhere,noscript,qrcoder,reddites,tabmixplus,ublockorigin,url:,private"
OPTS_ALL=$(getopt --options ${OPTS_SHORT} --long ${OPTS_LONG} \
    --name ${SCRIPT} -- "$@")

# Check for bad arguments
if [ $? -ne 0 ];
then
    exit 1
fi

# Evaluate and parse command-line options
eval set -- "${OPTS_ALL}"

while true; do
    case "$1" in
        -h|-\?|--help)
            echo "${USAGE}"
            exit
            ;;
        -a|--adblockplus)
            ADDON_ARRAY+=("ADBLOCK_PLUS")
            shift
            ;;
        -d|--disconnect)
            ADDON_ARRAY+=("DISCONNECT")
            shift
            ;;
        -e|--errorzillaplus)
            ADDON_ARRAY+=("ERRORZILLA_PLUS")
            shift
            ;;
        -f|--flagfox)
            ADDON_ARRAY+=("FLAGFOX")
            shift
            ;;
        -s|--httpseverywhere)
            ADDON_ARRAY+=("HTTPS_EVERYWHERE")
            shift
            ;;
        -n|--noscript)
            ADDON_ARRAY+=("NOSCRIPT")
            shift
            ;;
        -q|--qrcoder)
            ADDON_ARRAY+=("QRCODER")
            shift
            ;;
        -r|--reddites)
            ADDON_ARRAY+=("REDDIT_ES")
            shift
            ;;
        -t|--tabmixplus)
            ADDON_ARRAY+=("TAB_MIX_PLUS")
            shift
            ;;
        -b|--ublockorigin)
            ADDON_ARRAY+=("UBLOCK_ORIGIN")
            shift
            ;;
        -u|--url)
            ADDON_ARRAY+=("$2")
            shift 2
            ;;
        -p|--private)
            PRIVATE="-private"
            shift
            ;;
        --)
            shift;
            break
            ;;
    esac
done

## Functions
# Clean up the profile directory
clean_up () {
    rm -rf ${PROFILE_DIR}
    exit $?
}

# Download and install an add-on
addon_install () {
    # Use indirect parameter expansion to obtain url value from addon string
    local addon_url="${!addon}"
    local addon_path="${PROFILE_DIR}/addon-latest.xpi"

    # if addon_url is empty, assume addon was passed with --url option
    if [ -z "${addon_url}" ]; then
        addon_url="${addon}"
    fi

    wget "${addon_url}" --output-document="${addon_path}"
    addon_renamed=$(unzip -p "${addon_path}" install.rdf | grep 'id' | \
        cut -f2 -d">"|cut -f1 -d"<" | head -1)
    mv "${addon_path}" "${EXTENSIONS_DIR}/${addon_renamed}.xpi"
}

## Main
# Catch interrupt and termination signal to be sure clean_up is called
trap clean_up SIGINT SIGTERM

# Make the temporary profile directory
PROFILE_DIR=$(mktemp -p ${TMP_DIR} -d ${FIREFOX_DIR})

# Install add-ons (if applicable)
if [ "${#ADDON_ARRAY[@]}" -ne 0 ];
then
    EXTENSIONS_DIR="${PROFILE_DIR}/extensions"
    mkdir "${EXTENSIONS_DIR}"
    for i in "${ADDON_ARRAY[@]}"
    do
        addon="${i}"
        addon_install
    done
fi

# Run firefox and cleanup when finished
firefox -profile ${PROFILE_DIR} -no-remote ${PRIVATE}
clean_up
