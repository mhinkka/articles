# Assessing Big Data SQL Frameworks for Analyzing Event Logs
---

This directory will eventually contain all the supporting materials for this article. Support materials will include scripts and configurations used to perform the tests in Aalto University's Triton Cluster.

## Files of the test framework
---

The following list contains short descriptions for all the most important files and directories
related to the developed test framework. 

    README.md                     -> This file.
    scripts/                      -> All the script files.
      hadoop/                     -> Hadoop configuration and startup scripts.
        conf/                     -> Hadoop configuration file templates for Hadoop 1.2.1.
        init.sh                   -> Hadoop configuration initializations.
        start-1.2.1.sh            -> Start Hadoop 1.2.1.
        start.sh                  -> Start Hadoop 2.4.0.
        stop-1.2.1.sh             -> Shutdown Hadoop 1.2.1.
        stop.sh                   -> Shutdown Hadoop 2.4.0.        
      hive/                       -> Hive test related files.
        conf/                     -> Hive configuration file templates for Hive 0.13.
        script/                   -> Test SQL scripts for Hive.
          flows.sql               -> Flow analysis test script.
          load-rcfile.sql         -> Script for loading CSV testdata into rcfile table.
          variations.sql          -> Trace analysis test script.
        udf/
          CollectAll.java         -> Java code for CollectAll-UDF function required by
                                     trace analysis.
        init.sh                   -> Hive configuration initializations.
        start.sh                  -> Start Hive 0.13.
        stop.sh                   -> Shutdown Hive 0.13.
        test-1.2.1.sh             -> Test Hive 0.13 using Hadoop 1.2.1.
        test.sh                   -> Test Hive 0.13 using Hadoop 2.4.0.
      presto/                     -> Presto test related files.
        conf/                     -> Presto configuration file templates for Presto 0.77.
          coordinator.sh          -> Launch Presto coordinator.
          presto-common-init.sh   -> Initialize presto host.
          worker.sh               -> Launch Presto worker.
        hadoop-conf/              -> Hadoop configuration file templates for Hadoop 2.4.0.
        script/                   -> Test SQL scripts for Presto.
          flows.sql               -> Flow analysis test script.
          variations.sql          -> Trace analysis test script.
        init.sh                   -> Hive configuration initializations.
        test.sh                   -> Test Presto using Hive 0.13 and Hadoop 2.4.0.
        test-1.2.1.sh             -> Test Presto using Hive 0.13 and Hadoop 1.2.1.
      results/                    -> Collected results of test runs in pgfplots friendly 
                                     format.
      shark/                      -> Test scripts for testing Shark (not used in the paper)
      spark-1.2.1/                -> Spark 1.2.1 test related files.
        conf/                     -> Spark configuration file templates for Spark 1.2.1.
        script/                   -> Test Java "scripts" for Spark.
          src/main/java/          -> Spark test application Java sources.
            Tester.java           -> Main class for Spark-tests.
            TesterCaching.java    -> Main class for Spark-C-tests.
          pom.xml                 -> Maven Project Object Module file for test application.
        init.sh                   -> Spark configuration initializations.
        test.sh                   -> Test Spark 1.2.1.
        stop.sh                   -> Shutdown Spark 1.2.1.
      spark/                      -> Spark 1.0.2 test related files (not used in the paper).
      testdata/                   -> Test data generation related scripts and files.
        bpi_2013_challenge.csv    -> CSV file used as basis of the test data.
        buildtestdata.sh          -> Generate actual test data by repeating the provided CSV 
                                     multiple times and by generating unique case ids for 
                                     every file.
      .bashrc                     -> Variable initializations for bash shells.
      launcher.sh                 -> Launch actual test runs.
      results.sh                  -> Collect results from logs generated into sub directories 
                                     of test target directory.
      triton.template.sh          -> Template of the actual batch script that is passed to the SLURM.
      

## Test framework usage
---

### Environment Requirements

Test framework is hard-coded to work only on Aalto's Triton cluster by an user having a specific kind of directory hierarchies. This chapter explains required directories and their contents.

    $HOME/
      hadoop/
        hadoop-1.2.1/              -> Apache Hadoop 1.2.1 binary distribution.
        hadoop-2.4.0/              -> Apache Hadoop 2.4.0 binary distribution.
      hive/
        apache-hive-0.13.1-bin     -> Apache Hive 0.13.1 binary distribution.
      maven/
        apache-maven-3.2.5/        -> Apache Maven 3.2.5 binary distribution.
      presto/
        presto                     -> Presto command line interface executable.
      scala/
        scala-2.10.2/              -> Scala 2.10.2 binary distribution.
      spark/
        spark-1.0.2-bin-hadoop2/   -> Spark 1.0.2 binary distribution for Hadoop 2.
        spark-1.2.1-bin-hadoop2.4/ -> Spark 1.0.2 binary distribution for Hadoop 2.4.
    $WRKDIR/
      packages/                    -> Storage for additional binary distributions used 
                                      in tests.
        presto-server-0.77/        -> Facebook Presto-Server 0.77 binary distribution.
      runs/                        -> Test result target directory.
      test.csv                     -> Test data to use for tests.

Also the environment definitions in scripts/.bashrc must be added to bash initialization scripts used in worker hosts.
      
### Initializing test data

1. Change working directory to be the scripts/testdata-directory.
2. Run buildtestdata.sh script using suitable arguments and route the output to $WRKDIR/test.csv.

Example:
./buildtestdata.sh 1600 bpi_2013_challenge.csv > $WRKDIR/test.csv

These parameters were used to generate the test data used in the paper.

### Running test(s)

1. Log into Aalto's Triton cluster front-end system.
2. Change working directory to be the scripts-directory.
3. Run launcher.sh script using suitable arguments.

Example:
. launcher.sh test triton.template.sh "flows variations" "4 8" 10000000 3 "hive presto spark spark-caching"

This will generate several (one for every test type and one for every number of worker hosts => 4) batch jobs that will be transmitted to SLURM. 
This will run flow and trace analysis using 4 and 8 worker hosts on test data having 10 million events three times on hive, presto, spark and spark-caching settings.

### Collecting results from test result target directory

1. Log into Aalto's Triton cluster front-end system.
2. Change working directory to be the scripts-directory.
3. Run results.sh-script.

Results will be generated in pgfplots friendly format into results-subdirectory.

