#
# This script uses Nearest Neighbor classification on a dataset to predict
# whether there is an SR or bug related to the specified supportconfig.
#
# Inputs: 1) supportconfig feature info to be matched (provided as a file)
#         2) output type (srs|bugs) dataset file
#         3) input dataset file
#         4) distance metric
#
# Output: Prediction of whether the supportconfig data looks like an
#         existing bug|sr|cert
#

import sys
import getopt
import numpy as np
import pandas as pd
import subprocess
from sklearn.neighbors import NearestNeighbors
from sklearn.neighbors import KNeighborsClassifier

def usage():
    print("Usage: " + sys.argv[0] + " [-d(ebug)] sc_features_file outtype_dataset_file input_dataset_file distance_metric")

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
    if not argv[arg_index_start + 2]:
        usage()
        sys.exit(2)
    sc_features_file = argv[arg_index_start]
    outtype_dataset_file = argv[arg_index_start + 1]
    dataset_file = argv[arg_index_start + 2]
    dist_metric = argv[arg_index_start + 3]
    outtype_col_name = "Id"
    weights_alg = "distance"

    # load datasets and build the combined dataframe
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": sc_features_file:", sc_features_file)
        print("*** DEBUG: " + sys.argv[0] + ": outtype_dataset_file:", outtype_dataset_file)
        print("*** DEBUG: " + sys.argv[0] + ": dataset_file:", dataset_file)
        print("*** DEBUG: " + sys.argv[0] + ": dist_metric:", dist_metric)
    dataset_df = pd.read_csv(dataset_file, sep=" ", dtype={'000_md5sum': str})
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": dataset_df:\n", dataset_df)
    outtype_dataset_df = pd.read_csv(outtype_dataset_file, sep=" ", dtype={'000_md5sum': str, outtype_col_name: str})
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": outtype_dataset_df:\n", outtype_dataset_df)
    df = pd.merge(dataset_df, outtype_dataset_df, on='000_md5sum', how='left')
    df.fillna(0, inplace = True)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df:\n", df)
        
    # create the sc vector (and add columns for unknowns to df dataframe)
    sc_bin_list = [0] * (len(df.columns) - 2)
    sc_features_list = subprocess.getoutput("cat %s" % sc_features_file).split()
    num_sc_features = len(sc_features_list)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": sc_features:", sc_features_list)
    for feature in sc_features_list:
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": feature:", feature)
        if feature in df.columns.values:
            matching_col_num = df.columns.get_loc(feature)
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": matching_col_num:", matching_col_num)
            sc_bin_list[matching_col_num - 1] = 1
        else:
            if DEBUG == "TRUE":
                print("*** DEBUG: " + sys.argv[0] + ": no matching column for:", feature)
            sc_bin_list.append(1)
            df.insert((len(df.columns) - 1), feature, 0)
        if DEBUG == "TRUE":
            print("*** DEBUG: " + sys.argv[0] + ": sc_bin_list:", sc_bin_list)
            print("*** DEBUG: " + sys.argv[0] + ": df:", df)
    sc_array = np.array(sc_bin_list)

    # run the classifier
    knn = KNeighborsClassifier(n_neighbors=5, weights=weights_alg, metric='euclidean')
    df_cols = len(df.columns)
    Inputs_df = df.iloc[:, 1:df_cols - 1]
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": Inputs_df:\n", Inputs_df)
    outputs_df = df.loc[:, [outtype_col_name]]
    outputs_array = outputs_df.values.ravel()
    outputs_array = outputs_array.astype('int') 
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": outputs_array:", outputs_array)
    knn.fit(Inputs_df, outputs_array)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": neighbors:", knn.kneighbors(sc_array.reshape(1, -1)))
    out_pred = knn.predict(sc_array.reshape(1, -1))
#    print(out_pred)
    return(out_pred)

if __name__ == "__main__":
    ret_val = main(sys.argv[1:])
    print(ret_val)


