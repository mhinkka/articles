/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package my;

import scala.Tuple2;
import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.api.java.function.Function;
import org.apache.spark.api.java.function.Function2;
import org.apache.spark.api.java.function.PairFunction;
import org.apache.spark.api.java.function.FlatMapFunction;
import org.apache.spark.api.java.function.Function;
import org.apache.spark.sql.api.java.JavaSQLContext;
import org.apache.spark.sql.api.java.JavaSchemaRDD;
import org.apache.spark.sql.api.java.Row;
//import org.apache.spark.sql.hive.api.java.JavaHiveContext;

import java.io.PrintWriter;
import java.io.FileNotFoundException;
import java.util.ArrayList;
import java.util.List;
import java.util.Date;
import java.util.Comparator;
import java.util.Collections;

import my.Event;

/** 
 * Computes an approximation to pi
 * Usage: JavaSparkPi [slices]
 */
public final class Tester {
    private static SparkConf sparkConf;
    private static JavaSparkContext sc;
    private static JavaSQLContext sqlContext;
    private static String resultPath;
    private static String outDir;
    private static JavaSchemaRDD schemaEvents;

    public static void main(String[] args) throws Exception {
	sparkConf = new SparkConf().setAppName("SparkTester");
	sc = new JavaSparkContext(sparkConf);
	sqlContext = new JavaSQLContext(sc);
	String testName = args[0];
	outDir = args[1];
	int numRepeats = Integer.parseInt(args[2]);
	/*
	if (testName.equals("load")) {
	    System.out.println(new Date().toString() + " Load skipped...");
	}
	else {
	    runOperation(testName);
	}
	*/
	runOperation(testName);
    }

    private static void runOperation(String testName)
    {
	System.out.println(new Date().toString() + " Starting spark operation: " + testName);
	Date start = new Date();

	if (testName.equals("load")) 
	    load();
	else if (testName.equals("flows")) 
	    flows();
	else if (testName.equals("variations")) 
	    variations();

	Date end = new Date();
	System.out.println("Finished spark operation: " + testName + " " + (end.getTime() - start.getTime()) + " ms");
    }

    private static void load()
    {
	System.out.println(new Date().toString() + " Starting loading data to spark");

	// Load a text file and convert each line to a JavaBean.
	//	JavaRDD<Event> events = sc.textFile("$out/test.csv").map(
	JavaRDD<Event> events = sc.textFile(outDir + "/../test.csv").map(
	  new Function<String, Event>() {
	      public Event call(String line) throws Exception {
		  String[] parts = line.split(",");

		  System.out.println("Parsing: " + line);
		  Event e = new Event();
		  //		  e.setEventId(parts[0]);
		  e.setCaseId(parts[0]);
		  e.setEvent(parts[1]);
		  //		  e.setTimestamp(formatter.parse(parts[3]));
		  e.setTimestamp(parts[2]);
		  return e;
	      }
	  });

	JavaSchemaRDD schemaEvents = sqlContext.applySchema(events, Event.class);
	schemaEvents.registerAsTable("events");

	long rowCount = schemaEvents.count(); // Should at least force a scan the whole .csv-file thus loading the data
	System.out.println(new Date().toString() + " Events table initialized. Row count: " + rowCount);
    }

    public static <E>ArrayList<E> makeList(Iterable<E> iter) 
    {
	ArrayList<E> list = new ArrayList<E>();
	for (E item : iter) {
	    list.add(item);
	}
	return list;
    }

