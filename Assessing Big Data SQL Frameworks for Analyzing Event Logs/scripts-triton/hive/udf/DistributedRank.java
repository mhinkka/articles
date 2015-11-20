package com.example;

import java.util.*;
import org.apache.hadoop.hive.ql.exec.Description;
import org.apache.hadoop.hive.ql.exec.UDF;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.IntWritable;

public class DistributedRank extends UDF {
    public HashMap<String, Integer> counters = new HashMap<String, Integer>();

    public Text evaluate(Text input) {
	String inputStr = input.toString();
	Integer counter;
	if ((counter = counters.get(inputStr)) != null)
	    ++counter;
	else
	    counter = 1;

	counters.put(inputStr, counter);
	return new Text(counter.toString());
    }
}

