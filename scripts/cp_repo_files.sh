#!/bin/bash

#
# This script is to build a valid OpenXT repository that may be used for
# generating a ISO file, an OTA package, or to just use on a PXE server.
#
# The contents of this are derived from OpenXT build-scripts.
#
# Copyright (c) 2016 Assured Information Security, Inc.
# Copyright (c) 2016 BAE Systems
# Copyright (c) 2016 Apertus Solutions, LLC
#
# Contributions by Jean-Edouard Lejosne
# Contributions by Christopher Clark
# Contributions by Daniel P. Smith
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

: ${IMAGE_DIR:="${OE_BUILD_TMPDIR}/deploy/images"}
: ${ISO_DIR:="${HOME}/repository"}
: ${COPY:="cp"}

[ -d $ISO_DIR ] || mkdir -p $ISO_DIR
mkdir -p ${ISO_DIR}/packages.main
mkdir -p ${ISO_DIR}/isolinux

###############################################################################
# Copy all files from build to ISO directory structure
###############################################################################

image_table=(
"xenclient-dom0         xenclient-initramfs                 cpio.gz"        \
"xenclient-stubdomain   xenclient-stubdomain-initramfs      cpio.gz"        \
"xenclient-dom0         xenclient-dom0                      xc.ext3.gz"     \
"xenclient-uivm         xenclient-uivm                      xc.ext3.vhd.gz" \
"xenclient-ndvm         xenclient-ndvm                      xc.ext3.vhd.gz" \
"xenclient-syncvm       xenclient-syncvm                    xc.ext3.vhd.gz" \
"xenclient-dom0         xenclient-installer                 cpio.gz"        \
"xenclient-dom0         xenclient-installer-part2           tar.bz2"        \
)

target="${ISO_DIR}"

for entry in "${image_table[@]}"; do
    machine=$(echo $entry | awk '{ print $1 }')
    image=$(echo $entry | awk '{ print $2 }')
    extension=$(echo $entry | awk '{ print $3 }')

    echo ${image} | grep -q initramfs && continue

    real_name=$(echo $image | cut -f2 -d-)
    source_base=${IMAGE_DIR}/${machine}/${image}-image
    source_image=${source_base}-${machine}.${extension}

    # Transfer image and give it the expected name
    if [ -f ${source_image} ]; then
        case ${image} in
        "xenclient-installer")
            $COPY ${source_image} ${target}/isolinux/rootfs.gz
        ;;
        "xenclient-installer-part2")
            $COPY ${source_image} ${target}/packages.main/control.${extension}
            $COPY ${IMAGE_DIR}/${machine}/*.acm \
                   ${IMAGE_DIR}/${machine}/tboot.gz \
                   ${IMAGE_DIR}/${machine}/xen.gz \
                   ${IMAGE_DIR}/${machine}/microcode_intel.bin \
                   ${target}/isolinux/
            $COPY ${IMAGE_DIR}/${machine}/bzImage-xenclient-dom0.bin \
                   ${target}/isolinux/vmlinuz
        ;;
        *)
            $COPY ${source_image} \
                ${target}/packages.main/${real_name}-rootfs.i686.${extension}
        ;;
        esac
    fi
done

