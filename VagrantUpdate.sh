#!/bin/bash

# This script updates osis-converters and its Virtual Machine

# Make sure we're in osis-converters root dir
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Stash any local changes
git stash
echo .
echo ANY LOCAL CHANGES TO OSIS-CONVERTERS HAVE BEEN STASHED!!
echo TO RE-APPLY ANY CHANGES YOU MADE, USE: git stash apply
echo .

# Pull any remote updates from master
git checkout master
git pull

# VM must be running before ssh will work
vagrant up

# Running VagrantProvision.sh on the VM will update the VM's installed software
vagrant ssh -c "bash /vagrant/VagrantProvision.sh"
