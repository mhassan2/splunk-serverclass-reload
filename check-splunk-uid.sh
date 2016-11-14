#!/bin/bash
#
######################################################################################
# Date:			April 11, 2012  Mohamad Hassan  mhassan2@yahoo.com
# License:		GPL
# Script name : 	check-splunk-uid.sh
# Purpose: 		Enforce user ID policies in Splunk! Delete users who do not login for more than 90 days.
#
# Time/Date calcuation borrowed from http://www.unix.com/tips-tutorials/31944-simple-date-time-calulation-bash.html
#
# Usage:
# 	-v 	Just a trial run. No Action (email, logging, deletion) is executed.
#
# Feature Summary:
#	-Actions executed are recorded in /opt/splunk/scripts/check-splunk-uid.log
#	-Warning emails sent at this interval 30,33,60,63,90 days. Eventually delete at 93 days of inactivity.
#	-Systadmins always cced on emails
#	-Some system IDs are excluded from this check
#	-you can run in demo mode if you just want to see the status of users.
#	-Newly created users will get grace period of 24HRS to change their initial password (provided that you have daily crontab job to execute the scipt)
#
# Note:
# 	Time/Date functions from http://www.unix.com/tips-tutorials/31944-simple-date-time-calulation-bash.html
#	- added log to ingnore line begining with # in input file
#	-added log for creation time
#	-users must be created with create-splunk-uid.sh for creating date to be detected
#
#
######################################################################################


SYSADMEMAIL="Mohamad.Hassan@foo.com"
EXCLUDED_USERS="(api|admin|root|splunk|wwwepic)"

UIDTMPFILE="/tmp/check-splunk-uid.tmp"
UIDFILE="/tmp/check-splunk-uid.tmp"

CREATEUIDLOG="/opt/splunk/scripts/create-splunk-user.log"
LOGFILE="/opt/splunk/scripts/check-splunk-uid.log"

WEBACCESSLOGS="/opt/splunk/var/log/splunk/web_service.log*"
AUDITLOGS="/opt/splunk/var/log/splunk/audit.log*"

SPLUNK_USERS="/opt/splunk/etc/passwd"
TMPMSGFILE="/tmp/check-splunk-uid.email"

HOSTNAME=`hostname -s`
CTRL_HOST="usstlecpsecap04"
alias xsplunk="/opt/splunk/bin/splunk login -auth 'cli:$(cat /opt/splunk/scripts/.splunk-cli-creds)' && splunk"


#-----------------------------------------------------------------------------------------------
reminder ()
{

	
	echo "             **************   This is an automated message   ************** "	>> $TMPMSGFILE
	echo ""											>> $TMPMSGFILE
	echo "               ** This message is regarding your Splunk! access ONLY ** "		>> $TMPMSGFILE
	echo ""											>> $TMPMSGFILE
	echo ""											>> $TMPMSGFILE
	echo "--------------------------------------------------------------------"		>> $TMPMSGFILE
	echo "User ID	= 	${USERNAME} "							>> $TMPMSGFILE
	echo "Role	=	${ROLE}" 							>> $TMPMSGFILE
	echo "Email	=	${USEREMAIL}" 							>> $TMPMSGFILE
	echo "Splunk	= 	https://$HOSTNAME:8000" 					>> $TMPMSGFILE
	echo ""											>> $TMPMSGFILE
	echo "Inactivity= 	${INACTIVITY} days"						>> $TMPMSGFILE
	echo "Last Successful login:	$LAST"							>> $TMPMSGFILE
	echo "--------------------------------------------------------------------"		>> $TMPMSGFILE
	echo ""											>> $TMPMSGFILE
	echo ""											>> $TMPMSGFILE
	echo "Action: 			$ACTION"						>> $TMPMSGFILE
	echo "Explanation: 		$REASON"						>> $TMPMSGFILE
	
	if [ "$DEMO" == "FALSE" ]; then
		cat $TMPMSGFILE |mail -s "Account alert from Splunk!"  -r Splunk@syslog-nala -c $SYSADMEMAIL $USEREMAIL ;
		#echo
	fi	

	#test code
	#mailx bar@foo.com -s "HTML Hello" -a "Content-Type: text/html" < body.htm
	
	
}
#-----------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------
date2stamp () {
    date --utc --date "$1" +%s
 }
