#!/usr/bin/env python

##########################################################################################################################################
# Script:	reload.py
# Inputs:	none
# Description: 	This python script wraps around "reload deploy-server" cli in splunk. It parses /opt/splunk/etc/system/local/serverclass.conf 
#		and extracts all existing server classes. Then prompts user to select a class to reload. <ENTER> only will reload all classes. 
#		In large environment this speed up the deployment process
#
# Revisions:	6/13/2013 converted from my bash script -MyH
#
# Note: "reload" works with "updated" app. If you add new app; you must restart splunkd 
##########################################################################################################################################


from sys import argv
from sys import stdout
#import sys
import time
from os import path, access, R_OK  # W_OK for write permission.
import string
#from subprocess import call
import subprocess

TMPFILE = "/tmp/reload.tmp"
CONFFILE = "/opt/splunk/etc/system/local/default-serverclass.conf"
USERFILE = "/splunkds/scripts/user.conf"
i = 0
j = 0
curr_class = ""
prev_class = curr_class
curr_app = ""
prev_app = ""
txt = []
menu = []

#-----------------------------------------------------
def die(error_msg):
	#raise Exception(error_msg)
	print
	print (error_msg); print ("\n")
	exit (0)
#-----------------------------------------------------

#-----------------------------------------------------
def shell_cmd(cmd):
        p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in p.stdout.readlines():
                line,
        retval = p.wait()
        return (line)
#-----------------------------------------------------


if path.isfile(CONFFILE) and access(CONFFILE, R_OK):
	print "\nReading file [%s]...\n" % CONFFILE
else:
	
	print "\n[%s]..." % CONFFILE
	die('Error: File is missing or is not readable!')
f = open(CONFFILE, 'r')


if path.isfile(USERFILE) and access(USERFILE, R_OK):
	 print "\nReading file [%s]...\n" % USERFILE
else:
        die('Error: user.conf is missing or is not readable!')
f2 = open(USERFILE, 'r')




for line in f2:
	line = line.split(":")				# parse on :
	user = line[0]
	password = line[1].strip('\n')



print "\033[01;0m"
print "No)	 ServerClass	        {count}		Application Name"
print "-------------------------	---------------------------------------------------------------------------------"

#Exclude all_deploy class, classes with no apps and commneted lines!
for line in f:
	if (string.find(line,"#") == -1) and (string.find(line,"app:") >= 0)  and (string.find(line,"all_deploy") == -1) and (len(line) > 0):
		line = line.replace("[","")			# clean leading end
		line = line.replace(']\n',"")			# clean trailing end
		line = line.replace("serverClass:","")		# remove serverclass	
		line = line.replace("app:","")			# remove app
		line = line.split(":")				# parse on :
		
		curr_class = line[0]
		curr_app = line[1]
		if i == 0: 
			txt = line
			menu.append(curr_class)

#		print "DEBUGG:currClass:%s >> currApp:%s" % (curr_class, curr_app)
#		print "DEBUGG:prevClass:%s    currClass:%s  " % (prev_class, curr_class )

		if (curr_class == prev_class): # or  (not prev_class):
#			print "DEBUGG: ** Append! **", i
			txt.append(prev_app)
		elif (i != 0): 
			print "\033[01;46m%-2d) %-25s\t\033[01;0m{%d} %s" % (j, str(txt[0:1]).strip('[\']') ,  len(txt)-1, str(txt[1:]).strip('[\'] \'') )
			txt = line
			menu.append(curr_class)
			j += 1

		prev_class = curr_class
		prev_app = curr_app
		i += 1

#disply the last item in the list after for loop
print "\033[01;46m%-2d) %-25s\t\033[01;0m{%d} %s\n" % (j, str(txt[0:1]).strip('[\']') ,  len(txt)-1, str(txt[1:]).strip('[\'] \'') )


#DEBUGG:
#j =  0
#while j < len(menu):
#	print j, menu[j]
#	j += 1

c = '/opt/splunk/bin/splunk list deploy-clients -count -1 -auth ' + user + ':' + password + '|grep hostname:|wc -l '
#print "c=[%s]" % c
count = shell_cmd(c)
print "Agents count:>> %s " % count

try:
   	selection = int(raw_input('Select a number (<ENTER> for all) : '))
   	print "Reloading serverClass:>>> \033[01;46m[%s]\n" % menu[selection]
	print "\033[01;0m"
	c = '/opt/splunk/bin/splunk reload deploy-server -count -1 -auth ' + user + ':' + password + '-class ' + menu[selection]
	shell_cmd (c)
	i = 5
	
except ValueError:
   	print "Reloading serverClass:>>> \033[01;46m[ALL]\n" 
	print "\033[01;0m"
	c = '/opt/splunk/bin/splunk reload deploy-server -count -1 -auth ' + user + ':' + password
	shell_cmd (c)
	i = 0


sleep = 4
print "Frequency of sampling:%d    Interval in sec:%d " % (10-i, sleep)
print "Current Agent Count (CTRL-C to abort):>> ", 
while i <= 10 :
	c = '/opt/splunk/bin/splunk list deploy-clients -count -1 -auth ' + user + ':' + password + '|grep hostname:|wc -l '
	count = shell_cmd(c)
	print (count.rstrip('\n')),
	stdout.flush()
	i += 1
	time.sleep(sleep)
print	

#s.rstrip('\n')
f.closed
f2.closed

