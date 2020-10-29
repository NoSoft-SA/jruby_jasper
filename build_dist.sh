#!/bin/bash

# make jar
bundle exec warble

# zip jar, starter and config into dist dir...
zip dist/jruby_jasper.zip jruby_jasper.jar start.sh config/.env config/log4j2.xml jruby_jasper.service.template INSTALL.md
