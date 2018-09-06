#########################
# Ruby install script   #
# Used to do ruby stuff #
#########################

######################
#### Sub Routines ####
######################
Check_Shell()
{
   # Check the shells error code when a step has completed
   if [ $? -eq 0 ]; then
      # The shell returned 0
      echo "Step was successful"
   else
      # The shell returned non 0
      echo "ERROR! Shell error code returned:[$?]!"
      exit 1
   fi
}

##############
#### MAIN ####

echo "Getting ruby version"
ruby -v
#echo "getting bundle env"
#bundle env
#echo "getting rails version"
#rails -v

# bundle install
echo "-------------------------------------------------"
echo "------------------------------------"
echo "---- Running the bundle install ----"
echo "------------------------------------"
gem update bundler ; bundle install --path=vendor/bundle --jobs=4 --retry=3

# Check the shell error code
Check_Shell

# Were done here...
echo "-------------------------------------------------"
echo "Step has completed"
