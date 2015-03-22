function printResults()
{
    if (resultIndex == 0) {
	return;
    }

    if ((resultIndex >= 3) && (frameworkName == testFramework)) {
	for (i = 0; i <= resultIndex; ++i) {
	    if (fileNamePrinted == 0) {
		printf("File: %s\n", fileName);
		printf("Test directory: %s\n", testDirectory);
		printf("Test framework: %s\n", testFramework);
		fileNamePrinted = 1;
	    }
	    if (frameworkNamePrinted == 0) {
#		printf("Framework: %s\n", frameworkName);
		frameworkNamePrinted = 1;
	    }
	    printf(results[i]);
	}
	n = asort(systemTimes);
	if ((n % 2) == 1) {
	    median = systemTimes[int(n / 2) + 1];
	}
	else {
	    median = (systemTimes[n / 2 + 1] + systemTimes[n / 2]) / 2;
	}
	printf("Median: %d s\n", median / 1000);

	if (match(fileName, /\/([^\/]*)\/results.txt/, subs)) {
	    fn = subs[1];
	    if (match(fn, /([^-]*)-([^-]*)-([^-]*)-([^-]*)$/, subs)) {
		testName = subs[4];
		numEvents = subs[3];
		numNodes = subs[1];
	    }
	}

	outputFileName = sprintf("%s/test-%s_%s_%d", resultDir, testFramework, testName, numNodes);
	printf("Result: %s: %d %d\n", outputFileName, numEvents, median / 1000);
	printf("%d %d\n", numEvents, median / 1000) >> outputFileName;

	if (((testFramework == "spark-caching") || (frameworkName == "spark-caching")) && (warmUpTime != -1)) {
	    outputFileName = sprintf("%s/warm-up-%s_%s_%d", resultDir, testFramework, testName, numNodes);
	    printf("Result: %s: %d %d\n", outputFileName, numEvents, warmUpTime / 1000);
	    printf("%d %d\n", numEvents, warmUpTime / 1000) >> outputFileName;
	}

	++numResults;
    }

    delete results;
    delete systemTimes;
    resultIndex = 0;
    warmUpTime = -1;
}

BEGIN {
    fileName = "";
    frameworkName = "";
    fileNamePrinted = 0;
    frameworkNamePrinted = 0;
    resultIndex = 0;
    numResults = 0;
    warmUpTime = -1;
    delete loadTimes;
}
{
    if (fileName != FILENAME) {
	printResults();
	fileNamePrinted = 0;
	frameworkNamePrinted = 0;
	fileName = FILENAME;
    }

    if (match($0, /Starting (.*) test #1.../, subs)) {
	tmp = subs[1];
	printResults();
	frameworkNamePrinted = 0;
	frameworkName = tmp;
    }

    if ((frameworkName == "spark-caching") || (frameworkName == "spark2-caching")) {
	if (match($0, /^Finished spark warm-up operation: ([^ ])+ ([0-9]+) ms/, subs)) {
	    warmUpTime = subs[2];
	}
	else if (match($0, /^Finished spark operation: ([^ ])+ ([0-9]+) ms/, subs)) {
	    systemTimes[resultIndex] = subs[2];
	    results[resultIndex] = sprintf("%d s\n", systemTimes[resultIndex] / 1000);
	    ++resultIndex;
	}
    }
    else {
	if (match($0, /^.*system ([0-9]?[0-9]):([0-9][0-9]).([0-9][0-9])/, subs)) {
	    systemTimes[resultIndex] = (subs[1] * 60000) + (subs[2] * 1000) + subs[3] * 10;
	    results[resultIndex] = sprintf("%d:%d.%d (%d s)\n", subs[1], subs[2], subs[3], systemTimes[resultIndex] / 1000);
	    ++resultIndex;
	}
    }
}

END {
    printResults();
    if (numResults > 0) {
	print "";
    }
}
