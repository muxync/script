#!/bin/bash -e

################################################################################
# vm-create.sh
# Helper script to create virtual machines using virt-install
#
# Prompts for missing arguments before creating the new VM
# Defaults can be configured below
# Requires virtinst command-line tools and GNU getopt (util-linux)
#
# Author: Mark Mulligan (muxync)
# Website: https://github.com/muxync/scripts
# License: The MIT License (MIT) https://creativecommons.org/licenses/MIT
#
# Copyright (c) 2016 Mark Mulligan <muxync@muxync.net>
#
################################################################################

## User Configuration
# Use a '*' for release in ISO_TYPE to auto detect latest ISO_DEFAULT
# See VM_CREATE at end of this script if additional configuration is desired
URI_DEFAULT="qemu:///system"
HVM_DEFAULT="Y"
ISO_TYPE="debian*amd64-netinst.iso"
ISO_DIR="/virt/iso"
RAM_DEFAULT=1024
SIZE_DEFAULT=6
FORMAT_DEFAULT="qcow2"
GRAPHICS_DEFAULT="vnc"
AUTOSTART_DEFAULT="Y"
STORAGE_DIR="/var/lib/libvirt/images"

## Internal Configuration and Tests
ISO_DEFAULT=$(printf '%s\n' ${ISO_DIR}/${ISO_TYPE} | tail -1)
SCRIPT=$(basename ${BASH_SOURCE[0]})

# Check getopt compatibility
if $(getopt --test >/dev/null 2>&1) ; [ $? -ne 4 ]; then
    echo "${SCRIPT}: old version of getopt detected using 'getopt --test'"
    echo "${SCRIPT}: install GNU getopt (util-linux) and try again"
    exit 1
fi

# Help Message
USAGE="usage: ${SCRIPT} [-h] [-n NAME] [-u URI] [-v] [-i ISO] [-r RAM]
                    [-s SIZE] [-f FORMAT] [-g GRAPHICS] [-a]

optional arguments:
  -h, --help            show this help message and exit
  -n NAME, --name NAME  name for virtual machine
  -u URI, --uri URI     hypervisor URI
  -v, --hvm             use full virtualization
  -i ISO, --iso ISO     path to the ISO disk image
  -r RAM, --ram RAM     RAM allocated to the VM in MB
  -s SIZE, --size SIZE  disk size of the VM in GB
  -f FORMAT, --format FORMAT
                        format of the disk disk image
  -g GRAPHICS, --graphics GRAPHICS
                        graphics connection type
  -a, --autostart       autostart the VM at host boot"

# Configure getopt
OPTS_SHORT="hn:u:vi:r:s:f:g:a"
OPTS_LONG="help,name:,uri:,hvm,iso:,ram:,size:,format:,graphics:,autostart"
OPTS_ALL=$(getopt --options ${OPTS_SHORT} --long ${OPTS_LONG} \
    --name ${SCRIPT} -- "$@")

# Check for bad arguments
if [ $? -ne 0 ];
then
    echo "${SCRIPT}: bad argument(s) in getopt initialization"
    exit 2
fi

# Evaluate and parse command-line options
eval set -- "${OPTS_ALL}"

while true; do
    case "$1" in
        -h|-\?|--help)
            echo "${USAGE}"
            exit
            ;;
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -u|--uri)
            URI="$2"
            shift 2
            ;;
        -v|--hvm)
            HVM="Y"
            shift
            ;;
        -i|--iso)
            ISO="$2"
            shift 2
            ;;
        -r|--ram)
            RAM="$2"
            shift 2
            ;;
        -s|--size)
            SIZE="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -g|--graphics)
            GRAPHICS="$2"
            shift 2
            ;;
        -a|--autostart)
            AUTOSTART="Y"
            shift
            ;;
        --)
            shift;
            break
            ;;
    esac
done

## Functions
# Prompt for var configuration (read from var_str) if not set previously
# Offer default configuration and set var with user input
ask () {
    # Use indirect parameter expansion to obtain var value from var string
    local var="${!var_str}"
    local var_str_default="${var_str}_DEFAULT"
    local default="${!var_str_default}"

    if [ -z "${var}" ]; then
        # Loop until a non-empty answer is given
        while true; do
            if [ -z "${default}" ]; then
                read -p "${question}: " answer
            else
                read -p "${question} [${default}]: " answer
            fi

            answer="${answer:=${default}}"
            if [ -n "${answer}" ]; then
                eval ${var_str}="${answer}"
                break
            fi
        done
    fi
}

# Prompt for var configuration (read from var_str) if not set previously
# Offer default configuration and set var to '$1' if var is 'Y'
ask_yn () {
    # Use indirect parameter expansion to obtain var values from var string
    local var="${!var_str}"
    local var_str_default="${var_str}_DEFAULT"
    local default="${!var_str_default}"
    local choices=

    if [ -z "${var}" ]; then
        case "${default}" in
            [Yy]*) choices="Y/n" ;;
            [Nn]*) choices="y/N" ;;
            *) choices="y/n" ;;
        esac

        # Loop until a y/n answer is given
        while true; do
            read -p "${question} [${choices}]: " answer
            answer="${answer:=$default}"
            case "${answer}" in
                [Yy]*)
                    eval ${var_str}="$1"
                    break ;;
                [Nn]*)
                    unset ${var_str}
                    break ;;
            esac
        done
    else
        case "${!var_str}" in
            [Yy]*) eval ${var_str}="$1" ;;
            [Nn]*) unset ${var_str} ;;
        esac
    fi
}

## Main
var_str="NAME"
question="VM name"
ask

var_str="URI"
question="Hypervisor URI"
ask

var_str="HVM"
question="Full virtualization"
ask_yn "--hvm"

var_str="ISO"
question="ISO path"
ask

var_str="RAM"
question="RAM in MB"
ask

var_str="SIZE"
question="Disk size in GB"
ask

var_str="FORMAT"
question="Disk format"
ask

var_str="GRAPHICS"
question="Graphics connection"
ask

var_str="AUTOSTART"
question="Autostart the VM"
ask_yn "--autostart"

VM_CREATE="virt-install --connect ${URI} ${HVM} --name ${NAME}
    --cdrom ${ISO} --ram ${RAM} --disk
    path=${STORAGE_DIR}/${NAME}.img,size=${SIZE},format=${FORMAT}
    --graphics ${GRAPHICS} ${AUTOSTART}"

echo
echo "Creating VM..."
echo ${VM_CREATE}
echo
eval ${VM_CREATE}
