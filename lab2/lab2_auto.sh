#!/bin/bash

# preparision
working_base_directory=$(pwd)
if [ ! -d $working_base_directory/logs ]; then
    mkdir logs
fi
if [ ! -d $working_base_directory/works ]; then
    echo "Expected directory, which contains all the students' works, not found: ./works" 1>&2
    exit 1
fi

# execute all the student files in the working_base_directory
# notice that the file name has to be ended as .tar.gz, otherwise the student work will not be graded
for file_abs_path in $working_base_directory/works/*;
do
    file_name=$(basename "$file_abs_path")
    student=$(echo "$file_name" | sed "s#Lab 2  Using Encryption_\(.*\)_attempt_.*#\1#")

    student_dir="$working_base_directory/logs/$student"
    mkdir $student_dir
    logfile=$student_dir/$student.log

    echo "================= Grading: $student ==========================" >> $logfile

    # unzip
    unzip "$file_abs_path" -d "$student_dir" 2>>$logfile
    # if it cannot be unzipped, skip the rest execution for this file
    if [ $? -ne 0 ]; then
        continue
    fi

    # import student's gpg public key
    echo "================== Importing GPG Public Key ==================" >> $logfile
    # TODO: The following command will not return non-0 even when nothing is found
    # the | egrep ".*" workaround will not work since we need to record the exit code of execution, too
    find $student_dir -iname "${student}.public.gpg-key" -exec gpg --import {} + 2>>$logfile
    if [ $? -ne 0 ]; then
        echo "[Error]: Unable to import gpg public key" >> $logfile
    fi
    echo "==============================================================" >> $logfile

    # verify signed message
    echo "================== Verifying Signed File =====================" >> $logfile
    find $student_dir -iname "${student}.txt.sig" -exec gpg --verify {} + 2>>$logfile
    if [ $? -ne 0 ]; then
        echo "[Error]: Unable to verify the signature" >> $logfile
    fi
    echo "==============================================================" >> $logfile

    # decrypt encrypted message to Jerry
    # Note: commenting out the following if you are not using Qubes OS
    #find $student_dir -iname "*${student}.txt.gpg" -exec gpg --decrypt {} + 2>>logfile
    echo "=================== Decrypting Message =======================" >> $logfile
    find $student_dir -iname "*${student}.txt.gpg" -exec qubes-gpg-client --decrypt {} + 2>>$logfile
    if [ $? -ne 0 ]; then
        echo "==========================================================" >> $logfile
        echo "[Error]: Unable to decrypt the message" >> $logfile
    fi
    echo "==============================================================" >> $logfile
done
