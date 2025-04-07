#!/bin/sh

find . ! -name 'index.html' ! -name 'cleanup-dist.sh' -type f -exec rm -f {} +
