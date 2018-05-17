#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Dec 25 11:59:43 2017

Test framework sources used to perform the tests required by paper: "Classifying Processes Instances Using Recurrent Neural Networks"
by Markku Hinkka, Teemu Lehto, Keijo Heljanko and Alexander Jung
"""

import lasagne
from lasagne.layers import *
import numpy as np
import theano as theano
import theano.tensor as T
import time
import operator
from utils import TraceData, load_traces, writeLog, writeResultRow
import matplotlib.pyplot as plt
from datetime import datetime
from sklearn import metrics
import nltk
import itertools

TRAIN_SAMPLE_PERCENTAGE = 0.75

UNKNOWN_TOKEN = "UNKNOWN"
IN_SELECTION_TOKEN = "SELECTED"
NOT_IN_SELECTION_TOKEN = "NOT_SELECTED"

class Model:
    def __init__(self, case_name, dataset_name, algorithm, num_layers, 
                 optimizer, learning_rate, batch_size, 
                 num_callbacks, hidden_dim_size, num_iterations_between_reports,
                 grad_clipping, predict_only_outcome, final_trace_only, 
                 trace_length_modifier, max_num_words, truncate_unknowns, rng):
        writeLog("Using data set: " + dataset_name)
        self.algorithm = algorithm
        self.num_layers = num_layers
        self.optimizer = optimizer
        self.learning_rate = learning_rate
        self.batch_size = batch_size
        self.num_callbacks = num_callbacks
        self.traces = trace_registry[dataset_name](trace_length_modifier)
        self.dataset_size = len(self.traces)
        self.dataset_name = dataset_name
        self.case_name = case_name
        self.hidden_dim_size = hidden_dim_size
        self.num_iterations_between_reports = num_iterations_between_reports
        self.grad_clipping = grad_clipping
        self.rng = rng
        self.predict_only_outcome = predict_only_outcome
        self.final_trace_only = final_trace_only
        self.trace_length_modifier = trace_length_modifier
        self.max_num_words = max_num_words
        self.truncate_unknowns = truncate_unknowns
        lasagne.random.set_rng(rng)
        try:
            self.createModel()
        except:
            writeLog("Exception: " + sys.exc_info()[0])

    def gen_data(self, data, p, positions, batch_size, return_target=True):
        '''
        This function produces a semi-redundant batch of training samples from the location 'p' in the provided string (data).
        For instance, assuming SEQ_LENGTH = 5 and p=0, the function would create batches of 
        5 characters of the string (starting from the 0th character and stepping by 1 for each semi-redundant batch)
        as the input and the next character as the target.
        To make this clear, let us look at a concrete example. Assume that SEQ_LENGTH = 5, p = 0 and BATCH_SIZE = 2
        If the input string was "The quick brown fox jumps over the lazy dog.",
        For the first data point,
        x (the inputs to the neural network) would correspond to the encoding of 'T','h','e',' ','q'
        y (the targets of the neural network) would be the encoding of 'u'
        For the second point,
        x (the inputs to the neural network) would correspond to the encoding of 'h','e',' ','q', 'u'
        y (the targets of the neural network) would be the encoding of 'i'
        The data points are then stacked (into a three-dimensional tensor of size (batch_size,SEQ_LENGTH,vocab_size))
        and returned. 
        Notice that there is overlap of characters between the batches (hence the name, semi-redundant batch).
        '''
        data_size = len(positions)
        x = np.zeros((batch_size, self.seq_length, self.vocab_size))
        y = np.zeros(batch_size)
        masks = []
        for n in range(batch_size):
            ptr = (p + n) % data_size
            pos = positions[ptr]
            dt = data[pos[0]]
            for i in range(pos[1]):
                x[n, i, self.word_to_index[dt[i]]] = 1.
            masks.append([1 if x < pos[1] else 0 for x in range(self.seq_length)])
#!            if(return_target):
#!                y[n, self.word_to_index[dt[-1]] if self.predict_only_outcome else self.word_to_index[dt[pos[1] + 1]]] = 1
            if(return_target):
                y[n] = self.word_to_index[dt[-1]] if self.predict_only_outcome else self.word_to_index[dt[pos[1]]]
        return x, np.array(y,dtype='int32'), np.asarray(masks)

    def gen_prediction_data(self, traces, tracePercentage):
        batches = []
        masks = []
        numTraces = len(traces)
        if (numTraces == 0):
            return np.asarray(batches), np.asarray(masks)
        batchRow = 0
        x = np.zeros((self.batch_size if (numTraces > self.batch_size) else numTraces, self.seq_length, self.vocab_size))
        m = np.zeros((self.batch_size if (numTraces > self.batch_size) else numTraces, self.seq_length))
        batches.append(x)
        masks.append(m)

        for traceRow in range(len(traces)):
            trace = traces[traceRow]
            traceData = trace.getActivitiesForPrediction(self.word_to_index, tracePercentage, self.truncate_unknowns, self.seq_length, self.vocab_size)
            for i in range(len(traceData)):
                x[batchRow, i, traceData[i]] = 1.
            for i in range(self.seq_length):
                m[batchRow, i] = 1 if i < len(traceData) else 0
            batchRow += 1
            if (batchRow >= self.batch_size):
                x = np.zeros((self.batch_size if (numTraces - traceRow) > self.batch_size else (numTraces - traceRow - 1), self.seq_length, self.vocab_size))
                m = np.zeros((self.batch_size if (numTraces - traceRow) > self.batch_size else (numTraces - traceRow - 1), self.seq_length))
                batches.append(x)
                masks.append(m)
                batchRow = 0
        return np.asarray(batches), np.asarray(masks)


    def trainModel(self, callback):
        data_size = len(self.positions_train)
        writeLog("Training...")
        p = 0
        num_iterations = 0
        num_iterations_after_report = 0
        num_report_iterations = 1
        avg_cost = 0;
#        writeLog("It: " + str(data_size * self.num_epochs // self.batch_size))
        try:
            it = 0
            while (num_report_iterations <= self.num_callbacks):
                x, y, mask = self.gen_data(self.TS_train, p, self.positions_train, self.batch_size)
                it += 1
                p += self.batch_size 
                num_iterations += self.batch_size
                num_iterations_after_report += self.batch_size
#                if(p+self.batch_size+self.seq_length >= data_size):
#                    writeLog('Carriage Return')
#                    p = 0;
                avg_cost += self.train(x, y, mask)
                if (callback and num_iterations_after_report >= self.num_iterations_between_reports):
                    callback(num_iterations, it, avg_cost / it, num_report_iterations)
                    avg_cost = 0
                    num_iterations_after_report = num_iterations_after_report - self.num_iterations_between_reports
                    num_report_iterations = num_report_iterations + 1

#            callback(num_iterations, it, avg_cost / it, num_report_iterations)
        except KeyboardInterrupt:
            pass

    def initializeTraces(self):
        word_to_index = []
        index_to_word = []

        TRAIN_SIZE = int(self.dataset_size * TRAIN_SAMPLE_PERCENTAGE)
        TEST_SIZE = int(self.dataset_size * (1 - TRAIN_SAMPLE_PERCENTAGE))
        indexes = self.rng.permutation(self.dataset_size)
#        indexes = range(self.dataset_size)
        self.traces_train = self.traces[indexes[:TRAIN_SIZE]]
        self.traces_test = self.traces[indexes[TRAIN_SIZE:]]

        # Tokenize the sentences into words
        writeLog("Tokenizing %s sentences." % len(self.traces))
    #    tokenized_sentences = [nltk.word_tokenize(trace.sentence) for trace in traces]
        tokenized_sentences_train = [nltk.WhitespaceTokenizer().tokenize(trace.sentence) for trace in self.traces_train]
        tokenized_sentences = [nltk.WhitespaceTokenizer().tokenize(trace.sentence) for trace in self.traces]

        # Count the word frequencies
        word_freq = nltk.FreqDist(itertools.chain(*tokenized_sentences_train))
        writeLog("Found %d unique words tokens." % len(word_freq.items()))

        # Get the most common words and build index_to_word and word_to_index vectors
        vocab = sorted(word_freq.items(), key=lambda x: (x[1], x[0]), reverse=True)
        writeLog("Using vocabulary size %d." % len(vocab))
        writeLog("The least frequent word in our vocabulary is '%s' and appeared %d times." % (vocab[-1][0], vocab[-1][1]))

        words = []
        for x in vocab:
            w = x[0]
            if (w != IN_SELECTION_TOKEN and w != NOT_IN_SELECTION_TOKEN):
                words.append(w)
        words = np.asarray(words)

        if ((self.max_num_words != None) and (self.max_num_words < len(words))):
            words = words[range(self.max_num_words)]
            writeLog("Vocabulary was truncated to %d most frequent words in training set." % len(words))
        index_to_word = np.concatenate([[UNKNOWN_TOKEN, IN_SELECTION_TOKEN, NOT_IN_SELECTION_TOKEN], words])
        word_to_index = dict([(w, i) for i, w in enumerate(index_to_word)])
        self.seq_length = 0
        # Replace all words not in our vocabulary with the unknown token
        for i, sent in enumerate(tokenized_sentences):
            ts = [w if w in word_to_index else UNKNOWN_TOKEN for w in sent]
            if (self.truncate_unknowns):
                origts = ts
                ts = []
                wasUnknown = False
                for w in origts:
                    isUnknown = w == UNKNOWN_TOKEN
                    if ((not isUnknown) or (not wasUnknown)):
                        ts.append(w)
                    wasUnknown = isUnknown
            tokenized_sentences[i] = ts
            l = len(tokenized_sentences[i])
            if (l > self.seq_length):
                self.seq_length = l
        writeLog("Maximum sequence length is %d tokens." % (self.seq_length))
        self.word_to_index = word_to_index
        self.index_to_word = index_to_word
        self.vocab_size = len(self.word_to_index);

        tokenized_sentences = np.asarray(tokenized_sentences)
        self.TS_train = tokenized_sentences[indexes[:TRAIN_SIZE]]
        self.positions_train = []
        if (self.final_trace_only):
            for i, ts in enumerate(self.TS_train):
                l = len(ts)
                if l > 1:
                    self.positions_train.append([i, l - 1])
        else:
            for i, ts in enumerate(self.TS_train):
                l = len(ts)
                if l > 1:
                    for pos in range(l - 1):
                        self.positions_train.append([i, pos])
        
        self.TS_test = tokenized_sentences[indexes[TRAIN_SIZE:]]
        self.positions_test = []
        for i, ts in enumerate(self.TS_test):
            l = len(ts)
            if l > 1:
                for pos in range(l - 1):
                    self.positions_test.append([i, pos])

    def createModel(self):
        self.initializeTraces()

        writeLog("Preparing " + str(self.num_layers) + " layers for algorithm: " + self.algorithm)

        # First, we build the network, starting with an input layer
        # Recurrent layers expect input of shape
        # (batch size, SEQ_LENGTH, num_features)
        mask_var = T.matrix('mask')

        l_in = lasagne.layers.InputLayer(shape=(None, None, self.vocab_size))
        l_mask = lasagne.layers.InputLayer((None, None), mask_var)
        l_layers = [l_in]

        # We now build the LSTM layer which takes l_in as the input layer
        # We clip the gradients at GRAD_CLIP to prevent the problem of exploding gradients. 
        if (self.algorithm == "gru"):
            layerCreatorFunc = lambda parentLayer, isFirstLayer, isLastLayer: lasagne.layers.GRULayer(
                    parentLayer, self.hidden_dim_size, grad_clipping=self.grad_clipping,
                    mask_input = l_mask if isFirstLayer else None,
                    only_return_final=isLastLayer)
        else:
            # All gates have initializers for the input-to-gate and hidden state-to-gate
            # weight matrices, the cell-to-gate weight vector, the bias vector, and the nonlinearity.
            # The convention is that gates use the standard sigmoid nonlinearity,
            # which is the default for the Gate class.
#            gate_parameters = lasagne.layers.recurrent.Gate(
#                W_in=lasagne.init.Orthogonal(), W_hid=lasagne.init.Orthogonal(),
#                b=lasagne.init.Constant(0.))
#            cell_parameters = lasagne.layers.recurrent.Gate(
#                W_in=lasagne.init.Orthogonal(), W_hid=lasagne.init.Orthogonal(),
#                # Setting W_cell to None denotes that no cell connection will be used.
#                W_cell=None, b=lasagne.init.Constant(0.),
#                # By convention, the cell nonlinearity is tanh in an LSTM.
#                nonlinearity=lasagne.nonlinearities.tanh)

            layerCreatorFunc = lambda parentLayer, isFirstLayer, isLastLayer: lasagne.layers.LSTMLayer(
                    parentLayer, self.hidden_dim_size, grad_clipping=self.grad_clipping,
                    mask_input = l_mask if isFirstLayer else None,
                    nonlinearity=lasagne.nonlinearities.tanh,
                    # Here, we supply the gate parameters for each gate
#                    ingate=gate_parameters, forgetgate=gate_parameters,
#                    cell=cell_parameters, outgate=gate_parameters,
                    # We'll learn the initialization and use gradient clipping
                    only_return_final=isLastLayer)

        for layerId in range(self.num_layers):
            l_layers.append(layerCreatorFunc(l_layers[layerId], layerId == 0, layerId == self.num_layers - 1))

        # The output of l_forward_2 of shape (batch_size, N_HIDDEN) is then passed through the softmax nonlinearity to 
        # create probability distribution of the prediction
        # The output of this stage is (batch_size, vocab_size)
        l_out = lasagne.layers.DenseLayer(l_layers[len(l_layers) - 1], num_units=self.vocab_size, W = lasagne.init.Normal(), nonlinearity=lasagne.nonlinearities.softmax)
        l_layers.append(l_out)
        
        # Theano tensor for the targets
        target_values = T.ivector('target_output')
#!        target_var = T.matrix('target_output')
    
        # lasagne.layers.get_output produces a variable for the output of the net
        network_output = lasagne.layers.get_output(l_out)

        # https://github.com/Lasagne/Lasagne/blob/master/examples/recurrent.py
        # The network output will have shape (n_batch, 1); let's flatten to get a
        # 1-dimensional vector of predicted values
#        predicted_values = network_output.flatten()

#        flat_target_values = target_values.flatten()

        # Our cost will be mean-squared error
#        cost = T.mean((predicted_values - flat_target_values)**2)
#        cost = T.mean((network_output - target_values)**2)
        # The loss function is calculated as the mean of the (categorical) cross-entropy between the prediction and target.
#!        cost = T.nnet.categorical_crossentropy(network_output,target_var).mean()
        cost = T.nnet.categorical_crossentropy(network_output,target_values).mean()

        # Retrieve all parameters from the network
        all_params = lasagne.layers.get_all_params(l_out,trainable=True)

        # Compute AdaGrad updates for training
        writeLog("Computing updates...")
        writeLog("Using optimizer: " + self.optimizer)
        if (self.optimizer == "sgd"):
            updates = lasagne.updates.sgd(cost, all_params, self.learning_rate)
        elif (self.optimizer == "adagrad"):
            updates = lasagne.updates.adagrad(cost, all_params, self.learning_rate)
        elif (self.optimizer == "adadelta"):
            updates = lasagne.updates.adagrad(cost, all_params, self.learning_rate, 0.95)
        elif (self.optimizer == "momentum"):
            updates = lasagne.updates.momentum(cost, all_params, self.learning_rate, 0.9)
        elif (self.optimizer == "nesterov_momentum"):
            updates = lasagne.updates.nesterov_momentum(cost, all_params, self.learning_rate, 0.9)
        elif (self.optimizer == "rmsprop"):
            updates = lasagne.updates.rmsprop(cost, all_params, self.learning_rate, 0.9)
        else:
            updates = lasagne.updates.adam(cost, all_params, self.learning_rate, beta1=0.9, beta2=0.999)

        # Theano functions for training and computing cost
        writeLog("Compiling train function...")
        self.train = theano.function([l_in.input_var, target_values, l_mask.input_var], cost, updates=updates, allow_input_downcast=True)
#!        self.train = theano.function([l_in.input_var, target_var, l_mask.input_var], cost, updates=updates, allow_input_downcast=True)
        writeLog("Compiling train cost computing function...")
        self.compute_cost = theano.function([l_in.input_var, target_values, l_mask.input_var], cost, allow_input_downcast=True)
#!        self.compute_cost = theano.function([l_in.input_var, target_var, l_mask.input_var], cost, allow_input_downcast=True)

        # In order to generate text from the network, we need the probability distribution of the next character given
        # the state of the network and the input (a seed).
        # In order to produce the probability distribution of the prediction, we compile a function called probs. 
        writeLog("Compiling propabilities computing function...")
        self.propabilities = theano.function([l_in.input_var, l_mask.input_var],network_output,allow_input_downcast=True)

        self.start_time = time.time()
        self.previous_time = self.start_time
        self.cumul_train_time = 0
        self.cumul_test_time = 0
        self.auc = 0
        self.sr_trains = []
        self.sr_tests = []
        self.sr_tests_75p = []
        self.sr_tests_50p = []
        self.sr_tests_25p = []
        self.sr_examplesSeen = []
        self.time_used = []
        self.avg_costs = []
        self.time_used_for_test = []
        self.all_cms = []
        def predict_outcome(tracesToCalculateFor, selIndex, notSelIndex, tracePercentage):
            batches, masks = self.gen_prediction_data(tracesToCalculateFor, tracePercentage)
            correct = 0
            predictions = []
            probs_out = []
            for i in range(len(batches)):
                x = batches[i]
                mask = masks[i]
                probs = self.propabilities(x, mask)
                for prob in enumerate(probs):
                    selProb = prob[1][selIndex]
                    notSelProb = prob[1][notSelIndex]
                    probs_out.append(selProb / (selProb + notSelProb))
                    predictions.append(selProb >= notSelProb)
            return predictions, probs_out

        def calculateSuccessRate(tracesToCalculateFor, tracePercentage, testId):
            selIndex = self.word_to_index[IN_SELECTION_TOKEN]
            notSelIndex = self.word_to_index[NOT_IN_SELECTION_TOKEN]
            predictions, probs = predict_outcome(tracesToCalculateFor, selIndex, notSelIndex, tracePercentage)
            numSuccess = 0
            cm = [0, 0, 0, 0]
            exps = []
            for i in range(len(tracesToCalculateFor)):
                expected = tracesToCalculateFor[i].isSelected
                actual = predictions[i]
                exps.append(1 if expected else 0)
                numSuccess += 1 if expected == actual else 0
                cm[0] += 1 if expected and actual else 0
                cm[1] += 1 if not expected and not actual else 0
                cm[2] += 1 if not expected and actual else 0
                cm[3] += 1 if expected and not actual else 0
            self.cms[testId] = cm
            self.cms_str += ":%i_%i_%i_%i" % (cm[0], cm[1], cm[2], cm[3])
            if (testId == 1):
                self.auc = metrics.roc_auc_score(exps, probs)
            return numSuccess / len(tracesToCalculateFor)

        def report(num_examples_seen, it, avg_cost, num_report_iterations):
            t2 = time.time()
            tutrain = (t2 - self.previous_time)
            self.cumul_train_time = self.cumul_train_time + tutrain
            self.time_used.append(tutrain)
            self.generate_trace(5)
            self.sr_examplesSeen.append(num_examples_seen)
            self.cms = {}
            self.cms_str = ""
            writeLog("Testing 100% training samples")
            sr_train = calculateSuccessRate(self.traces_train, 1.0, 0)
            self.sr_trains.append(sr_train)
            writeLog("Testing 100% test samples")
            sr_test = calculateSuccessRate(self.traces_test, 1.0, 1)
            writeLog("Testing 75% test samples")
            sr_tests_75p = calculateSuccessRate(self.traces_test, 0.75, 2)
            writeLog("Testing 50% test samples")
            sr_tests_50p = calculateSuccessRate(self.traces_test, 0.5, 3)
            writeLog("Testing 25% test samples")
            sr_tests_25p = calculateSuccessRate(self.traces_test, 0.25, 4)
            self.sr_tests.append(sr_test)
            self.sr_tests_75p.append(sr_tests_75p)
            self.sr_tests_50p.append(sr_tests_50p)
            self.sr_tests_25p.append(sr_tests_25p)
            self.avg_costs.append(avg_cost)
            data_size = len(self.TS_train)
            epoch = it*self.batch_size/data_size
            t3 = time.time()
            tutest = (t3 - t2)
            self.cumul_test_time = self.cumul_test_time + tutest
            self.previous_time = t3
            self.time_used_for_test.append(tutest)
            self.all_cms.append(self.cms)
            writeLog("Iteration: %i (%i) Total time used: ~%f seconds (train: %f, test: %f)" % (num_report_iterations, num_examples_seen, (time.time() - self.start_time) * 1., self.cumul_train_time, self.cumul_test_time))
            writeLog("Epoch {} average loss = {}".format(epoch, avg_cost))
            writeLog("Success rates: test: %f test 75%%: %f test 50%%: %f test 25%%: %f train: %f" % (sr_test, sr_tests_75p, sr_tests_50p, sr_tests_25p, sr_train))
            writeResultRow([datetime.now().replace(microsecond=0).isoformat(), 
                "ok", "", self.case_name, self.dataset_name, self.dataset_size, 
                self.algorithm, self.num_layers, self.hidden_dim_size, 
                self.optimizer, self.learning_rate, self.seq_length, self.batch_size,
                self.grad_clipping, self.num_iterations_between_reports,
                num_report_iterations,
                num_examples_seen, epoch, tutrain, self.cumul_train_time, tutest, 
                self.cumul_test_time, sr_train, sr_test, sr_tests_75p, sr_tests_50p,
                sr_tests_25p,
                avg_cost, self.auc, self.cms[1][0], self.cms[1][1], self.cms[1][2], self.cms[1][3],
                str(self.cms_str),
                self.predict_only_outcome, self.final_trace_only, self.trace_length_modifier, 
                self.num_iterations_between_reports * self.num_callbacks == 100000 * 50, 
                self.max_num_words, self.truncate_unknowns])
#            self.draw_chart()
    
#        writeLog("Calculating initial probabilities.")
#        self.sr_examplesSeen.append(0)
        self.cms = {}
        self.cms_str = ""
#        sr_train = calculateSuccessRate(self.traces_train, 1.0, 0)
#        self.sr_trains.append(sr_train)
#        sr_test = calculateSuccessRate(self.traces_test, 1.0, 1)
#        self.sr_tests.append(sr_test)
#        self.time_used.append(time.time() - self.start_time)
#        self.avg_costs.append(0)
#        writeLog("Initial success rates: test: %f  train: %f" % (sr_test, sr_train))
    
        num_examples_seen = self.trainModel(report)
    
        self.cms = {}
        self.cms_str = ""
        self.sr_examplesSeen.append(num_examples_seen)
        sr_train = calculateSuccessRate(self.traces_train, 1.0, 0)
        self.sr_trains.append(sr_train)
        sr_test = calculateSuccessRate(self.traces_test, 1.0, 1)
        self.sr_tests.append(sr_test)
        self.avg_costs.append(0)
        writeLog("Final success rates: test: %f  train: %f" % (sr_test, sr_train))
        self.time_used.append(self.cumul_train_time)
#        self.draw_chart()

    def draw_chart(self):
        plt.plot(self.sr_examplesSeen, self.sr_trains, label = 'Train data')
        plt.plot(self.sr_examplesSeen, self.sr_tests, label = 'Test data')
        plt.plot(self.sr_examplesSeen, self.avg_costs, label = 'Avg. Cost')
        plt.xlabel('iterations')
        plt.ylabel('Success rate')
        plt.title('Classification prediction success rate - ' + self.case_name)
        plt.legend()    
        plt.show()

    def generate_trace(self, min_length=5):
        # We start the sentence with the start token
        x = np.zeros((1, self.seq_length, self.vocab_size))
        mask = np.zeros((1, self.seq_length))
        new_sentence = []
        i = 0
        # Repeat until we get an end token
        selIndex = self.word_to_index[IN_SELECTION_TOKEN]
        notSelIndex = self.word_to_index[NOT_IN_SELECTION_TOKEN]
        while not ((len(new_sentence) > 0) and ((new_sentence[-1] == selIndex) or (new_sentence[-1] == notSelIndex))):
            probs = self.propabilities(x, mask)[0]
#            samples = np.random.multinomial(1, probs)
#            index = np.argmax(samples)
            index = np.random.choice(range(len(probs)), p=probs)
            new_sentence.append(index)
            x[0, i, index] = 1
            mask[0, i] = 1
            i += 1

            # Seomtimes we get stuck if the sentence becomes too long, e.g. "........" :(
            # And: We don't want sentences with UNKNOWN_TOKEN's
            if len(new_sentence) >= self.seq_length or index == self.word_to_index[UNKNOWN_TOKEN]:
                writeLog("Generated exceedingly long example trace. Skipping.") 
                return None
        if len(new_sentence) < min_length:
            return None
        res = [self.index_to_word[x] for x in new_sentence]
        writeLog("Generated example trace of length %d: %s" % (len(res), str(res))) 
        return res

    def write_csv(self, name, csvwriter):
        for i in range(len(self.sr_examplesSeen)):
            csvwriter.writerow([self.case_name, self.sr_examplesSeen[i], 
                                self.time_used[i], self.sr_trains[i], self.sr_tests[i], 
                                self.avg_costs[i], self.optimizer, self.hidden_dim_size, 
                                self.dataset_size])

trace_registry = {
}
    