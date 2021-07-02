#
# This script runs knn on the requested datasets, combines the results with
# the provided weights, then outputs a list of nearest bugs|srs|certs along
# with their distances.
#
# Inputs: 1) directory containing feature files (named $datatype.tmp)
#         2) output type (srs|bugs|certs) dataset file
#         3) dataset file1, distance metric1, weight1
#         4) (optional) dataset file2, distance metric2, weight2
#         ...
#
# Output: List of SRs or bugs along with their nearest neighbor distances
#

from __future__ import print_function

import getopt
import sys
import os
import pandas as pd
from sklearn.neighbors import NearestNeighbors
import knn 

def usage():
    print("Usage: " + sys.argv[0] + " [-d(ebug)] feature_files_dir outtype_dataset_file dataset_file1 distance_metric1 weight1 dataset_file2 distance_metric2 weight2 ...", file=sys.stderr)

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
        print("Feature directory does not exist: ", argv[arg_index_start], file=sys.stderr)
        usage()
        sys.exit(2)
    if os.path.isfile(argv[arg_index_start + 1]):
        outtype_dataset_file = argv[arg_index_start + 1]
    else:
        print("Out type datafile does not exist: ", argv[arg_index_start + 1], file=sys.stderr)
        usage()
        sys.exit(2)
    i = 2
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
            print("Input datatype file does not exist: ", argv[arg_index_start + i], file=sys.stderr)
            usage()
            sys.exit(2)
        if argv[arg_index_start + (i + 1)]:
            dist_metrics.append(argv[arg_index_start + (i + 1)])
        else:
            print("No distance metric provided for ", argv[arg_index_start + i], file=sys.stderr)
            usage()
            sys.exit(2)
        if argv[arg_index_start + (i + 2)]:
            weights.append(argv[arg_index_start + (i + 2)])
        else:
            print("No weight provided for ", argv[arg_index_start + i], file=sys.stderr)
            usage()
            sys.exit(2)
        i = i + 3
    outtype_col_name  = "Id"
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": datatypes:", datatypes, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": dist_metrics:", dist_metrics, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": weights:", weights, file=sys.stderr)

    total_ids_scores = []
    for datatype_num in range(len(datatypes)):
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": datatype_num:", datatype_num, file=sys.stderr)
        features_file = feature_files_dir + "/" + datatypes[datatype_num] + ".tmp"
        if not os.path.isfile(features_file):
            print("Features file does not exist: ", features_file, file=sys.stderr)
            sys.exit(2)
        knn_args = features_file + " " + outtype_dataset_file + " " + datatype_filenames[datatype_num] + " " + dist_metrics[datatype_num] + " false"
        ids_scores = knn.main(knn_args.split())
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": ids_scores:", ids_scores, file=sys.stderr)
        total_ids_scores = total_ids_scores + ids_scores
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": total_ids_scores:", total_ids_scores, file=sys.stderr)

    new_total_ids_scores = []
    for id_score in total_ids_scores:
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": id_score:", id_score, file=sys.stderr)
        found = "FALSE" 
        for new_id_score in new_total_ids_scores:
            if new_id_score[0] == id_score[0]:
                new_id_score[1] = new_id_score[1] + id_score[1]
                found = "TRUE"
                break
        if found == "FALSE":
            new_total_ids_scores.append(id_score)
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": new_total_ids_scores:", new_total_ids_scores, file=sys.stderr)
    for id_score in new_total_ids_scores:
        id_score[1] = id_score[1]/len(datatypes)
    new_total_ids_scores.sort(key=lambda x:x[1],reverse=True)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": new_total_ids_score:", new_total_ids_scores, file=sys.stderr)
    return(new_total_ids_scores)

if __name__ == "__main__":
    ret_val = main(sys.argv[1:])
    print(ret_val)
