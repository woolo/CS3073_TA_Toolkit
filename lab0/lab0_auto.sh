#!/bin/bash

set -x

# The function implicitly
function checksum_file() {
    cd $working_base_directory/top_secret
    echo "===================================================================" >> $logfile
    echo "================== Checksum against pictures ======================" >> $logfile
    echo "===================================================================" >> $logfile
    sha512sum -c $working_base_directory/valid.sha512 >> $logfile 2>&1
}

function file_path() {
    cd $working_base_directory/top_secret
    echo "===================================================================" >> $logfile
    echo "================ Look for file path in answers.txt ================" >> $logfile
    echo "===================================================================" >> $logfile
    ## declare an array variable
    declare -a arr=("/usr/share/pixmaps/abcd123cs3073.jpg" "/var/log/CS3073sup.jpg" "/etc/foocs3073.jpg" "/.hidden/xyz482CS3073.JPG")

    ## now loop through the above array
    for path in "${arr[@]}"
    do
        cat answers.txt | grep -i "$path" >> $logfile 2>&1

        # when nothing is greped, exit echo will not be 0
        if [ "$?" -ne 0 ]; then
            echo "File path $path not found in answers.txt" >> $logfile
        fi
    done
}

function file_inspect(){
    cd $working_base_directory/top_secret
    echo "===================================================================" >> $logfile
    echo "========================== cat answers.txt ========================" >> $logfile
    echo "===================================================================" >> $logfile
    cat answers.txt >> $logfile 2>&1
    echo "===================================================================" >> $logfile
    echo "========================= cat diskfree.txt ========================" >> $logfile
    echo "===================================================================" >> $logfile
    cat diskfree.txt >> $logfile 2>&1
}

# preparisions
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
for file_abs_path in $working_base_directory/works/*
do
    file_name=$(basename $file_abs_path)
    student=$(echo "${file_name%%.*}" | sed s/-intro//)
    logfile=$working_base_directory/logs/$student.log

    echo "================ Grading: $file_name ==================" >> $logfile
    # decompress
    tar -xvf $file_abs_path 2>> $logfile

    # if it cannot be decompressed, skip the rest execution for this file
    if [ "$?" -ne 0 ]; then
        continue
    fi

    # checksum for the picuture, making sure they are not currupted
    checksum_file

    # find file path indicated by students in their answers.txt
    file_path

    # check the exisitence of and print answers.txt and freedisk.txt
    file_inspect

    cd $working_base_directory
    rm -r $working_base_directory/top_secret
done
