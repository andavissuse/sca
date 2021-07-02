#
# This script analyzes a dataset to find nearest neighbors, then outputs
# the distance for the neighbors along with the requested output type
# (srs|bugs|certs) associated with the neighbors. Returns all exact-match
# neighbors + 5 nearest neighbors.
#
# Inputs: 1) supportconfig feature info to be matched (provided as a file)
#         2) output type (srs|bugs|certs) dataset file
#         3) input dataset file
#         4) distance metric
#         5) exact_matches_only ("true" or "false"; "true" will return exact matches only)
#
# Output: Nearest neighbor bugs|srs|certs along with score between 0 and 1.
#         Higher score indicates a better match.
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
    print("Usage: " + sys.argv[0] + " [-d(ebug)] sc_features_file outtype_dataset_file dataset_file distance_metric exact_matches_only", file=sys.stderr)

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
    sc_features_file = argv[arg_index_start]
    outtype_dataset_file = argv[arg_index_start + 1]
    dataset_file = argv[arg_index_start + 2]
    dist_metric = argv[arg_index_start + 3]
    exact_matches_only = argv[arg_index_start + 4]
    outtype_col_name  = "Id"

    # load datasets and build the combined dataframe
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": sc_features_file:", sc_features_file, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": outtype_dataset_file:", outtype_dataset_file, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": dataset_file:", dataset_file, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": dist_metric:", dist_metric, file=sys.stderr)
    dataset_df = pd.read_csv(dataset_file, sep=" ", dtype={'000_md5sum': str})
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": dataset_df:\n", dataset_df, file=sys.stderr)
    outtype_dataset_df = pd.read_csv(outtype_dataset_file, sep=" ", dtype={'000_md5sum': str, outtype_col_name: str})
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": outtype_dataset_df:\n", outtype_dataset_df, file=sys.stderr)
    df = pd.merge(dataset_df, outtype_dataset_df, on='000_md5sum', how='inner')
    if df.empty:
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": df is empty", file=sys.stderr)
        return []
    df.fillna(0, inplace = True)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df:\n", df, file=sys.stderr)

    # create the sc vector (and add columns for unknowns to df dataframe)
    sc_bin_list = [0] * (len(df.columns) - 2)
    sc_features_list = subprocess.getoutput("cat %s" % sc_features_file).split()
    num_sc_features = len(sc_features_list)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": sc_features:", sc_features_list, file=sys.stderr)
    for feature in sc_features_list:
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": feature:", feature, file=sys.stderr)
        if feature in df.columns.values:
            matching_col_num = df.columns.get_loc(feature)
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": matching_col_num:", matching_col_num, file=sys.stderr)
            sc_bin_list[matching_col_num - 1] = 1
        else:
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": no matching column for:", feature, file=sys.stderr)
            sc_bin_list.append(1)
            df.insert((len(df.columns) - 1), feature, 0)
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": sc_bin_list:", sc_bin_list, file=sys.stderr)
    sc_array = np.array(sc_bin_list)

    # initialize nearest neighbors
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": initializing nearest neighbors...", file=sys.stderr)
    neigh = NearestNeighbors(metric=dist_metric)
    df_cols = len(df.columns)
    df_rows = len(df)
    Inputs_df = df.iloc[:, 1:df_cols - 1]
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": Inputs_df:\n", Inputs_df, file=sys.stderr)
#    outputs_df = df.loc[:, [outtype_col_name]]
#    outputs_array = outputs_df.values.ravel()
#    outputs_array = outputs_array.astype('str')
#    if DEBUG == "TRUE":
#        print("*** DEBUG: knn.py: outputs_array: ", outputs_array)
    neigh.fit(Inputs_df)

    # find all exact matches
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": finding exact matches...", file=sys.stderr)
    out_list = []
    new_out_list = []
    exact_match_radius = 0.0
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": sc_array:", sc_array, file=sys.stderr)
    neigh_exact_matches = neigh.radius_neighbors(sc_array.reshape(1, -1), radius=exact_match_radius)
    neigh_exact_match_dists = np.asarray(neigh_exact_matches[0][0])
    neigh_exact_match_inds = np.asarray(neigh_exact_matches[1][0])
    num_exact_matches = len(neigh_exact_match_inds)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": num_exact_matches:", num_exact_matches, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": neigh_exact_match_inds:", neigh_exact_match_inds, file=sys.stderr)
        print("*** DEBUG: " + sys.argv[0] + ": neigh_exact_match_dists:", neigh_exact_match_dists, file=sys.stderr)
        for i in range(num_exact_matches):
            print("*** DEBUG: " + sys.argv[0] + ": neigh_exact_match_md5sum:", df.at[neigh_exact_match_inds.item(i), '000_md5sum'], file=sys.stderr)
    
    # continue with exact matches or get add'l 5 nearest matches (depending on exact_matches_only argument)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": continuing with exact matches or finding add'l nearest matches...", file=sys.stderr)
    if exact_matches_only == "true":
        for i in range(num_exact_matches):
            out_list.append(df.iat[neigh_exact_match_inds.item(i), df_cols - 1])
            new_out_list = list(OrderedDict.fromkeys(out_list)) 
    else:
        if (df_rows - num_exact_matches) < 5:
            num_neighbors = df_rows
        else:
            num_neighbors = num_exact_matches + 5
        neigh_dists, neigh_inds = neigh.kneighbors(sc_array.reshape(1, -1), num_neighbors)
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": neigh_inds:", neigh_inds, file=sys.stderr)
            print("*** DEBUG: " + sys.argv[0] + ": neigh_dists:", neigh_dists, file=sys.stderr)
        for i in range(num_neighbors):
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": neigh_md5sum:", df.at[neigh_inds.item(i), '000_md5sum'], file=sys.stderr)
            score = 1 - neigh_dists.item(i)
            if (score > 0):
                out_list.append([df.iat[neigh_inds.item(i), df_cols - 1], score])
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": out_list:", out_list, file=sys.stderr)
        # clean up the list to account for duplicates and sort by score
        new_out_list = []
        for out_list_entry in out_list:
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": out_list_entry:", out_list_entry, file=sys.stderr)
            found = "FALSE"
            for new_out_list_entry in new_out_list:
                if DEBUG == "TRUE":
                    print("*** DEBUG: " + sys.argv[0] + ": new_out_list_entry:", new_out_list_entry, file=sys.stderr)
                if new_out_list_entry[0] == out_list_entry[0]:
                    new_out_list_entry[1] = new_out_list_entry[1] + out_list_entry[1]
                    if new_out_list_entry[1] > 1:
                        new_out_list_entry[1] = 1.0
                    found = "TRUE"
                    break
            if found == "FALSE":
                new_out_list.append(out_list_entry)
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": new_out_list:", new_out_list, file=sys.stderr)
        new_out_list.sort(key=lambda x:x[1], reverse=True)

    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": new_out_list:", new_out_list, file=sys.stderr)
    return(new_out_list)

if __name__ == "__main__":
    ret_val = main(sys.argv[1:])
    print(ret_val)
