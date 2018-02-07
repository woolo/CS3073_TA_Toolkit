#!/bin/bash

set -x
working_base_directory=$(pwd)

cd $working_base_directory/works

# The syntax is for Perl rename, which is used by Debian by default.
# For Feodora users, see here: https://stackoverflow.com/questions/22577767/get-the-perl-rename-utility-instead-of-the-built-in-rename

rename -v 's/Lab 0  Introduction to Linux UNIX_(.*)_attempt_(.*)-intro\.tar\.gz/-intro\.tar\.gz/' *

cd $working_base_directory
