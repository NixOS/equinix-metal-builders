#!/bin/sh

cfgOpt() {
    touch build.cfg
    ret=$(awk '$1 == "'"$1"'" { print $2; }' build.cfg)
    if [ -z "$ret" ]; then
        echo "Config option '$1' isn't specified in build.cfg" >&2
        echo "Example format:"
        echo "$1        value"
        echo ""
        exit 1
    fi

    echo "$ret"
}

pxeHost=netboot@netboot.gsc.io
pxeDir=/var/lib/nginx/netboot/webroot/
opensslServer=netboot.gsc.io
opensslPort=61616

#buildHost=$(cfgOpt "buildHost")
#pxeHost=$(cfgOpt "pxeHost")
#pxeDir=$(cfgOpt "pxeDir")
#opensslServer=$(cfgOpt "opensslServer")
#opensslPort=$(cfgOpt "opensslPort")
