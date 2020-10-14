#!/bin/bash

# Get file of this script.
THIS_SCRIPT=`readlink -f $0`
# Absolute path this script is in.
SCRIPTPATH=`dirname $THIS_SCRIPT`
cd $SCRIPTPATH

export JAR_BASE=$SCRIPTPATH

java -jar jruby_jasper.jar
