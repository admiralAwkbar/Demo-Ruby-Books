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

# Generate database.yml
echo "-------------------------------------------------"
echo "-----------------------------------------"
echo "---- Generating database information ----" 
echo "-----------------------------------------"
mkdir -p config
echo 'test:
  database: ruby_test
  adapter: postgresql
  encoding: SQL_ASCII
  username: psuser
  password: password1
  host: localhost
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
' > config/database.yml

# Check the shell error code
Check_Shell

echo "-------------------------------------------------"
echo "-------------------------------"
echo "---- Starting Postrgess DB ----"
echo "-------------------------------"
#sed -i 's/local   all             postgres                                peer/local   all             postgres                                md5/g' /etc/postgresql/9.5/main/pg_hba.conf
service postgresql start
service postgresql status
echo "creating user"
su - postgres -c "psql -c \"CREATE ROLE psuser WITH LOGIN PASSWORD 'password1';\""
su - postgres -c "psql -c \"CREATE DATABASE ruby_test OWNER psuser;\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ruby_test to psuser;\""
su - postgres -c "psql -c \"ALTER USER psuser CREATEDB;\""

service postgresql stop
service postgresql start
service postgresql status

#echo "Cat of file"
#cat /etc/postgresql/*/main/pg_hba.conf

# Check the shell error code
Check_Shell

# rake db:create db:schema:load
echo "-------------------------------------------------"
echo "-------------------------------"
echo "---- Exporting Environment ----" 
echo "-------------------------------"
export RAILS_ENV="test"
export RACK_ENV="test"
bundle exec rake db:create db:schema:load --trace

# Check the shell error code
Check_Shell

# Were done here...
echo "-------------------------------------------------"
echo "Step has completed"
