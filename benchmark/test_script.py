#!/bin/python3
import sys
import argparse
import subprocess
import time
import json


#url_str = "localhost:4567"

nucleotide_opt_str = "advanced=-task blastn -evalue+1e-5&method=blastn"
protein_opt_str = "advanced=-evalue+1e-5&method=blastx"

def main():
    parse_args()
    print(cmd_args.url)

    # Find available dbs
    print("Available db:")
    dbs = retrive_databases()
    if not any(dbs):
        print("Unable to find any database on server")
        sys.exit(1)
    for name in databases_attr(dbs, "title")["protein"]:
        print(name)
    print()

    # First Protein DB
    db_str = "databases[]=" + databases_attr(dbs, "id")["protein"][0]
    # Obtain a sequence length of
    seq = read_seq_from_file("sequence.txt", cmd_args.len)

    #one_search(url_str, seq, db_str, protein_opt_str)

    jobids = []
    ts1 = time.time()
    for i in range(cmd_args.num):
        jobid = submit_job(cmd_args.url, seq, db_str, protein_opt_str)
        jobids.append(jobid)
    for jobid in jobids:
        request_result(jobid)
    ts2 = time.time()
    print(ts2 - ts1)

#
#
# Parse cmd arguments
#
#
def parse_args():
    # initiate the parser
    parser = argparse.ArgumentParser()

    # add long and short argument
    parser.add_argument("--url", "-u", required=True, help="URL of the SequenceServer instance")
    parser.add_argument("--len", "-l", type=int, required=True, help="Length of the sequence")
    parser.add_argument("--num", "-n", type=int, default=1, help="Number of search submitted")
    parser.add_argument("--seq_file", default="sequence.txt", help="File to extract search sequence from")
    parser.add_argument("--db", nargs='+', help="Names of databases")
    parser.add_argument("--verbose", action="store_true", help="Make output verbose")

    # read arguments from the command line
    global cmd_args
    cmd_args = parser.parse_args()


#
#
# Read a sequence of given length from the file
#
#
def read_seq_from_file(filename, length):
    seq = ""
    with open(filename, "r") as f:
        for line in f.readlines():
            if(len(seq) < length):
                seq = seq + line.strip()
            else:
                seq = seq[:length]
                break
    return seq

def submit_job(url_str, seq, db_str, opt_str):
    post_param = "sequence=" + seq + '&' + db_str + '&' + opt_str
    # Submit job
    ts1 = time.time()
    proc = subprocess.run(["curl", "-d", post_param, "-X", "POST", url_str, "-D", "/dev/stdout"], capture_output=True, check=True)
    ts2 = time.time()
    resp_header_str = proc.stdout.decode("utf-8")

    # Obtain Job id
    jobid = ""
    http_status = ""
    for line in resp_header_str.splitlines():
        if(line[:8] == "HTTP/1.1" and line[9:12] == "303"):
            http_status = "303"
        if(line[:9] == "Location:"):
            jobid = line[len(line) - 36:].strip()
            print(jobid)
            break
    if(http_status != "303"):
        raise RuntimeError("Wrong HTTP Status Code");
    if(len(jobid) != 36):
        raise RuntimeError("Invalid Jobid")
    print(ts2 - ts1)
    return jobid

def request_result(jobid):
    # Request for json result
    if(len(jobid) == 36):
        result_json = ""
        req_count = 1
        while(len(result_json) == 0):
            proc = subprocess.run(["curl", cmd_args.url + "/" + jobid + ".json"], capture_output=True, check=True)
            result_json = proc.stdout.decode("utf-8")
            if(len(result_json) == 0):
                req_count += 1
            else:
                print("num_req: ", req_count)
                print(result_json[:50])
#
#
# perform a search
#
#
def one_search(url_str, seq, db_str, opt_str):
    ts1 = time.time()
    jobid = submit_job(cmd_args.url, seq, db_str, opt_str)
    ts2 = time.time()
    request_result(jobid, ts1)
    ts3 = time.time()
    print(ts3 - ts1)

#
#
# Reutrns a list of id of databases
#
#
def retrive_databases():
    proc = subprocess.run(["curl", cmd_args.url + "/searchdata.json"], capture_output=True, check=True)
    json_str = proc.stdout.decode("utf-8")
    try:
        json_obj = json.loads(json_str)
    except json.decoder.JSONDecodeError:
        print("Unable to retrive list of dbs available on server")
        sys.exit(1)
    return json_obj["database"]

def databases_attr(dbs, attr):
    nucleotide_dbs = []
    protein_dbs = []
    for db in dbs:
        if(db["type"] == "nucleotide"):
            nucleotide_dbs.append(db[attr])
        elif(db["type"] == "protein"):
            protein_dbs.append(db[attr])
    return {"nucleotide" : nucleotide_dbs, "protein" : protein_dbs}




main()
