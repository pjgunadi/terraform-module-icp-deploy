#!/usr/bin/python
from __future__ import print_function
import sys
import paramiko

servername=sys.argv[1]
username=sys.argv[2]
password=sys.argv[3]
remotesrc=sys.argv[4]
targetpath=sys.argv[5]
client = paramiko.SSHClient()
client.set_missing_host_key_policy(
    paramiko.AutoAddPolicy())
client.connect(sys.argv[1],username=sys.argv[2],password=sys.argv[3])
sftp_client = client.open_sftp()
sftp_client.get(remotesrc,targetpath,lambda x,t : print("Transfering %s %d %% completed." % (targetpath, ((x*1.0)/(t*1.0)*100.0))))
sftp_client.close()
client.close()
