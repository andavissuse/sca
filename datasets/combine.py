#
# This script updates a dataset from a supportconfig
#
# Inputs: 1) new (combined) dataset file
#         2) old dataset file
#
# Output: New (combined) dataset file
#

import sys
import os
import getopt
import subprocess
import pandas as pd

def usage():
    print("Usage: " + sys.argv[0] + " [-d(ebug)] combined-dataset-file old-dataset-file")

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
    if not argv[arg_index_start + 1]:
        usage()
        sys.exit(2)
    new_dataset_file = argv[arg_index_start]
    old_dataset_file = argv[arg_index_start + 1]

    # get datasets from disk
    if os.path.exists(new_dataset_file):
        df_new = pd.read_csv(new_dataset_file, sep=" ", dtype={'000_md5sum': str})
    else:
        df_new = pd.DataFrame()
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_new:", df_new)
    df_old = pd.read_csv(old_dataset_file, sep=" ", dtype={'000_md5sum': str})
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_old:", df_old)

    # combine datasets
    df_new_combined = df_new.append(df_old, sort=False).fillna(0)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_new_combined:", df_new_combined)
    df_new_combined_md5 = df_new_combined[['000_md5sum']]
    df_new_combined_data = df_new_combined.drop(columns=['000_md5sum']).astype('int64')
    df_new_combined_ints = pd.concat([df_new_combined_md5, df_new_combined_data], axis=1)
    if DEBUG == "TRUE":
        print("*** DEBUG: " + sys.argv[0] + ": df_new_combined_ints:", df_new_combined_ints)

    # write updated dataset to disk
    fobj_new = open(new_dataset_file, 'w', newline='')
    df_new_combined_ints.to_csv(fobj_new, sep=' ', index=False)

if __name__ == "__main__":
    main(sys.argv[1:])
