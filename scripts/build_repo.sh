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
# Generate a valid repository package directory
###############################################################################

repository="${ISO_DIR}/packages.main"

cat > manifest <<EOF
control tarbz2 required control.tar.bz2 /
dom0 ext3gz required dom0-rootfs.i686.xc.ext3.gz /
uivm vhdgz required uivm-rootfs.i686.xc.ext3.vhd.gz /storage/uivm
ndvm vhdgz required ndvm-rootfs.i686.xc.ext3.vhd.gz /storage/ndvm
syncvm vhdgz optional syncvm-rootfs.i686.xc.ext3.vhd.gz /storage/syncvm
file iso optional xc-tools.iso /storage/isos/xc-tools.iso
EOF

echo -n > "$repository/XC-PACKAGES"

# Format of the manifest file is
# name format optional/required source_filename dest_path
while read name format opt_req src dest; do

    if [ ! -e "${repository}/${src}" ] ; then
        if [ "${opt_req}" = "required" ] ; then
            echo "Error: Required file $src is missing"
            exit 1
        fi

        echo "Optional file $src is missing: skipping"
        continue
    fi

    filesize=$( du -b ${repository}/${src} | awk '{print $1}' )
    sha256sum=$( sha256sum ${repository}/${src} | awk '{print $1}' )

    echo "$name" "$filesize" "$sha256sum" "$format" \
         "$opt_req" "$src" "$dest" >> "${repository}/XC-PACKAGES"
done < manifest

PACKAGES_SHA256SUM=$(sha256sum "${repository}/XC-PACKAGES" |
                                awk '{print $1}')

set +o pipefail #fragile part

# Pad XC-REPOSITORY to 1 MB with blank lines. If this is changed, the
# repository-signing process will also need to change.
{
    cat <<EOF
xc:main
pack:Base Pack
product:OpenXT
build:${BUILD_ID}
version:${VERSION}
release:${RELEASE}
upgrade-from:${UPGRADEABLE_RELEASES}
packages:${PACKAGES_SHA256SUM}
EOF
    yes ""
} | head -c 1048576 > "$repository/XC-REPOSITORY"

set -o pipefail #end of fragile part

openssl smime -sign \
        -aes256 \
        -binary \
        -in "$repository/XC-REPOSITORY" \
        -out "$repository/XC-SIGNATURE" \
        -outform PEM \
        -signer "${OE_BUILD_DIR}/certs/dev-cacert.pem" \
        -inkey "${OE_BUILD_DIR}/certs/dev-cakey.pem"


