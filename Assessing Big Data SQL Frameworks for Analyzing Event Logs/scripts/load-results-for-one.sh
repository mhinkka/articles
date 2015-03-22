#!/bin/bash
echo $1
echo $2
cat $1 | sed -n -e 's/\(^.*system \)\([^e]*\)\(.*$\)/\2/p'