#-----------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------    
 stamp2date (){
        date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
 }
#-----------------------------------------------------------------------------------------------
 
#-----------------------------------------------------------------------------------------------       
 dateDiff (){
 	case $1 in
             -s)   sec=1;      shift;;
             -m)   sec=60;     shift;;
             -h)   sec=3600;   shift;;
             -d)   sec=86400;  shift;;
              *)   sec=86400;;
      	esac
 
 dte1=$(date2stamp $1)
 dte2=$(date2stamp $2)
 diffSec=$((dte2-dte1))
 
 if ((diffSec < 0)); then 
 	abs=-1; 
 else abs=1; 
 
 fi
 
 echo $((diffSec/sec*abs))
 
 }
#-----------------------------------------------------------------------------------------------                                                                            



#Error checks
if [ $HOSTNAME != $CTRL_HOST ]; then
        echo "This scirpt must be executed from this from $CTRL_HOST!  Exiting";echo;
        exit
fi

DEMO="FALSE"
if [ "$1" == "-v" ]; then
  	echo; echo "		   ########  DEMO MODE!  ########";echo
    	DEMO="TRUE"
fi



#dump all UIDs to a file. Exclude system IDs
cat $SPLUNK_USERS|cut -d: -f2,6,7|sed 's/:/ /g'|egrep -vi "$EXCLUDED_USERS" > $UIDFILE



