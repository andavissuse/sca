#
# This script runs knn on the requested datasets, combines the results with
# the provided weights, then outputs a list of nearest bugs|srs|certs along
# with their distances.
#
# Input:  1) class file
#         2) dataset file 1
#         3) feature file 1
#         4) distance metric 1
#         5) radius 1
#         6) weight 1
#         7) (optional) dataset file 2
#         8) (optional) feature file 2
#         9) (optional) distance metric 2
#         ...
#
# Output: List of class matches along with their nearest neighbor distances
#

from __future__ import print_function

import getopt
import sys
import os
import numpy as np
import pandas as pd
from sklearn.neighbors import NearestNeighbors
from functools import reduce
import knn 

def usage():
    print("Usage: " + sys.argv[0] + " [-d(ebug)] class_file dataset_file_1 feature_file_1 distance_metric_1 radius_1 weight_1 dataset_file_2 feature_file_2 distance_metric_2 radius_2 weight_2 ...", file=sys.stderr)

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
    if not argv[arg_index_start + 5]:
        usage()
        sys.exit(2)
    class_file = argv[arg_index_start]
    dataset_files = []
    feature_files = []
    dist_metrics = []
    radii = []
    weights = []
    for i in range(arg_index_start + 1, len(args), 5):
        dataset_files.append(argv[i])
        feature_files.append(argv[i + 1])
        dist_metrics.append(argv[i + 2])
        radii.append(argv[i + 3])
        weights.append(argv[i + 4])
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": class_file:", class_file, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": dataset_files:", dataset_files, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": feature_files:", feature_files, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": dist_metrics:", dist_metrics, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": radii:", radii, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": weights:", weights, file=sys.stderr)

    # get nearest neighbor results from each dataset, put into pandas arrays
    df_total_nns = pd.DataFrame() 
    for dataset_num in range(len(dataset_files)):
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": dataset_num:", dataset_num, file=sys.stderr)
            knn_args = "-d " + class_file + " " + dataset_files[dataset_num] + " " + feature_files[dataset_num] + " " + dist_metrics[dataset_num] + " " + radii[dataset_num]
            print("*** DEBUG: " + sys.argv[0] + ": knn_args:", knn_args, file=sys.stderr)
        else:
            knn_args = class_file + " " + dataset_files[dataset_num] + " " + feature_files[dataset_num] + " " + dist_metrics[dataset_num] + " " + radii[dataset_num]
        df_knn_result = knn.main(knn_args.split())
        df_knn_result = df_knn_result.sort_values('Score', ascending='False').drop_duplicates(subset='Id', keep='first')
#        df_knn_result.columns = df_knn_result.iloc[0]
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": df_knn_result:", df_knn_result, file=sys.stderr)
        df_total_nns = df_total_nns.append(df_knn_result)
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": df_total_nns:", df_total_nns, file=sys.stderr)
    # inner-join all results
#    df_merged = reduce(lambda left,right: pd.merge(left, right, on=['md5sum', 'Id']), dfs_nns)
#    df_merged = dfs_nns[0]
#    for dataset_num in range(len(dataset_files) - 1):
#        dfs_to_merge = [df_merged, dfs_nns[dataset_num + 1]]
#        df_merged = reduce(lambda left, right: pd.merge(left, right, on=['md5sum', 'Id']), dfs_to_merge)
#        df_merged['Score'] = df_merged['Score_x'] + df_merged['Score_y']
#        df_merged.drop(columns=['Score_x', 'Score_y'], inplace=True)
#        if DEBUG == "TRUE":
#            print("*** DEBUG: " + sys.argv[0] + ": df_merged:", df_merged, file=sys.stderr)
#    aggregation_functions = {'Score': 'sum'}
#    df_scored = df_merged.groupby(df_merged['Id']).aggregate(aggregation_functions)
#    df_scored['Score'] = df_scored['Score'].div(len(dataset_files)).round(2)
#    df_scored = df_scored.sort_values(by=['Score'], ascending=False)
#    if DEBUG == "TRUE":
#        print("*** DEBUG: " + sys.argv[0] + ": df_scored:", df_scored, file=sys.stderr)
#    scored_list = df_scored.reset_index().values.tolist()
#    if DEBUG == "TRUE":
#        print("*** DEBUG: " + sys.argv[0] + ": scored_list:", scored_list, file=sys.stderr)
#    return(scored_list)

#    dfs_nns = pd.DataFrame(list_nns, index='md5sum')
#    if DEBUG == "TRUE":
#        print("*** DEBUG: " + sys.argv[0] + ": dfs_nns:", dfs_nns, file=sys.stderr)
    df_total_nns = df_total_nns.drop(columns=['md5sum'])
    df_total_nns = df_total_nns.set_index('Id')
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_total_nns:", df_total_nns, file=sys.stderr)
    df_total_nns = df_total_nns.groupby(['Id'])[['Score']].agg('sum')
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_total_nns after groupby:", df_total_nns, file=sys.stderr)
    df_total_nns = df_total_nns.sort_values(by=['Score'], ascending=False)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_total_nns sorted:", df_total_nns, file=sys.stderr)
    np_total_nns = df_total_nns.to_records()
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": np_total_nns:", np_total_nns, file=sys.stderr)
    list_total_nns = np_total_nns.tolist()
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": list_total_nns:", list_total_nns, file=sys.stderr)


#    return(list_total_nns_combined)
    return(list_total_nns)

if __name__ == "__main__":
    ret_val = main(sys.argv[1:])
    print(ret_val)
