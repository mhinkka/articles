#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Dec 25 11:59:43 2017

Test framework sources used to perform the tests required by paper: "Classifying Processes Instances Using Recurrent Neural Networks"
by Markku Hinkka, Teemu Lehto, Keijo Heljanko and Alexander Jung
"""

import csv
import numpy as np
import time
import sys
import operator
import io
import array
from datetime import datetime
import matplotlib.pyplot as plt
import math

UNKNOWN_TOKEN = "UNKNOWN"
IN_SELECTION_TOKEN = "SELECTED"
NOT_IN_SELECTION_TOKEN = "NOT_SELECTED"

class TraceData:
    traceId = ""
    isSelected = False
    activities = []
#    sentence = ""

    def __init__(self, var1, var2, var3, trace_length_modifier):
        self.traceId = var1
        self.isSelected = var2
        self.pathString = var3
        self.trace_length_modifier = trace_length_modifier
        if ((not var3) or var3.isspace()):
            self.fullActivities = np.asarray([])
        else:
            self.fullActivities = np.asarray([w.replace(" ", "_") for w in var3[2:-2].split("..")])
        if (trace_length_modifier != 1.0):
            self.activities = self.fullActivities[range(math.ceil(trace_length_modifier * len(self.fullActivities)))]
        else:
            self.activities = self.fullActivities
#        self.instrumentedActivities = [SENTENCE_START_TOKEN]
        self.instrumentedActivities = []
        self.instrumentedActivities.extend(self.activities)
        self.instrumentedActivities.append((IN_SELECTION_TOKEN if self.isSelected else NOT_IN_SELECTION_TOKEN))
#        self.instrumentedActivities.append(SENTENCE_END_TOKEN)
        self.sentence = "%s %s" % (" ".join(self.activities), (IN_SELECTION_TOKEN if self.isSelected else NOT_IN_SELECTION_TOKEN))
        self.activitiesForPrediction = {}

    def getActivitiesForPrediction(self, word_to_index, tracePercentage, truncateUnknowns, seqLength, vocabSize):
        key = "%s_%s_%s_%s_%s" % (tracePercentage, self.trace_length_modifier, truncateUnknowns, seqLength, vocabSize) 
        if (not key in self.activitiesForPrediction):
            activities = self.activities[range(math.ceil(tracePercentage * len(self.activities)))]
            unknownId = word_to_index[UNKNOWN_TOKEN]
            activities = [word_to_index[activity] if (activity in word_to_index) else unknownId for activity in activities]
            if (truncateUnknowns):
                origActivities = activities
                activities = []
                wasUnknown = False
                for id in origActivities:
                    isUnknown = id == unknownId
                    if ((not isUnknown) or (not wasUnknown)):
                        activities.append(id)
                    wasUnknown = isUnknown
            self.activitiesForPrediction[key] = activities
        return self.activitiesForPrediction[key]

    def getActivitiesForPredictionGRU(self, word_to_index):
        return [word_to_index[activity] for activity in self.activities]

loaded_traces = {}

def load_traces(traceName, filename, selectionCallback, trace_length_modifier, datasetSize = None):
    key = "%s_%s_%s" % (traceName, trace_length_modifier, datasetSize) 
    if (key in loaded_traces):
        return loaded_traces[key]
    word_to_index = []
    index_to_word = []
    traces = []

    # Read the data and append SENTENCE_START and SENTENCE_END tokens
    writeLog("Creating traces \"" + traceName + "\". Reading CSV file: " + filename)
    with open(filename, 'rt', encoding="utf-8") as f:
        reader = csv.reader(f, skipinitialspace=True, delimiter=';')
        reader.__next__()
        for row in reader:
            traces.append(TraceData(row[0], selectionCallback(row), row[len(row) - 1], trace_length_modifier))
    writeLog("Parsed %d traces." % (len(traces)))
    traces = np.asarray(traces)
#    sentences = []
#    for trace in traces:
#        sentences.append(trace.instrumentedActivities)
    if (datasetSize != None):
        traces = traces[:datasetSize]
    loaded_traces[key] = traces
    return traces #, Word2Vec(sentences, min_count=1)

def print_trace(s, index_to_word):
    sentence_str = [index_to_word[x] for x in s[1:-1]]
    writeLog(" ".join(sentence_str))
    sys.stdout.flush()

def generate_trace(model, index_to_word, word_to_index, min_length=5):
    # We start the sentence with the start token
    new_sentence = []
    # Repeat until we get an end token
    selIndex = word_to_index[IN_SELECTION_TOKEN]
    notSelIndex = word_to_index[NOT_IN_SELECTION_TOKEN]

    while not ((len(new_sentence) > 0) and ((new_sentence[-1] == selIndex) or (new_sentence[-1] == notSelIndex))):
        next_word_probs = model.predict(new_sentence)[-1]
        samples = np.random.multinomial(1, next_word_probs)
        sampled_word = np.argmax(samples)
        new_sentence.append(sampled_word)
        # Seomtimes we get stuck if the sentence becomes too long, e.g. "........" :(
        # And: We don't want sentences with UNKNOWN_TOKEN's
        if len(new_sentence) > 100 or sampled_word == word_to_index[UNKNOWN_TOKEN]:
            return None
    if len(new_sentence) < min_length:
        return None
    return new_sentence

def generate_traces(model, n, index_to_word, word_to_index):
    for i in range(n):
        sent = None
        while not sent:
            sent = generate_trace(model, index_to_word, word_to_index)
        print_trace(sent, index_to_word)

def predict_outcome(model, test, word_to_index):
    nextPrediction = model.predict(test)[-1]
    selIndex = word_to_index[IN_SELECTION_TOKEN]
    notSelIndex = word_to_index[NOT_IN_SELECTION_TOKEN]
    selProb = nextPrediction[selIndex]
    notSelProb = nextPrediction[notSelIndex]
    return selProb >= notSelProb;

def get_filename(figure_type, name, file_type):
    dtstr = datetime.now().replace(microsecond=0).isoformat().replace("-", "").replace(":", "")
    return _output_path + figure_type + "-" + name + "-" + dtstr + "." + file_type

def draw_train_chart(results, name):
    for i in range(len(results)):
        result = results[i]
        plt.plot(result.sr_examplesSeen, result.sr_trains, label = result.case_name)
    plt.xlabel('iterations')
    plt.ylabel('Success rate')
    plt.title('Training set classification success rate - ' + name)
    plt.legend()
    plt.savefig(get_filename("train", name, "pdf"))    
    plt.show()

def draw_test_chart(results, name):
    for i in range(len(results)):
        result = results[i]
        plt.plot(result.sr_examplesSeen, result.sr_tests, label = result.case_name)
    plt.xlabel('iterations')
    plt.ylabel('Success rate')
    plt.title('Test set classification success rate - ' + name)
    plt.legend()    
    plt.savefig(get_filename("test", name, "pdf"))    
    plt.show()

def draw_time_used_chart(results, name):
    for i in range(len(results)):
        result = results[i]
        plt.plot(result.sr_examplesSeen, result.time_used, label = result.case_name)
    plt.xlabel('iterations')
    plt.ylabel('Seconds')
    plt.title('Time used - ' + name)
    plt.legend()    
    plt.savefig(get_filename("duration", name, "pdf"))    
    plt.show()

def draw_charts(results, name):
    draw_train_chart(results, name)
    draw_test_chart(results, name)
    draw_time_used_chart(results, name)
    with open(get_filename("final-results", name, "csv"), "w") as csvfile:
        csvwriter = csv.writer(csvfile, delimiter=',',
                                quotechar='|', quoting=csv.QUOTE_MINIMAL)
        csvwriter.writerow(["TestName", "Dataset", "DatasetSize", "Count", "TimeUsed", "SR_Train", "SR_Test", "AvgCost", "Optimizer", "HiddenSize", "NumTraces"])
        for i in range(len(results)):
            result = results[i]
            result.write_csv(name, csvwriter)

_output_path = ""
_log_filename = ""
_results_filename = ""

def configure(output_path):
    global _output_path
    global _log_filename
    global _results_filename
    _output_path = output_path
    _log_filename = get_filename("log", "", "txt")
    _results_filename = get_filename("results", "", "csv")
    with open(_results_filename, "a", newline="") as csvfile:
        csvwriter = csv.writer(csvfile, delimiter=',', quotechar='|', quoting=csv.QUOTE_MINIMAL)
        csvwriter.writerow(["Time", "Status", "Name", "TestName", "Dataset", "DatasetSize", "Algorithm", "NumLayers", "HiddenDimSize", "Optimizer", "LearningRate", "SeqLength", "BatchSize", "GradClipping", "ItemsBetween", "TestIteration", "Iteration", "Epoch", "TimeUsed", "CumulTimeUsed", "TimeUsedForTest", "CumulTimeUsedForTest", "SR_Train", "SR_Test", "SR_Test75p", "SR_Test50p", "SR_Test25p", "AvgCost", "AUC", "TP", "TN", "FP", "FN", "AllConfusions", "PredictOnlyOutcome", "FinalTraceOnly", "TraceLengthMod", "FixedLength", "MaxNumActivities", "TruncateUnknowns"])

def writeLog(message):
    message = datetime.now().replace(microsecond=0).isoformat() + " \t" + message
    print(message)
    with open(_log_filename, "a") as logfile:
        logfile.write(message + "\n")

def writeResultRow(cells):
    with open(_results_filename, "a", newline="") as csvfile:
        csvwriter = csv.writer(csvfile, delimiter=',', quotechar='|', quoting=csv.QUOTE_MINIMAL)
        csvwriter.writerow(cells)