    private static void flows()
    {
	runOperation("load");

	JavaSchemaRDD orderedEvt = sqlContext.sql(
	       "SELECT eventId, caseId, event, timestamp FROM events");

	PairFunction<Row, String, Row> func = new PairFunction<Row, String, Row>() {
            public Tuple2<String, Row> call(Row r) throws Exception {
                return new Tuple2<String, Row>(r.getString(1), r);
            }
	};

	JavaPairRDD<String, Row> evtByCase = orderedEvt.mapToPair(func);
	JavaPairRDD<String, Iterable<Row>> groupByCase = evtByCase.groupByKey();

	/*
	  {
	      List<String> rows = groupByCase.map(new Function<Tuple2<String, Iterable<Row>>, String>() {
	          public String call(Tuple2<String, Iterable<Row>> row) {
		  String result = "";
		  List<Row> rl = makeList(row._2);
		  result += row._1 + " : " + rl.size() + " ";
		  for (Row r : rl) {
		      result += "," + r.getString(2);
		      }
		      return result;
		          }
			  }).collect();
			      writeStringListToFile(rows, outDir + "/results/tmp.csv");
			      }
	*/

	FlatMapFunction<Tuple2<String, Iterable<Row>>, Flow> fmFunc = new FlatMapFunction<Tuple2<String, Iterable<Row>>, Flow>() {
	    public Iterable<Flow> call(Tuple2<String, Iterable<Row>> item) {
		List<Row> rl = makeList(item._2);
		Collections.sort(rl,
				 new Comparator<Row>() {
				     @Override public int compare(Row r1, Row r2) {
					 int result = r1.getString(3).compareTo(r2.getString(3));
					 if (result != 0)
					     return result;
					 return r1.getString(2).compareTo(r2.getString(2));
				     }           
				 });
		
		List<Flow> result = new ArrayList<Flow>();
		Row previousRow = null;
		for (Row row : rl) {
		    if (previousRow != null) {
			result.add(new Flow(previousRow.getString(1), 
					    previousRow.getString(2), row.getString(2), 
					    previousRow.getString(3), row.getString(3)));
		    }
		    else {
			result.add(new Flow(row.getString(1), "_START", row.getString(2), "", row.getString(3)));
		    }
		    previousRow = row;
		}

		result.add(new Flow(previousRow.getString(1), previousRow.getString(2), "_END", previousRow.getString(3), ""));
		return result;
            }
	};
	JavaRDD<Flow> flows = groupByCase.flatMap(fmFunc);
	JavaSchemaRDD schemaFlows = sqlContext.applySchema(flows, Flow.class);
	schemaFlows.registerAsTable("flows");

	JavaSchemaRDD groupedFlows = sqlContext.sql(
"SELECT count(*) c, fromEvent, toEvent, SUM(duration) FROM flows " +
"GROUP BY fromEvent, toEvent " +
"ORDER BY c DESC, fromEvent ASC, toEvent ASC");

	saveTable(groupedFlows, outDir + "/results/flows.csv");

	System.out.println(new Date().toString() + " Flow analysis done");
    }

    private static void variations()
    {
	runOperation("load");

	JavaSchemaRDD orderedEvt = sqlContext.sql(
            "SELECT caseId, event, timestamp FROM events ORDER BY timestamp ASC, event ASC");
	//            "SELECT evt_case, evt_event, evt_timestamp FROM events ORDER BY evt_timestamp ASC, evt_event ASC");

	PairFunction<Row, String, Row> func = new PairFunction<Row, String, Row>() {
            public Tuple2<String, Row> call(Row r) throws Exception {
                return new Tuple2<String, Row>(r.getString(0), r);
            }
	};

	JavaPairRDD<String, Row> evtByCase = orderedEvt.mapToPair(func);
	JavaPairRDD<String, Iterable<Row>> groupByCase = evtByCase.groupByKey();

	Function<Tuple2<String, Iterable<Row>>, Variation> mFunc = new Function<Tuple2<String, Iterable<Row>>, Variation>() {
	    public Variation call(Tuple2<String, Iterable<Row>> item) {
		List<Row> rl = makeList(item._2);
		Collections.sort(rl,
		    new Comparator<Row>() {
			@Override public int compare(Row r1, Row r2) {
			    int result = r1.getString(2).compareTo(r2.getString(2));
			    if (result != 0)
				return result;
			    return r1.getString(1).compareTo(r2.getString(1));
			}           
		    });
		
		Variation result = new Variation(rl.size());
		
		for (Row row : rl) {
		    result.addToPath(row.getString(1));
		}
		return result;
            }
	};
	JavaRDD<Variation> variations = groupByCase.map(mFunc);
	JavaSchemaRDD schemaVariations = sqlContext.applySchema(variations, Variation.class);
	schemaVariations.registerAsTable("variations");

	JavaSchemaRDD groupedVariations = sqlContext.sql(
"SELECT count(*) caseCount, eventCount, eventTypes FROM variations " +
"GROUP BY eventTypes, eventCount " +
"ORDER BY caseCount DESC, eventCount DESC, eventTypes ASC");

	saveTable(groupedVariations, outDir + "/results/variations.csv");

	System.out.println(new Date().toString() + " Variation analysis done");
    }

    private static void saveTable(JavaSchemaRDD table, String toFilePath)
    {
        List<String> rows = table.map(new Function<Row, String>() {
                public String call(Row row) {
		    String result = "";
		    for (int i = 0; i < row.length(); ++i) {
			if (i > 0)
			    result += ",";
			result += row.get(i).toString();
		    }
		    return result;
                }
            }).collect();
	writeStringListToFile(rows, toFilePath);
    }

    private static void writeStringListToFile(List<String> rows, String toFilePath)
    {
	try {
	    PrintWriter out = new PrintWriter(toFilePath);
	    for (String row : rows) {
		out.println(row);
	    }
	    out.close();
	}
	catch (FileNotFoundException e) {
	    System.out.println("Error writing to result file " + e.toString() + " : " + toFilePath);
	    System.out.println("Writing to STDOUT instead.");
	    for (String row : rows) {
		System.out.println(row);
	    }
	}
    }
}
