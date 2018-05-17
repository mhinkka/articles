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
from utils import load_traces, generate_traces, draw_charts, configure
from model import Model, trace_registry
import matplotlib.pyplot as plt

configure(output_path = "C:/Users/User/Dropbox/Aalto/testing/testruns/")
filePath = "D:/dev/aalto/papers/nn-predictions/src/"

trace_registry["bpic14_dur"] = lambda trace_length_modifier: load_traces("bpic14_dur", filePath + "rabobank.csv", lambda row: row[1] == "1", trace_length_modifier, 40000)
trace_registry["bpic14_rfi"] = lambda trace_length_modifier: load_traces("bpic14_rfi", filePath + "rabobank.csv", lambda row: row[2] == "request for information", trace_length_modifier, 40000)
trace_registry["bpic12_dur"] = lambda trace_length_modifier: load_traces("bpic12_dur", filePath + "BPIC12.csv", lambda row: row[1] == "1", trace_length_modifier)
trace_registry["bpic13_dur"] = lambda trace_length_modifier: load_traces("bpic13_dur", filePath + "BPIC13.csv", lambda row: row[1] == "1", trace_length_modifier)
trace_registry["bpic17_dur"] = lambda trace_length_modifier: load_traces("bpic17_dur", filePath + "BPIC17.csv", lambda row: row[1] == "1", trace_length_modifier)
trace_registry["hospital_dur"] = lambda trace_length_modifier: load_traces("hospital_dur", filePath + "HospitalLog.csv", lambda row: row[1] == "1", trace_length_modifier)
    
results = []
random_seed = 123

def test_dataset(dataset_name):
    def test_algorithm(algorithm):
        global results
        global random_seed
        case_name = "test"
        num_layers = 1
        optimizer = "adam"
        learning_rate = 0.01
        batch_size = 256
        num_callbacks = 50
        hidden_dim_size = 32
        num_iterations_between_reports = 100000
        grad_clipping = 100
        predict_only_outcome = True
        final_trace_only = True
        trace_length_modifier = 1.0
        truncate_unknowns = False
        max_num_words = 50

        results = Model(
                case_name = case_name, 
                dataset_name = dataset_name, 
                algorithm = algorithm, 
                num_layers = num_layers, 
                optimizer = optimizer, 
                learning_rate = learning_rate, 
                batch_size = batch_size, 
                num_callbacks = num_callbacks,
                hidden_dim_size = hidden_dim_size,
                num_iterations_between_reports = num_iterations_between_reports,
                grad_clipping = grad_clipping,
                predict_only_outcome = predict_only_outcome,
                final_trace_only = final_trace_only,
                trace_length_modifier = trace_length_modifier,
                max_num_words = max_num_words,
                truncate_unknowns = truncate_unknowns,
                rng = np.random.RandomState(random_seed))
        results = Model(
                case_name = case_name, 
                dataset_name = dataset_name, 
                algorithm = algorithm, 
                num_layers = num_layers, 
                optimizer = optimizer, 
                learning_rate = learning_rate, 
                batch_size = batch_size, 
                num_callbacks = num_callbacks,
                hidden_dim_size = hidden_dim_size,
                num_iterations_between_reports = num_iterations_between_reports,
                grad_clipping = grad_clipping,
                predict_only_outcome = predict_only_outcome,
                final_trace_only = final_trace_only,
                trace_length_modifier = 0.5,
                max_num_words = max_num_words,
                truncate_unknowns = truncate_unknowns,
                rng = np.random.RandomState(random_seed))
        results = Model(
                case_name = case_name, 
                dataset_name = dataset_name, 
                algorithm = algorithm, 
                num_layers = num_layers, 
                optimizer = optimizer, 
                learning_rate = learning_rate, 
                batch_size = batch_size, 
                num_callbacks = num_callbacks,
                hidden_dim_size = hidden_dim_size,
                num_iterations_between_reports = num_iterations_between_reports,
                grad_clipping = grad_clipping,
                predict_only_outcome = predict_only_outcome,
                final_trace_only = False,
                trace_length_modifier = trace_length_modifier,
                max_num_words = max_num_words,
                truncate_unknowns = truncate_unknowns,
                rng = np.random.RandomState(random_seed))
        results = Model(
                case_name = case_name, 
                dataset_name = dataset_name, 
                algorithm = algorithm, 
                num_layers = num_layers, 
                optimizer = optimizer, 
                learning_rate = learning_rate, 
                batch_size = batch_size, 
                num_callbacks = num_callbacks,
                hidden_dim_size = hidden_dim_size,
                num_iterations_between_reports = num_iterations_between_reports,
                grad_clipping = grad_clipping,
                predict_only_outcome = False,
                final_trace_only = final_trace_only,
                trace_length_modifier = trace_length_modifier,
                max_num_words = max_num_words,
                truncate_unknowns = truncate_unknowns,
                rng = np.random.RandomState(random_seed))
        results = Model(
                case_name = case_name, 
                dataset_name = dataset_name, 
                algorithm = algorithm, 
                num_layers = num_layers, 
                optimizer = optimizer, 
                learning_rate = learning_rate, 
                batch_size = batch_size, 
                num_callbacks = num_callbacks,
                hidden_dim_size = hidden_dim_size,
                num_iterations_between_reports = num_iterations_between_reports,
                grad_clipping = grad_clipping,
                predict_only_outcome = False,
                final_trace_only = False,
                trace_length_modifier = trace_length_modifier,
                max_num_words = max_num_words,
                truncate_unknowns = truncate_unknowns,
                rng = np.random.RandomState(random_seed))
        results = Model(
                case_name = case_name, 
                dataset_name = dataset_name, 
                algorithm = algorithm, 
                num_layers = num_layers, 
                optimizer = optimizer, 
                learning_rate = learning_rate, 
                batch_size = batch_size, 
                num_callbacks = num_callbacks,
                hidden_dim_size = 16,
                num_iterations_between_reports = num_iterations_between_reports,
                grad_clipping = grad_clipping,
                predict_only_outcome = predict_only_outcome,
                final_trace_only = final_trace_only,
                trace_length_modifier = trace_length_modifier,
                max_num_words = max_num_words,
                truncate_unknowns = truncate_unknowns,
                rng = np.random.RandomState(random_seed))
    test_algorithm("gru")
    test_algorithm("lstm")

test_dataset("bpic14_dur")
test_dataset("bpic14_rfi")
test_dataset("bpic12_dur")
test_dataset("bpic13_dur")
test_dataset("bpic17_dur")
test_dataset("hospital_dur")
