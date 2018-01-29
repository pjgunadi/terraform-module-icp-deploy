#!/usr/bin/python
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
sftp_client.get(remotesrc,targetpath)
sftp_client.close()
client.close()
