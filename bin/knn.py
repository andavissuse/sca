#
# This script analyzes a dataset to find the nearest neighbors to the given
# feature value(s).  
#
# Inputs: 1) class file
#         2) dataset file
#         3) feature file
#         4) distance metric
#         5) cutoff radius
#
# Output: pandas dataframe (md5sum, class_id, score) of nearest neighbors
#

from __future__ import print_function

import getopt
import sys
import numpy as np
import pandas as pd
import subprocess
from sklearn.neighbors import NearestNeighbors
from collections import OrderedDict

def usage():
    print("Usage: knn.py [-d(ebug)] class_file dataset_file feature_file distance_metric cutoff_radius", file=sys.stderr)

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
    class_file = argv[arg_index_start]
    dataset_file = argv[arg_index_start + 1]
    feature_file = argv[arg_index_start + 2]
    dist_metric = argv[arg_index_start + 3]
    cutoff_radius = argv[arg_index_start + 4]
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: class_file:", class_file, file=sys.stderr)
        print("*** DEBUG: knn.py: dataset_file:", dataset_file, file=sys.stderr)
        print("*** DEBUG: knn.py: feature_file:", feature_file, file=sys.stderr)
        print("*** DEBUG: knn.py: dist_metric:", dist_metric, file=sys.stderr)
        print("*** DEBUG: knn.py: cutoff_radius:", cutoff_radius, file=sys.stderr)

    # read the dataset
    df_dataset = pd.read_csv(dataset_file, sep=" ", dtype={'000_md5sum': str})
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: df_dataset:\n", df_dataset, file=sys.stderr)
    df_class = pd.read_csv(class_file, sep=" ", dtype={'000_md5sum': str, 'Id': str})
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: df_class:\n", df_class, file=sys.stderr)
    df = pd.merge(df_dataset, df_class, on='000_md5sum', how='inner')
    if df.empty:
        if DEBUG == "TRUE":
            print("*** DEBUG: knn.py: df is empty", file=sys.stderr)
        return []
    df.fillna(0, inplace = True)
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: df:\n", df, file=sys.stderr)

    # create the feature vector (and add columns for unknowns to df dataframe)
    feature_binvals = [0] * (len(df.columns) - 2)
    feature_vals = subprocess.getoutput("cat %s" % feature_file).split()
    num_feature_vals = len(feature_vals)
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: feature_vals:", feature_vals, file=sys.stderr)
    for feature_val in feature_vals:
        if DEBUG == "TRUE":
            print("*** DEBUG: knn.py: feature_val:", feature_val, file=sys.stderr)
        if feature_val in df.columns.values:
            matching_col_num = df.columns.get_loc(feature_val)
            if DEBUG == "TRUE":
                print("*** DEBUG: knn.py: matching_col_num:", matching_col_num, file=sys.stderr)
            feature_binvals[matching_col_num - 1] = 1
        else:
            if DEBUG == "TRUE":
                print("*** DEBUG: knn.py: no matching column for:", feature_val, file=sys.stderr)
            feature_binvals.append(1)
            df.insert((len(df.columns) - 1), feature_val, 0)
    feature_vector = np.array(feature_binvals)
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: feature_vector:", feature_vector, file=sys.stderr)
        print("*** DEBUG: knn.py: feature_vector size:", feature_vector.shape, file=sys.stderr)

    # initialize nearest neighbors
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: initializing nearest neighbors...", file=sys.stderr)
    neigh = NearestNeighbors(metric=dist_metric)
    df_cols = len(df.columns)
    df_rows = len(df)
    Inputs_df = df.iloc[:, 1:df_cols - 1]
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: Inputs_df:\n", Inputs_df, file=sys.stderr)
    neigh.fit(Inputs_df)

    # find nearest neighbors in cutoff radius, change distance to score, return in pandas dataframe
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: finding matches in radius", cutoff_radius, file=sys.stderr)
    nns = neigh.radius_neighbors(feature_vector.reshape(1, -1), radius=cutoff_radius, return_distance=True, sort_results=True)
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: nns:\n", nns, file=sys.stderr)
    nn_dists = np.asarray(nns[0][0])
    nn_inds = np.asarray(nns[1][0])
    num_nns = len(nn_inds)
    list_nns = []
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: nn_dists:", nn_dists, file=sys.stderr)
        print("*** DEBUG: knn.py: nn_inds:", nn_inds, file=sys.stderr)
        print("*** DEBUG: knn.py: num_nns:", num_nns, file=sys.stderr)
    for i in range(num_nns):
        ind = nn_inds[i]
        md5sum = df.at[nn_inds[i], '000_md5sum']
        class_id = df.at[nn_inds[i], 'Id']
        dist = nn_dists[i]
        list_nns_entry = [md5sum, class_id, (1 - dist)]
        list_nns.append(list_nns_entry)
    if DEBUG == "TRUE":
        print("*** DEBUG: knn.py: list_nns:", list_nns, file=sys.stderr)
    
    df_nns = pd.DataFrame(list_nns, columns = ['md5sum', 'Id', 'Score'])
    return(df_nns)

if __name__ == "__main__":
    ret_val = main(sys.argv[1:])
    print(ret_val)
