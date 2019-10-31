#!/usr/bin/python3
import sys
import argparse
import subprocess
import time
import json
import threading
import statistics

#
#
# Ex Usage
# ./test_script_thread.py --url=localhost:4567 --list-db
# ./test_script_thread.py --url=localhost:4567 --len=100 --num=10 --db=cdd_delta
# ./test_script_thread.py --url=localhost:4567 --len=100 --num=10 --db cdd_delta landmark
# ./test_script_thread.py --url=localhost:4567 --len=100 --num=10 --seq-file=some_sequence.txt --db=cdd_delta
#
# Note curl seem to have some sort of upper limit of how long the post_param can be, so --len can not be infinitely large
# --len: default 0, 0 means read entire file
# --num: default 1
# --seq-file: default sequence.txt
#

# copied from SequenceServer's default
nucleotide_opt_str = "advanced=-task blastn -evalue+1e-5&method=blastn"
protein_opt_str = "advanced=-evalue+1e-5&method=blastx"

times_jobid = []
times_json = []

def main():
    parse_args()

    # Find available dbs
    dbs = list_databases()
    if not any(dbs):
        print("Unable to find any database on server")
        sys.exit(1)

    # If asked to list available dbs
    if cmd_args.list_dbs:
        print("Protein DBs:")
        for name in databases_attr(dbs, "name")["protein"]:
            print('\t', name)
        print("Nucleotide DBs:")
        for name in databases_attr(dbs, "name")["nucleotide"]:
            print('\t', name)
        print()
        sys.exit(0)

    # Check if all db are of the same type
    db_type = databases_type_check(dbs, cmd_args.db)

    # Generate db_str
    global db_str
    db_str = gen_db_str(dbs, cmd_args.db) 

    # Obtain a sequence of given length
    global seq_str
    seq_str = read_seq_from_file(cmd_args.seq_file, cmd_args.len)

    # Use default option of the type of db
    global opt_str
    if db_type == "protein":
        opt_str = protein_opt_str
    elif db_type == "nucleotide":
        opt_str = nucleotide_opt_str

    # Proceed without thread, if only 1 seq
    if cmd_args.num == 1:
        (t_jobid, t_json) = one_search(cmd_args.url, seq_str, db_str, opt_str)
        print(t_jobid)
        print(t_json)
        sys.exit(0)

    # Launch threads if more than 1 seq
    threads = []
    ts1 = time.time()
    for x in range(cmd_args.num):
        t = MyThread(name = "Thread-{}".format(x + 1))
        t.start()
        threads.append(t)
        #time.sleep(.01) 

    # Join all threads
    for thread in threads:
        thread.join()
    ts2 = time.time()
    duration = ts2 - ts1

    if cmd_args.verbose:
        print("=======================")

    print("search/sec:\t", cmd_args.num / duration)
    print()
    print("mean(jobid):\t", statistics.mean(times_jobid))
    print("min(jobid):\t", min(times_jobid))
    print("max(jobid):\t", max(times_jobid))
    print("median(jobid):\t", statistics.median(times_jobid))
    print("stdev(jobid):\t", statistics.pstdev(times_jobid))
    print()
    print("mean(json):\t", statistics.mean(times_json))
    print("min(json):\t", min(times_json))
    print("max(json):\t", max(times_json))
    print("median(json):\t", statistics.median(times_json))
    print("stdev(json):\t", statistics.pstdev(times_json))

#
#
# Thread class
# 1 instance will run 1 search
#
#
class MyThread(threading.Thread):
    def run(self):
        (t_jobid, t_json) = one_search(cmd_args.url, seq_str, db_str, opt_str)
        times_jobid.append(t_jobid)
        times_json.append(t_json)

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
    parser.add_argument("--len", "-l", type=int, default=0, help="Length of the sequence")
    parser.add_argument("--num", "-n", type=int, default=1, help="Number of search submitted")
    parser.add_argument("--seq-file", type=str, default="sequence.txt", dest="seq_file", help="File to extract search sequence from")
    parser.add_argument("--db", nargs='+', help="Names of databases")
    parser.add_argument("--verbose", action="store_true", help="Make output verbose")
    parser.add_argument("--list-dbs", action="store_true", dest="list_dbs", help="List the name of the databases available ons Server")

    # read arguments from the command line
    global cmd_args
    cmd_args = parser.parse_args()

    if not cmd_args.list_dbs:
        if not cmd_args.db:
            print("error: the following arguments are required: --url/-u, --db")
            sys.exit(1)


