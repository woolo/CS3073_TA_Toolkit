#!/bin/bash

DIR="$1"

if [[ -z $DIR ]]
then
cat <<EOR
permtest.sh -- test permissions for the assignment
--------------------------------------------------
usage: sudo ./permtest.sh DIR

... where DIR is the "root level" of the student's submission.
For example, submissions created by 'submit.sh' will be nested 
two levels deep, e.g., 'root/root-permissions'. Accordingly the
correct usage would be:

sudo ./permtest.sh root/root-permissions

EOR
	exit
fi

echo "Looking at entries in ./$DIR..."

LOG="/tmp/permtestlog"

function runprint {

	echo -e "  Student answer: $@"

}


function user_in_group() {
# user_in_group -- determine whether a user is in some group
# usage: user_in_group username groupname question-mode
#
# username: the user's name, e.g., 'larry'
# groupname: the group name in question, e.g., 'wheel'
# question-mode: the question number for the spreadsheet, e.g., Q
#                or "quiet" to suppress output if using function
#				 for boolean output
#
# output: prints evidence for non-membership and sets GRP_BOOL to 
#         'in' or 'out' depending on truth value.
#
#         if question-mode is 'quiet' does not print output.
# 
# there are two ways that a user can be in a group. Using 'emp' and 'larry' as
# examples:
#
# 1. the 'emp' line in group contains "larry"
#
# 2. "larry" has the 'emp' group number as their primary group in passwd (this
# will be the case if students created the account with adduser and the
# '--ingroup' option).
#
# We need to test both possibilities.

	USR=$1 # what user are we testing
	GRP=$2 # what group should they be in?
	QNUM=$3 # what question number is this in spreadsheet?
	        # OR enter 'quiet' to suppress messages (for boolean)

	GRP_BOOL="" # a boolean set to 'in' or 'out' for later reference
	GRP_PROB="" # a string that describes the evidence

	# get the group number for emp
	GRPID=$(grep -E "^$GRP" group | sed -r "s/^$GRP:x:([^:]+):.*/\1/") >> $LOG

	# test case #1 -- user is listed in group
	if ! grep "^$GRP" group | grep $USR >> $LOG
	then
		GRP_PROB="$USR not in /etc/group" 
		
		# testing case #2
		PRIGROUP=$(grep -E "^$USR" passwd | sed -r "s/$USR:x:[^:]+:([^:]+):.*/\1/")

		if [[ $GRPID != $PRIGROUP ]]
		then

			if [[ $QNUM != "quiet" ]]
			then
				GRP_PROB="$GRP_PROB; $GRPID not primary group for $USR (is $PRIGROUP)"
				echo "$QNUM: $USR not in group $GRP (primary or secondary)."
				echo "  $GRP_PROB"
				runprint $(grep ^$GRP group)
				runprint $(grep ^$USR passwd)
			fi

			GRP_BOOL="out" # $USR is not in $GRP
			return

		fi
	fi

	GRP_BOOL="in" # $USR is in $GRP

}



pushd $DIR >> $LOG

# /home should be owner root and user wheel (i.e., root:wheel); but the system
# we are grading on may not have a wheel group. even if it did, it is probably
# not the same numeric GID as on the student's node (and thus their
# submission). So, we need to figure out what group id wheel had on the
# student's node, and then find out what group has that group id on this
# system. That name is what will show up when we check it out.

# get the groupid for wheel and tps from the student's submission
WHEELID=$(grep -E "^wheel" group | sed -r "s/^wheel:x:([^:]+):.*/\1/") >> $LOG
echo -n "wheel's submitted ID is '$WHEELID'... "

# if there is a group with that ID on this system, it will have a different name
# we'll need to know that name for grading purposes. If there is no such group,
# we'll need to use the ID instead.

if grep -E ".+:x:$WHEELID:" /etc/group
then
	# get the LOCAL group name matching that group ID on the current system:
	WHEEL=$(grep ".+:x:$WHEELID:" /etc/group | sed -r "s/([^:]+):.*/\1/") >> $LOG
else
	# no such group -- just use the number
	echo -n "no local group... "
	WHEEL=$WHEELID
fi

echo "local name is '$WHEEL'"

# we need this information for the tps user just like for wheel group above.
# it's unlikely there's a tps user, but hey... it's not wrong to check.
TPSID=$(grep -E "^tps" passwd | sed -r "s/^tps:x:([^:]+):.*/\1/")
echo -n "tps's submitted user ID is '$TPSID'... "

if grep -E "^tps" /etc/passwd
then
	TPS=$(grep :$TPSID: /etc/passwd | sed -r 's/tps:x:([^:]+):.*/\1/')
else
	echo -n "no local user... "
	TPS=$TPSID
fi
echo "local name is '$TPS'"

echo "Looking for flaws in submission (only reporting errors)..."
echo

# students must create admins directory
if ! ls -al | grep admins >> $LOG
then
	echo "D: no /admins directory."
fi

