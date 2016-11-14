#!/bin/bash
#
######################################################################################
# Date:			Feb 3, 2012  Mohamad Hassan 
# License:		GPL
# Script name : 	create-splunk-use.sh
# Purpose: 		Create Splunk! users IDs.
# Changes:
# Sample input file:
##	username	email				role	Full Name
#	llucky          Li.Jixiang.Lucky@foo.com    admenpc	Li Jixiang Lucky
#	mhassan		mohamad.hassan@foo.com	admin	Mohamad Hassan
#
######################################################################################


DEFAULT_USERS_INFILE="/opt/splunk/scripts/create-splunk-user.list"
HOME_BASE="/opt/splunk/"
SYSADMEMAIL="Mohamad.Hassan@foo.com"
TMPEMAILFILE="/tmp/email.tmp"
RESULTTMPFILE="/tmp/added.tmp"
EXTMSGFILE="/opt/splunk/scripts/create-splunk-user.extendedmsg"
LOGFILE="/opt/splunk/scripts/create-splunk-user.log"
DATE=`date "+%Y-%m-%d %H:%M"`

#Control host is SH01
HOSTNAME=`hostname -s`
CTRL_HOST="usstlecpsecap04"
CRONHR=2

#Debugging
#echo There are $# arguments to $0: $*
#echo USER: $1
#echo FULLNAME: $2
#echo USEREMAIL: $3
#echo ROLE: $4
#echo here they are again: $@
#exit

#Error checks
#if [ $HOSTNAME != $CTRL_HOST ]; then
#        echo "This scirpt must be executed from this from $CTRL_HOST!  Exiting";echo;
#        exit
#fi

#if [ "$1" == "--help" ] || [ -z $1 ]; then
#  echo "USAGE: this is a test msg!"
#    exit 0
#fi
    

if [ "$#" == "0" ]; then
	echo
	echo "Usage:"
	echo "This script can be used to do bulk import using -f switch OR create individual single user account."
	echo "An email message will be sent to specified administrator as well as the created user."
	echo "The text of email can be found in $EXTMSGFILE"
	echo
	echo " -u	: User ID"
	echo " -e	: User email account. Will be used for alerts created by that user"
	echo " -r	: Assign a role to user, will determine access level"
	echo " -n	: User full name. This should be the last filed in the inputted command line"
	echo "(example: create-user-splunk.sh  -u mhassan -e mohamad.hassan@emerosn.com -r admsecurity -n Mohamad Hassan) "
	echo
	echo " -f 	: Input from a file. Lines begining with # will be ingored"
	echo "(example: create-splunk-user.sh -f create-splunk-user.list )"
	echo
	echo "Available Splunk roles:"
	echo "admin				: Adminstrator group user. Access to everything"
	echo "corp_etsnetworking		: Access to network devices logs only (router, switches, FW, LB)"
	echo "corp_cirt			: Access to all logs except Splunk logs"
	echo "corp_unix			: Unix group user. Access to Unix logs only (unix source type)"
	echo "corp_gdc			: N/A"
	echo "corp_enterprise_exchange	: MS Exchange team"
	echo "corp_enterpisead		: AD/Windows team. Access to windows logs (AD,DHCP, Windows, LANDESK)"
	echo "corp_xxx			: VMware user. Access to ESX logs only"
	echo "netpwr_apac_enpc_site-admin	: ENPC users. All ENPC logs"
	echo "corp_endpoint			: End Point Security Team (websense, Symantec)"
	echo
	echo
	echo "Listing of current roles (real time output)::"
	/opt/splunk/bin/splunk list user|grep role|awk '{print $2}'| sort -u 
	exit
fi	


if ([ "$1" == "-f" ] && [ ! -f "$2" ]); then
	echo "Iputfile not found [$USERS_INFILE]!...Quiting";echo;
	exit
fi

if [ "$1" == "-f" ]; then
	USERS_INFILE=$2		
else
	USERS_INFILE=$DEFAULT_USERS_INFILE
fi	
	
if [ $# == 4 ]; then
	USER=$1;   USEREMAIL=$2; ROLE=$3; FULLNAME=$4;
	echo "$USER  $USEREMAIL $ROLE '$FULLNAME' " > ${USERS_INFILE}
	ONEUSER=1;
else
	echo "Not enough arguments! Quiting.."	
fi	

#Calcute how many hour to next time crontab kicks the script at 2am UTC
CURHR=`date --utc "+%H"`
let GRACE='48+CRONHR'-$CURHR


cat ${USERS_INFILE} | while read DUSER USEREMAIL ROLE FULLNAME 
do

		#Ignore comments (lines start with hash)
  		USER=`echo $DUSER|grep  -v "^#\|^'\|^\/\/"`;
		if [ -n "$USER" ]; then
			GPASSWORD=`/opt/splunk/scripts/passwd_gen.sh`
			echo "Processing line: USER:[$USER] PASS[$GPASSWORD] FULLNAME[$FULLNAME] EMAIL[$USEREMAIL] ROLE[$ROLE]";
			/opt/splunk/bin/splunk login  -auth 'mhassan:wnmhgb';
			/opt/splunk/bin/splunk add user $USER -password $GPASSWORD -full-name "$FULLNAME" -email $USEREMAIL -role $ROLE > $RESULTTMPFILE
			RESULT=`grep -i Added $RESULTTMPFILE`
	
			#Build body of msg:
			echo "             ********* This is an automated message ********** "		>> $TMPEMAILFILE
			echo "				 "						>> $TMPEMAILFILE
			echo "A local SPLUNK! account has been created for you with the following details:"	>> $TMPEMAILFILE
			echo "-------------------------------------------------------------------------">> $TMPEMAILFILE
			echo "User ID	= ${USER} "							>> $TMPEMAILFILE
			echo "Password	= ${GPASSWORD} "						>> $TMPEMAILFILE
			echo "Group		= ${ROLE} "						>> $TMPEMAILFILE
			echo "Email		= $USEREMAIL"						>> $TMPEMAILFILE
			echo "" 									>> $TMPEMAILFILE
			echo "" 									>> $TMPEMAILFILE
			cat $EXTMSGFILE									>> $TMPEMAILFILE
			
			
		
		
			if [ "$RESULT" == "User added." ]; then
				cat $TMPEMAILFILE |mail -s "Your new SPLUNK! Account" -r Splunk-Admin-no-reply@splunk.emrsn.com -c $SYSADMEMAIL $USEREMAIL ;
				echo "User created! Returned results:[`cat $RESULTTMPFILE`]"
				echo "$DATE [UID:$USER] [ROLE:$ROLE] [EMAIL:$USEREMAIL]. User ID created!" >> $LOGFILE
			else
				echo "User NOT created! Returned results:[`cat $RESULTTMPFILE`]"
			fi	
		
			#Cleanup
			rm -fr $RESULTTMPFILE
			rm -fr $TMPEMAILFILE
		fi
		echo
			
	
if [ ONEUSER == 1 ]; then
	exit
fi	
	
done