#
#
# Read a sequence of given length from the file
#
#
def read_seq_from_file(filename, length = 0):
    seq = ""
    with open(filename, "r") as f:
        for line in f.readlines():
            if length == 0:
                seq = seq + line.strip()
            elif len(seq) < length:
                seq = seq + line.strip()
            else:
                seq = seq[:length]
                break
    return seq

#
#
# Submit Jobs to SeqServer
#
#
def submit_job(url_str, seq, db_str, opt_str):
    try:
        post_param = "sequence=" + seq + '&' + db_str + '&' + opt_str
        # Submit job
        ts1 = time.time()
        proc = subprocess.run(["curl", "-s", "-d", post_param, "-X", "POST", url_str, "-D", "/dev/stdout"], stdout=subprocess.PIPE, check=True)
        ts2 = time.time()
        resp_header_str = proc.stdout.decode("utf-8")


        # Obtain Job id
        jobid = ""
        http_status = ""
        for line in resp_header_str.splitlines():
            if line[:8] == "HTTP/1.1" and line[9:12] == "303":
                http_status = "303"
            if line[:9] == "Location:":
                jobid = line[len(line) - 36:].strip()
                if cmd_args.verbose:
                    print(jobid)
                break

        if http_status != "303":
            raise RuntimeError("Wrong HTTP Status Code");
        if len(jobid) != 36:
            raise RuntimeError("Invalid Jobid")

        respond_time = ts2 - ts1
        return (jobid, respond_time)

    except subprocess.CalledProcessError:
        print("Call to curl failed")
        print("Check URL and/or server status")
        sys.exit(1)

#
#
# Request JSON result with Job id
#
#
def request_result(jobid):
    try:
        # Request for json result
        if len(jobid) == 36:
            result_json = ""
            req_count = 1
            while(len(result_json) == 0):
                proc = subprocess.run(["curl", "-s", cmd_args.url + "/" + jobid + ".json"], stdout=subprocess.PIPE, check=True)
                result_json = proc.stdout.decode("utf-8")
                if len(result_json) == 0:
                    req_count += 1
                elif cmd_args.verbose:
                    print("num_req: ", req_count)
                    print(result_json[:50])

    except subprocess.CalledProcessError:
        print("Call to curl failed")
        print("Check URL and/or server status")
        sys.exit(1)

#
#
# Perform a search
#
#
def one_search(url_str, seq, db_str, opt_str):
    ts1 = time.time()
    (jobid, t_jobid) = submit_job(cmd_args.url, seq, db_str, opt_str)
    request_result(jobid)
    ts2 = time.time()
    t_json = ts2 - ts1
    if cmd_args.verbose:
        print(t_jobid)
        print(t_json)
    return (t_jobid, t_json)

#
#
# Reutrns a list of databases available on Server
#
#
def list_databases():
    try:
        proc = subprocess.run(["curl", "-s", cmd_args.url + "/searchdata.json"], stdout=subprocess.PIPE, check=True)
        json_str = proc.stdout.decode("utf-8")
        json_obj = json.loads(json_str)
    except subprocess.CalledProcessError:
        print("Call to curl failed")
        print("Check URL and/or server status")
        sys.exit(1)
    except json.decoder.JSONDecodeError:
        print("Unable to retrive list of dbs available on server")
        sys.exit(1)
    return json_obj["database"]

#
#
# Get an attribute from the list of databases
#
#
def databases_attr(dbs, attr):
    nucleotide_dbs = []
    protein_dbs = []
    for db in dbs:
        if db["type"] == "nucleotide":
            if attr == "name":
                nucleotide_dbs.append(db[attr].split('/')[-1])
            else:
                nucleotide_dbs.append(db[attr])
        elif db["type"] == "protein":
            if attr == "name":
                protein_dbs.append(db[attr].split('/')[-1])
            else:
                protein_dbs.append(db[attr])
    return {"nucleotide" : nucleotide_dbs, "protein" : protein_dbs}

#
#
# Check the type of the databases to search
#
#
def databases_type_check(dbs, db_names):
    in_p = None
    in_n = None
    for db_name in db_names:
        if db_name in databases_attr(dbs, "name")["protein"]:
            in_p = True
        elif db_name in databases_attr(dbs, "name")["nucleotide"]:
            in_n = True
        else:
            print("Database not available on server")
            sys.exit(1)

    if in_p and in_n:
        print("Can only search 1 type of db")
        sys.exit(1)
    if in_p:
        return "protein"
    if in_n:
        return "nucleotide"

def gen_db_str(dbs, db_names):
    result = ""
    for db_name in db_names:
        for db in dbs :
            if db["name"].split('/')[-1] == db_name:
                result += "databases[]=" + db["id"] + "&"
    return result[:-1]


if __name__ == '__main__':main()