# ownership of admin homedirs should be ken:ken, etc.
for OLDBIE in ken
do

	# we need the UIDs for ken:
	ADMU=$(grep -E "^$OLDBIE" passwd | sed -r "s/^$OLDBIE:x:([^:]+):.*$/\1/")
	ADMG=$(grep -E "^$OLDBIE" group | sed -r "s/^$OLDBIE:x:([^:]+):.*$/\1/")

	if ! ls -n admins | grep $OLDBIE | grep -E "$ADMU.+$ADMG" >> $LOG
	then
		echo "E: $OLDBIE home ownership not correct, should be '$ADMU $ADMG'"
		runprint $(ls -n admins | grep $OLDBIE)
	fi
	
	# and permissions should be drwxrwsr-x
	if ! ls -al admins | grep $OLDBIE | grep -E "drwxrwsr-x" >> $LOG
	then
		echo "E: $OLDBIE home perms not correct (s.b. drwxrwsr-x)"
		runprint $(ls -al admins | grep $OLDBIE)
	fi


done

# wheel should be the group of the home directory
if ! ls -al | grep home | grep -E "root.+$WHEEL" >> $LOG
then
	echo "F: home user/group not correct (s.b. root $WHEEL):"
	runprint $(ls -al | grep home)
fi

# permissions on home should be rwxrwx--x
if ! ls -al | grep home | grep -E "(rwxrwx--x|---rwx--x)" >> $LOG
then
	echo "G: /home permissions are not correct (s.b. 0771/rwxrwx--x or 0071/---rwx--x)"
	runprint $(ls -al | grep home)
fi

# homedirs in /home should be set 0750
for EMP in larry moe curly
do

	if ! ls -al home | grep $EMP | grep "drwxr-x---" >> $LOG
	then
		echo "H: homedir /home/$EMP has incorrect permissions (should be 0750/drwxr-x---)"
		runprint $(ls -al home | grep $EMP)
	fi

done


# there must be a ballots dir
if ! ls -al | grep ballots >> $LOG
then
	echo "I: no ballots box"
	runprint $(ls -al | grep ballots)
fi

# ownership of ballots directory
if ! ls -al | grep ballots | grep -E "root.+$WHEEL" >> $LOG
then
	echo "J: ballots ownership not correct (s.b. root $WHEEL)"
	runprint $(ls -al | grep ballots)
fi

# and its permissions should be drwx----wx
if ! ls -al | grep ballots | grep -E "(drwx----wx|d-------wx)" >> $LOG
then
	echo "K: ballots perms not correct (s.b. 0703/drwx----wx or 0003/d-------wx)"
	runprint $(ls -al | grep ballots)
fi

# tps reports directory must exist.
if ! ls -al | grep tpsreports >> $LOG
then
	echo "L: no tpsreports dir"
fi

# there should be a special 'tps' user
if ! grep -E "^tps" group | sed -r "s/^tps:x:(.+):.+/\1/" >> $LOG
then
	echo "M: no tps user"
fi

# the tpsreports directory should be owned tps with group wheel
if ! ls -al | grep tpsreports | grep -E "$TPS.+$WHEEL" >> $LOG
then
	echo "N: tpsreports ownership not correct, should be '$TPS $WHEEL'"
	runprint $(ls -al | grep tpsreports)
fi



# the permissions mode on tpsreports should be dwrxrws--T
if ! ls -al | grep tpsreports | grep -E 'drwxrws--T' >> $LOG
then
	echo "O: tpsreports perms not correct (s.b. 3770/dwrxrws--T):"
	runprint $(ls -al | grep tpsreports)
fi

# larry, moe, and curly should be in the emp group
user_in_group "larry" "emp" "P"
user_in_group "moe" "emp" "P"
user_in_group "curly" "emp" "P"
# the last letter above (e.g., P) indicates the question column for grading

# admins should NOT be in the emp group
GNAME="emp"
for UNAME in ken 
do 
	user_in_group "$UNAME" "$GNAME" "quiet"
	if [[ $GRP_BOOL == "in" ]]
	then
		echo "Q: $UNAME is in $GNAME but shouldn't be!"
		runprint $(grep ^$GNAME group)
		runprint $(grep ^$UNAME passwd)
	fi
done

# ken should be in wheel
user_in_group "ken" "wheel" "R"

# emps should NOT be in the wheel group
#if grep ^wheel group | grep -E "larry|moe|curly" >> $LOG
#then
#	echo "Q: an employee is in the wheel group!"
#	runprint $(grep ^wheel group)
#fi
GNAME="wheel"
for UNAME in larry moe curly
do 
	user_in_group "$UNAME" "$GNAME" "quiet"
	if [[ $GRP_BOOL == "in" ]]
	then
		echo "S: $UNAME is in $GNAME but shouldn't be!"
		runprint $(grep ^$GNAME group)
		runprint $(grep ^$UNAME passwd)
	fi
done



# admin group special memberships
unset ADMINERR
if ! grep ^ken group | grep moe | grep curly  >> $LOG
then
	ADMINERR=1
else
	if grep ^ken group | grep -E "larry" >> $LOG
	then
		ADMINERR=1
	fi
fi

if [[ ! -z $ADMINERR ]]
then
	echo "NOTE: missing or extra user in ken, s.b.: moe and curly (any order)"
	echo "There's no column for this in the spreadsheet at this time.
	runprint $(grep ^ken group)
fi

echo "Done."
popd >> $LOG
