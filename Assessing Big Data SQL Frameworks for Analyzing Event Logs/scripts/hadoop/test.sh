#echo "Testing hadoop..."
#hadoop fs -mkdir input
#sleep 5
#hadoop fs -put hadoop/input/file1.txt input
#hadoop fs -put hadoop/input/file2.txt input
#hadoop jar hadoop/wordcount.jar org.myorg.WordCount input output
#hadoop fs -cat output/part-r-00000
