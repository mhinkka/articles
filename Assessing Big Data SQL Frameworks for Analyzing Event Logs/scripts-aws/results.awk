function printResults()
{
    if (resultIndex >= 3 && (testFailed == 0)) {
	for (i = 0; i <= resultIndex; ++i) {
	    if (fileNamePrinted == 0) {
		printf("File: %s\n", fileName);
		printf("Test name: %s\n", testName);
		printf("Test framework: %s\n", frameworkName);
		fileNamePrinted = 1;
	    }
	    if (frameworkNamePrinted == 0) {
		printf("Framework: %s\n", frameworkName);
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

	outputFileName = sprintf("%s/test-%s_%s_%d", resultDir, frameworkName, testName, numNodes);
	printf("Result: %s: %d %d\n", outputFileName, numEvents, median / 1000);
	printf("%d %d\n", numEvents, median / 1000) >> outputFileName;

	if (loadTime != -1) {
	    outputFileName = sprintf("%s/load-%s_%s_%d", resultDir, frameworkName, testName, numNodes);
	    printf("Result: %s: %d %d\n", outputFileName, numEvents, loadTime / 1000);
	    printf("%d %d\n", numEvents, loadTime / 1000) >> outputFileName;
	}

	if (warmUpTime != -1) {
	    outputFileName = sprintf("%s/warm-up-%s_%s_%d", resultDir, frameworkName, testName, numNodes);
	    printf("Result: %s: %d %d\n", outputFileName, numEvents, warmUpTime / 1000);
	    printf("%d %d\n", numEvents, warmUpTime / 1000) >> outputFileName;
	}

	if ((loadTime != -1) && (warmUpTime != -1)) {
	    outputFileName = sprintf("%s/combined-%s_%s_%d", resultDir, frameworkName, testName, numNodes);
	    printf("Result: %s: %d %d\n", outputFileName, numEvents, (loadTime + warmUpTime) / 1000);
	    printf("%d %d\n", numEvents, (loadTime + warmUpTime) / 1000) >> outputFileName;
	}

	++numResults;
    }

    delete results;
    delete systemTimes;
    resultIndex = 0;
    loadTime = -1;
    warmUpTime = -1;
    testFailed = 0;
}

BEGIN {
    fileName = "";
    frameworkName = "";
    fileNamePrinted = 0;
    frameworkNamePrinted = 0;
    resultIndex = 0;
    numResults = 0;
    loadTime = -1;
    warmUpTime = -1;
    expectingLoad = 0;
    expectingWarmUp = 0;
    testFailed = 0;
    delete loadTimes;
}
{
    if (fileName != FILENAME) {
	printResults();
	fileNamePrinted = 0;
	frameworkNamePrinted = 0;
	fileName = FILENAME;
    }

    if (match($0, /Starting testing framework: (.*) \(id: [0-9]+\)/, subs)) {
	tmp = subs[1];
	printResults();
	frameworkNamePrinted = 0;
	frameworkName = tmp;
    }

    if (match($0, /Running test named: (.*)$/, subs)) {
	testName = subs[1];
    }

    if (match($0, /Number of events: (.*)$/, subs)) {
	numEvents = subs[1];
    }

    if (match($0, /Loading data...$/, subs)) {
	expectingLoad = 1;
    }

    if (match($0, /Performing warm-up run...$/, subs)) {
	expectingWarmUp = 1;
    }

    if (match($0, /TEST FAILED/, subs)) {
	testFailed = 1;
    }

    if ((frameworkName == "spark-caching") && (expectingLoad == 0)) {
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
	elapsedMs = -1;
	if (match($0, /^.*Elapsed: ([0-9]?[0-9]):([0-9][0-9])\.([0-9][0-9])/, subs)) {
	    elapsedMs = (subs[1] * 60 * 1000) + (subs[2] * 1000) + subs[3] * 10;
	}
	else if (match($0, /^.*Elapsed: ([0-9]?[0-9]):([0-9][0-9]):([0-9][0-9])/, subs)) {
            elapsedMs = (subs[1] * 60 * 60000) + (subs[2] * 60 * 1000) + (subs[3] * 1000);
        }

	if (elapsedMs != -1) {
	    if (expectingLoad != 0) {
		loadTime = elapsedMs;
		expectingLoad = 0;
	    }
	    else if (expectingWarmUp != 0) {
		warmUpTime = elapsedMs;
		expectingWarmUp = 0;
	    }
	    else {
		systemTimes[resultIndex] = elapsedMs;
		results[resultIndex] = sprintf("%d:%d.%d (%d s)\n", subs[1], subs[2], subs[3], systemTimes[resultIndex] / 1000);
		++resultIndex;
	    }
	}
    }
}

END {
    printResults();
    if (numResults > 0) {
	print "";
    }
}
