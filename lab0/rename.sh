#!/bin/bash

set -x
working_base_directory=$(pwd)

cd $working_base_directory/works

rename -v 's/Lab 0  Introduction to Linux UNIX_(.*)_attempt_(.*)-intro\.tar\.gz/-intro\.tar\.gz/' *

cd $working_base_directory