cat ${UIDFILE} | \
while read USERNAME ROLE USEREMAIL 
do
#	echo [USERNAME:$USERNAME]   [USEREMAIL:$USEREMAIL] [ROLE:$ROLE]
	#Calcute how many hour to next time crontab kicks the script at 2am UTC
	CREATED=""


	LAST=`grep "action=login" $WEBACCESSLOGS|awk '{print $1, $6, $9,$7,$8,$21}'|grep $USERNAME|grep success|cut -d ":" -f 2,10|sort|tail -1 | cut -d " " -f1 `
			
	TODAY=`date "+%Y-%m-%d"`

	
	#$LAST is empty if they are no activity records for the user (never logged-in OR logged-in long time ago)
	if [ -z "$LAST" ]; then
		let INACTIVITY=-1
	
	else
		#calculate numeber of days since last login (compaired to TODAY's DATE)
		INACTIVITY=`dateDiff "$TODAY" "$LAST"`
	fi
	
	

	#If script is set to execute daily; this condition will allow 48 hrs grace period for newly created accounts.
	 if      [ $INACTIVITY -eq -1 ]; then
                        
			#D1=`grep $USERNAME $AUDITLOGS|grep  "operation=create"|grep "action=edit_user"|awk '{print $7, $8}'\
			#|tail -1|sed "s/Audit:\[timestamp=//g"|cut -d: -f1,2`
			#CREATED="${D1:6:4}-${D1:0:2}-${D1:3:2} ${D1:11:6}"
			
			CREATED=`grep $USERNAME $CREATEUIDLOG|grep "User ID created\!" |awk '{print $1,$2'}`
			NOW=`date "+%Y-%m-%d %H:%M"`
			
			#testing
			#CREATED="2012-06-23 09:00"
			#NOW="2012-06-26 20:00"
			ELAPSED=`dateDiff "-h"  "$NOW" "$CREATED"`
			
			#echo "CREATED:	[$CREATED]"
			#echo "NOW:		[$NOW]"
			#echo "ELAPSED:	[$ELAPSED]"
			#echo
			if [ $ELAPSED -gt 24 ] ; then
				ACTION="##Account Deleted##"
			else
				ACTION="##Account scheduled for deletion##"
			fi	
                        REASON="User never logged-in. $ELAPSED HRS elapsed since creation time!"
                        CATEGORY="-1"
			
                        if [ "$DEMO" == "FALSE" ] && [ $ELAPSED -gt 24 ] ; then
                        	
                        	opt/splunk/bin/splunk remove user $USERNAME
                        	echo `date "+%Y-%m-%d %R"`:[$USERNAME][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
                        	reminder;
             		fi
                        

        
        elif    [ $INACTIVITY -eq 0 ]; then
                        ACTION="None"
                        REASON="Active today!"
                        CATEGORY="0"
                
	elif 	[ $INACTIVITY -gt 30 ]; then
			ACTION="**Account Deleted**"
			REASON="Inactive for more than 30+ days!"
			CATEGORY="30+"
			if [ "$DEMO" == "FALSE" ]; then
			#/opt/splunk/bin/splunk remove user $USERNAME
			echo `date "+%Y-%m-%d %R"`:[$USERNAME][Last:$LAST][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
			fi
			reminder;

	elif 	[ $INACTIVITY -eq 30 ]; then
                	ACTION="Email Warning! (W5)" 
                	REASON="Inactive for 30 days! Scheduled for deletion in 3 days"
                	CATEGORY="30"
                	if [ "$DEMO" == "FALSE" ]; then
                	echo `date "+%Y-%m-%d %R"`:[$USERNAME][Last:$LAST][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
         		fi
                	reminder;
	
	elif 	[ $INACTIVITY -eq 30 ]; then
                	ACTION="Email Warning! (W4)"
                	REASON="Inactive for 30+ days!"
                	CATEGORY="30+"
                	if [ "$DEMO" == "FALSE" ]; then
                	echo `date "+%Y-%m-%d %R"`:[$USERNAME][Last:$LAST][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
          		fi
                	reminder;
                	
	
	elif 	[ $INACTIVITY -eq 30 ]; then
                	ACTION="Email Warning! (W3)"
                	REASON="Inactive for 30 days!"
                	CATEGORY="30"
                	if [ "$DEMO" == "FALSE" ]; then
                	echo `date "+%Y-%m-%d %R"`:[$USERNAME][Last:$LAST][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
          		fi
                	reminder;
                	
	elif 	[ $INACTIVITY -eq 30 ]; then
                	ACTION="Email Warning! (W2)"
                	REASON="Inactive for 30+ days!"
                	CATEGORY="30+"
                	if [ "$DEMO" == "FALSE" ]; then
                	echo `date "+%Y-%m-%d %R"`:[$USERNAME][Last:$LAST][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
          		fi
                	reminder;

	elif 	[ $INACTIVITY -eq 30 ]; then
                	ACTION="Email Warning! (W1)"
                	REASON="Inactive for 30 days!"
                	CATEGORY="30"
                	if [ "$DEMO" == "FALSE" ]; then
                	echo `date "+%Y-%m-%d %R"`:[$USERNAME][Last:$LAST][Inactive:$INACTIVITY][CAT:$CATEGORY][$ACTION][$REASON] >> $LOGFILE
           		fi
                	reminder;


	else	
                	ACTION="None"
                        REASON="Inactive for less than 30 Days!"
                	CATEGORY="1"
	
	fi
	
	echo [$USERNAME][Last:$LAST] [Inactive:$INACTIVITY][CATEGORY:$CATEGORY][$ACTION][$REASON]
	echo "----------------------------------------------------------------------------------"
	

	
	#Clean up
	rm -fr $UIDTMPFILE
	rm -fr $UIDFILE
	rm -fr $TMPMSGFILE


done;

if [ "$DEMO" == "FALSE" ]; then
	echo "----------------------------------------------------------------------------------------------------" >> $LOGFILE
fi
