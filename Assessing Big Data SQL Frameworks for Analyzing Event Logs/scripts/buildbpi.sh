#!/bin/bash
seq -w 1 $1 | xargs -I COUNT awk '{print "COUNT" $0}' $2
