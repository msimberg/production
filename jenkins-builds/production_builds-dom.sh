#!/bin/bash -l

# expects production file as command line argument
if [ -z "$1" ]; then
 echo -e "\n Error! Please insert production file on command line! \n"
 exit 1
else
 filename=$(basename $1)
fi

# defines OS VERSION and ARCH parsing the selected production filename
OS=${filename%-[0-9]*.[0-9]*-[a-z]*}
ARCH=${filename#$OS-[0-9]*.[0-9]*-}
echo -e "\n Production file is $1: \n - OS VERSION is $OS \n - ARCH is $ARCH"

# list of builds
list=$(cat $1 | grep -v ^#)
echo -e "\n List of production builds: \n$list"

# cscs ARCH setup
module load daint-$ARCH
echo -e "\n Loading modules: \n - module load daint-$ARCH"

# EasyBuild setup
echo -e "\n EasyBuild setup: \n source $PWD/easybuild/setup.sh $APPS/UES/jenkins/$OS/$ARCH $PWD"
source $PWD/easybuild/setup.sh $APPS/UES/jenkins/$OS/$ARCH $PWD

# start time
echo -e "\n Builds started on $(date)"

# loop over list 
for build in $list; do
# build
 fullpath=$(eb --search $build | grep -v = | awk '{print $2}');
 sed "s/44_GA_2.2.7_g4a6c213-2.1/34_2.2.5_g8ce7a9a-2.1/" $fullpath > ./$build
 echo -e "\n eb ./$build -r --modules-header=$APPS/UES/login/daint-${ARCH}.h \n"
 eb ./$build -r --modules-header=$APPS/UES/login/daint-${ARCH}.h
 rm -f ./$build
# define name and version of the current build
 version=$(basename ${build#[aA-z-Z]*-} .eb)
 name=${build%-${version}.eb}
# create default
 echo -e "\n Creating file ${EASYBUILD_PREFIX}/modules/all/${name}/.version to set ${version} as default for ${name}"
 cat > ${EASYBUILD_PREFIX}/modules/all/${name}/.version<<EOF 
#%Module
set ModulesVersion "${version}"
EOF
# change permissions for selected builds (note that $USER needs to be member of the group to use the command chgrp)
 if [[ ${name} =~ "CPMD" || ${name} =~ "VASP" ]]; then
  echo -e "\n Changing group ownership and permissions for ${name} folders:\n - ${EASYBUILD_PREFIX}/software/${name}"
  chgrp ${name,,} -R ${EASYBUILD_PREFIX}/software/${name}
  chmod -R o-rwx ${EASYBUILD_PREFIX}/software/${name}/*
  echo -e "\n Appending warning to ${name} modulefile for users not belonging to ${name,,} group:\n - ${EASYBUILD_PREFIX}/modules/all/${name}/${version}"
  echo -e "if { [lsearch [exec groups] \"${name,,}\"]==-1 && [module-info mode load] } {\n puts stderr \"Access to ${name} executables and library files is only allowed to users with a valid ${name} license\"\n}" >> ${EASYBUILD_PREFIX}/modules/all/${name}/${version}
 fi
done 

# end time
echo -e "\n Builds ended on $(date)"
