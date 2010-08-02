#!/bin/bash

# we want to pull the current directory out of the table of contents links, 
#so get the current directory and add backslashes so we can use it in a sed regex
echo `pwd` > temp
sed "s/\\//\\\\\\//g" temp > temp2
dir=`cat temp2`
rm temp
rm temp2

cd target

# replace the current working directory
sed s/file:\\/\\/$dir\\///g book/index.html > book/index2.html

# replace the index_files path (where the images are)
sed s/\\.\\/index_files\\///g book/index2.html > book/index3.html

# move the index.html file back into place with strings replaced
mv book/index3.html book/index.html
rm book/index2.html

# move the images out so it's a flat directory structure
mv book/index_files/* book/
rm -rf book/index_files

# create the zip file
zip book.zip book/
zip book.zip book/*
