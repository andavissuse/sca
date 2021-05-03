#
# This script runs knn-classifier on the requested datasets, averages the results
# using the provided weights, then outputs a value of 1 or 0 to indicate the
# existence of an sr|bug|cert.
#
# Inputs: 1) directory containing feature files (named $datatype.tmp)
#         2) output type (srs|bugs|certs) dataset file
#         3) dataset file1, distance metric1, weight1
#         4) (optional) dataset file2, distance metric2, weight2
#         ...
#
# Output: 1 or 0 depending on whether the nearest neighbor analysis predicts
#         the existence of an SR or bug 
#

import getopt
import sys
import os
import pandas as pd
from sklearn.neighbors import NearestNeighbors
import knn_classifier 

def usage():
    print("Usage: " + sys.argv[0] + " [-d(ebug)] feature_files_dir outtype_dataset_file dataset_file1 distance_metric1 weight1 dataset_file2 distance_metric2 weight2 ...")

def main(argv):
    arg_index_start = 0
    DEBUG = "FALSE"
    try:
        opts, args = getopt.getopt(argv, 'd', ['debug'])
        if not args:
            usage()
            sys.exit(2)
    except getopt.GetoptError as err:
        usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt in ('-d'):
            DEBUG = "TRUE"
            arg_index_start = 1

    # arguments
    if not argv[arg_index_start + 4]:
        usage()
        sys.exit(2)
    if os.path.isdir(argv[arg_index_start]):
        feature_files_dir = argv[arg_index_start]
    else:
        print("Feature directory does not exist: ", argv[arg_index_start])
        usage()
        sys.exit(2)
    if os.path.isfile(argv[arg_index_start + 1]):
        outtype_dataset_file = argv[arg_index_start + 1]
    else:
        print("Out type datafile does not exist: ", argv[arg_index_start + 1])
        usage()
        sys.exit(2)
    i = 2
    debug_opt = ""
    datatype_filenames = []
    datatypes = []
    dist_metrics = []
    weights = []
    while i < len(args):
        if os.path.isfile(argv[arg_index_start + i]):
            datatype_filename = argv[arg_index_start + i]
            datatype_filenames.append(datatype_filename)
            datatype = os.path.basename(datatype_filename.rsplit('-', 1)[0])
            datatypes.append(datatype)
        else:
            print("Input datatype file does not exist: ", argv[arg_index_start + i])
            usage()
            sys.exit(2)
        if argv[arg_index_start + (i + 1)]:
            dist_metrics.append(argv[arg_index_start + (i + 1)])
        else:
            print("No distance metric provided for ", argv[arg_index_start + i])
            usage()
            sys.exit(2)
        if argv[arg_index_start + (i + 2)]:
            weights.append(argv[arg_index_start + (i + 2)])
        else:
            print("No weight provided for ", argv[arg_index_start + i])
            usage()
            sys.exit(2)
        i = i + 3
    outtype_col_name  = "Id"
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": datatypes:", datatypes)
        print("*** DEBUG: " + sys.argv[0] + ": dist_metrics:", dist_metrics)
        print("*** DEBUG: " + sys.argv[0] + ": weights:", weights)

    cumulative_prediction = 0
    for datatype_num in range(len(datatypes)):
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": datatype_num:", datatype_num)
            print("*** DEBUG: " + sys.argv[0] + ": datatype:", datatypes[datatype_num])
        features_file = feature_files_dir + "/" + datatype + ".tmp"
        if not os.path.isfile(features_file):
            print("Features file does not exist: ", features_file)
            sys.exit(2)
        if DEBUG == "TRUE":
            debug_opt = "-d "
        knn_args = debug_opt + features_file + " " + outtype_dataset_file + " " + datatype_filenames[datatype_num] + " " + dist_metrics[datatype_num]
        prediction = knn_classifier.main(knn_args.split())
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": prediction:", prediction)
        cumulative_prediction = cumulative_prediction + prediction
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": cumulative_prediction:", cumulative_prediction)
    avg_prediction = cumulative_prediction/(len(datatypes))
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": avg_prediction:", avg_prediction)
    if avg_prediction < 0.5:
        final_prediction = 0
    else:
        final_prediction = 1
    return(final_prediction)

if __name__ == "__main__":
    ret_val = main(sys.argv[1:])
    print(ret_val)
