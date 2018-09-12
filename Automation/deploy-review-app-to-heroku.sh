org_name=$1
repo_name=$2
app_name=$3

echo "TOKEN:"
echo $github_token

# Check for existing app on Heroku. If it already exists, delete it
existing_apps=$(heroku apps)
while read -r line; do
  if [[ ${line} == "${app_name}" ]]; then
    echo "Deployment already exists. Destroying existing app..."
    heroku apps:destroy --app "${app_name}" -c "${app_name}"
  fi
done <<< "${existing_apps}"

# Create Heroku App for this PR and push the code for initial deployment
heroku apps:create ${app_name} --buildpack https://github.com/heroku/heroku-buildpack-ruby.git
git push heroku +HEAD:master

# Run database migration
heroku run rake db:migrate
heroku ps:restart
heroku_status=$(heroku ps --app ${app_name} | grep web.1)

# Wait for Heroku deployment to finish
until [[ ${heroku_status} != *"starting"* ]]
do
  heroku_status=$(heroku ps --app ${app_name} | grep web.1)
  echo ${heroku_status}
  sleep 5
done

# Ensure Successful Deployment
if [[ ${heroku_status} != *"up"* ]]; then
  echo "Error: Heroku deployment failed. Current dyno status is:"
  echo ${heroku_status}
  exit 1
fi
