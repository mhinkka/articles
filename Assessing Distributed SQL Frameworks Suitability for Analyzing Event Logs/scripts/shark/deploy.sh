# Move scripts to target
mkdir -p $out/shark/script
for f in script/*; do
   f2=$out/shark/script/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s:\${HADOOP_TRITON_TARGET}:$out:
   }"
done

# Copy configurations to installation directory
mkdir -p $SHARK_HOME/conf/
'cp' -f conf/* $SHARK_HOME/conf/

