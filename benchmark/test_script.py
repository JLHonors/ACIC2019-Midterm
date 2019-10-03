#!/bin/python3
import subprocess
import time
import json


url_str = "128.196.142.146:4567"

seq_filename = "sequence.txt"
#seq = "CAGTCGATCGATGAGACTGGCTGGAGTGATGCAAATGCTAGCCTAGCTAGTAGTCCAG"
#db_str = "databases[]=e8e6afd3497c3e895e27ecd667e3bb4f"
nucleotide_opt_str = "advanced=-task blastn -evalue+1e-5&method=blastn"
protein_opt_str = "advanced=-evalue+1e-5&method=blastx"


def main():
    print("Available db:")
    db_names = retrive_database("title")
    for name in db_names["protein"]:
        print(name)
    print()

    db_ids = retrive_database("id")
    # First Protein DB
    db_str = "databases[]=" + db_ids["protein"][0]
    # Obtain a sequence length of
    seq = read_seq_from_file("sequence.txt", 50000)

    #one_search(url_str, seq, db_str, protein_opt_str)

    num_seq = 100
    jobids = []
    ts1 = time.time()
    for i in range(num_seq):
        jobid = submit_job(url_str, seq, db_str, protein_opt_str)
        jobids.append(jobid)
    for jobid in jobids:
        request_result(jobid)
    ts2 = time.time()
    print(ts2 - ts1)

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
    for line in resp_header_str.splitlines():
        if(line[:8] == "HTTP/1.1" and line[9:12] != "303"):
            print(line)
            raise RuntimeError("Wrong HTTP Status Code");
        if(line[:9] == "Location:"):
            jobid = line[len(line) - 36:].strip()
            print(jobid)
            break
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
            proc = subprocess.run(["curl", url_str + "/" + jobid + ".json"], capture_output=True, check=True)
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
    jobid = submit_job(url_str, seq, db_str, opt_str)
    ts2 = time.time()
    request_result(jobid, ts1)
    ts3 = time.time()
    print(ts3 - ts1)

#
#
# Reutrns a list of id of databases
#
#
def retrive_database(attr):
    nucleotide_dbs = []
    protein_dbs = []
    proc = subprocess.run(["curl", url_str+ "/searchdata.json"], capture_output=True, check=True)
    json_str = proc.stdout.decode("utf-8")
    json_obj = json.loads(json_str)
    for db in json_obj["database"]:
        if(db["type"] == "nucleotide"):
            nucleotide_dbs.append(db[attr])
        elif(db["type"] == "protein"):
            protein_dbs.append(db[attr])
    return {"nucleotide" : nucleotide_dbs, "protein" : protein_dbs}



main()
