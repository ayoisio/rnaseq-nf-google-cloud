#!/usr/bin/env python
import argparse
import pandas as pd
import pytz
from decimal import Decimal
from google.cloud import bigquery


def load_gene_results(results_path, table_id, sample_id, verbose=False):
    """
    Load gene results into BQ
    Inputs:
        results_path (str)
        table_id (str)
        sample_id (str)
        verbose (bool)
    """
    if verbose is True:
        print("results_path:", results_path)
        print("table_id:", table_id)
        print("sample_id:", sample_id)

    # determine results df
    decimal_columns = ["length", "effective_length", "expected_count", "TPM", "FPKM"]
    results_df = pd.read_csv(results_path, sep='\t', converters=dict.fromkeys(decimal_columns, Decimal))
    results_df.insert(0, 'sample_id', sample_id)
    results_df.rename(columns={'transcript_id(s)': 'transcript_ids'}, inplace=True)

    if verbose is True:
        print("results_df.shape:", results_df.shape)

    # create BigQuery client
    client = bigquery.Client()

    # define load job config
    job_config = bigquery.LoadJobConfig(
        schema=[
            bigquery.SchemaField("sample_id", bigquery.enums.SqlTypeNames.STRING),
            bigquery.SchemaField("gene_id", bigquery.enums.SqlTypeNames.STRING),
            bigquery.SchemaField("transcript_ids", bigquery.enums.SqlTypeNames.STRING),
            bigquery.SchemaField("length", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("effective_length", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("expected_count", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("TPM", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("FPKM", bigquery.enums.SqlTypeNames.DECIMAL),
        ],
        clustering_fields=["sample_id"],
        write_disposition="WRITE_APPEND",
    )

    # execute job
    job = client.load_table_from_dataframe(
        results_df, table_id, job_config=job_config
    )
    result = job.result()

    if not result.error_result:
        print('Job "{}" loaded without error. Current status is {}.'.format(result.job_id, result.state))
    else:
        print('Error occurred while loading job "{}":\n{}\nCurrent status is {}.'.format(result.job_id, result.error_result, result.state))


def load_isoform_results(results_path, table_id, sample_id, verbose=False):
    """
    Load isoform results into BQ
    Inputs:
        results_path (str)
        table_id (str)
        sample_id (str)
        verbose (bool)
    """
    if verbose is True:
        print("results_path:", results_path)
        print("table_id:", table_id)
        print("sample_id:", sample_id)

    # determine results df
    decimal_columns = ["length", "effective_length", "expected_count", "TPM", "FPKM", "IsoPct"]
    results_df = pd.read_csv(results_path, sep='\t', converters=dict.fromkeys(decimal_columns, Decimal))
    results_df.insert(0, 'sample_id', sample_id)

    if verbose is True:
        print("results_df.shape:", results_df.shape)

    # create BigQuery client
    client = bigquery.Client()

    # define load job config
    job_config = bigquery.LoadJobConfig(
        schema=[
            bigquery.SchemaField("sample_id", bigquery.enums.SqlTypeNames.STRING),
            bigquery.SchemaField("transcript_id", bigquery.enums.SqlTypeNames.STRING),
            bigquery.SchemaField("gene_id", bigquery.enums.SqlTypeNames.STRING),
            bigquery.SchemaField("length", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("effective_length", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("expected_count", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("TPM", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("FPKM", bigquery.enums.SqlTypeNames.DECIMAL),
            bigquery.SchemaField("IsoPct", bigquery.enums.SqlTypeNames.DECIMAL),
        ],
        clustering_fields=["sample_id"],
        write_disposition="WRITE_APPEND",
    )

    # execute job
    job = client.load_table_from_dataframe(
        results_df, table_id, job_config=job_config
    )
    result = job.result()

    if not result.error_result:
        print('Job "{}" loaded without error. Current status is {}.'.format(result.job_id, result.state))
    else:
        print('Error occurred while loading job "{}":\n{}\nCurrent status is {}.'.format(result.job_id, result.error_result, result.state))


if __name__ == "__main__":
    # establish argument parser
    parser = argparse.ArgumentParser()

    # results_type flag
    parser.add_argument(
        "--results_type",
        required=True,
        choices={"gene", "isoform"},
        help="Type of results being uploaded"
    )

    # results_path flag
    parser.add_argument(
        "--results_path",
        required=True,
        help="Path where results file is located"
    )

    # table_id flag
    parser.add_argument(
        "--table_id",
        required=True,
        help="BQ Table ID where results will be loaded"
    )

    # sample_id flag
    parser.add_argument(
        "--sample_id",
        required=True,
        help="Sample ID corresponding to the results"
    )

    # verbose flag
    parser.add_argument(
        "--verbose",
        required=False,
        type=bool,
        default=False,
        help="Verbosity"
    )

    # determine input arguments
    args = parser.parse_args()

    if args.results_type.lower() == "gene":
        load_gene_results(
            results_path=args.results_path,
            table_id=args.table_id,
            sample_id=args.sample_id,
            verbose=args.verbose
        )
    elif args.results_type.lower() == "isoform":
        load_isoform_results(
            results_path=args.results_path,
            table_id=args.table_id,
            sample_id=args.sample_id,
            verbose=args.verbose
        )
    else:
        print('Matching load function for results type "{}" not found.'.format(args.results_type))
