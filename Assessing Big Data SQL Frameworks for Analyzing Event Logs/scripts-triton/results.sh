RUNS_ROOT_PATH=$WRKDIR/runs
RESULTS_DIR=$PWD/results

'rm' -fr $RESULTS_DIR
mkdir -p $RESULTS_DIR

touch --date "2015-01-03" /tmp/firstvalidpresto.tmp
touch --date "2015-01-20" /tmp/firstvalidsparkflows.tmp

showResults()
{
    files=$1
    for fileName in $files; do
	testDirectory=$(echo $fileName | sed -n -e "s/^.*\/\([^\/]*\)$/\1/p")
	testFramework=$(echo $testDirectory | sed -n -e "s/\(.*\)\(-.*\)$/\1/p")
	if [ -z "$testFramework" ]; then
	    testFramework=$testDirectory
	fi

	# Skip some noisy and duplicate tests
	if [[ $fileName == *"test-0.77-8-rcfile-50000000-flows"* ]] && [ $testFramework == "hive" ]; then
	    echo "SKIPPING: $fileName $testFramework"
            continue
	fi

	if [[ $fileName == *"test-0.77-2-8-rcfile-100000000-flows"* ]] && [ $testFramework == "hive" ]; then
	    echo "SKIPPING: $fileName $testFramework"
            continue
	fi

	if [[ $fileName == *"test-0.77-2-8-rcfile-50000000-flows"* ]] && [ $testFramework == "hive" ]; then
	    echo "SKIPPING: $fileName $testFramework"
            continue
	fi

	if [[ $fileName == *"test-0.77-2-8-rcfile-100000000-flows"* ]] && [ $testFramework == "presto" ]; then
	    echo "SKIPPING: $fileName $testFramework"
            continue
	fi

	if [[ $fileName == *"spark-8-rcfile-10000000-variations"* ]] && [ $testFramework == "spark" ]; then
	    echo "SKIPPING: $fileName $testFramework"
            continue
	fi
	
	resultsPath="$fileName/$testDirectory"
	resultsFile=$(echo $resultsPath | sed -n -e "s/\/\([^\/]*\)$/\/load-results.txt/p")
	gawk -v successType="$2" -v testDirectory="$testDirectory" -v testFramework="$testFramework" -v resultDir="$RESULTS_DIR" -f ./load-results.awk $resultsFile

	resultsPath="$fileName/$testDirectory"
	resultsFile=$(echo $resultsPath | sed -n -e "s/\/\([^\/]*\)$/\/warm-up-results.txt/p")
	gawk -v successType="$2" -v testDirectory="$testDirectory" -v testFramework="$testFramework" -v resultDir="$RESULTS_DIR" -f ./warm-up-results.awk $resultsFile

	resultsFile=$(echo $fileName | sed -n -e "s/\/\([^\/]*\)$/\/results.txt/p")
	gawk -v successType="$2" -v testDirectory="$testDirectory" -v testFramework="$testFramework" -v resultDir="$RESULTS_DIR" -f ./results.awk $resultsFile
    done;
}

echo "Successful HIVE tests:"
#find $RUNS_ROOT_PATH -path "*/hive*/results/000000_0" | sed -n -e 's!^\(.*\)\/hive[^/]*\/results\/000000_0$!\1!p' | uniq | showHiveResults
files=$(find $RUNS_ROOT_PATH -path "*/hive*/results/000000_0" | sed -n -e 's!^\(.*\/hive[^/]*\)\/results\/000000_0$!\1!p' | uniq)
showResults "$files" "hive"

echo
echo "Successful Presto tests:"
#find $RUNS_ROOT_PATH -path "*/presto*/results*.tgz"  -size +260c | xargs ls -l | sed -n -e 's!^.*hinkkam2 *[0-9]\{3,\}.* \(.*\)/presto[^\/]*/results.*\.tgz$!\1!p' | uniq | showPrestoResults
files=$(find $RUNS_ROOT_PATH -path "*/presto*/results*.tgz" -size +350c -newer /tmp/firstvalidpresto.tmp | xargs ls -l | sed -n -e 's!^.*hinkkam2 *[0-9]\{3,\}.* \(.*/presto[^\/]*\)/results.*\.tgz$!\1!p' | uniq)
showResults "$files" "presto"

echo
echo "Successful Spark tests:"
files=$(find $RUNS_ROOT_PATH -path "*/spark-?/results/flows.csv" -newer /tmp/firstvalidsparkflows.tmp | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark"
files=$(find $RUNS_ROOT_PATH -path "*/spark-?/results/variations.csv" | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark"

echo
echo "Successful Spark (caching) tests:"
files=$(find $RUNS_ROOT_PATH -path "*/spark-caching-?/results/*.csv" | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark"

echo
echo "Successful Spark (parquet) tests:"
files=$(find $RUNS_ROOT_PATH -path "*/spark-parquet-?/results/*.csv" | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark"

echo
echo "Successful Spark2 tests:"
files=$(find $RUNS_ROOT_PATH -path "*/spark2-?/results/flows.csv" -newer /tmp/firstvalidsparkflows.tmp | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark2"
files=$(find $RUNS_ROOT_PATH -path "*/spark2-?/results/variations.csv" | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark2"

echo
echo "Successful Spark2 (caching) tests:"
files=$(find $RUNS_ROOT_PATH -path "*/spark2-caching-?/results/*.csv" | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark2"

echo
echo "Successful Spark2 (parquet) tests:"
files=$(find $RUNS_ROOT_PATH -path "*/spark2-parquet-?/results/*.csv" | sed -n -e 's!^\(.*\/spark[^\/]*\)\/results\/[a-zA-Z]*.csv$!\1!p' | uniq)
showResults "$files" "spark2"

echo "Finalizing results..."
files=$(find $RESULTS_DIR/ -type f)
for fileName in $files; do
    newFileName="$(basename "$fileName").dat"
    sort -gk 1 "$fileName" > $RESULTS_DIR/$newFileName
    'rm' -f $fileName;
done;

rm -fr /tmp/firstvalidpresto.tmp
rm -fr /tmp/firstvalidsparkflows.tmp
