app_name=$1

# Check for existing apps on Heroku. If it already exists, delete it
existing_apps=$(heroku apps)
echo ${existing_apps}
while read -r line; do
  if [[ ${line} == "${app_name}" ]]; then
    echo "App already exists. Destroying existing app..."
    heroku apps:destroy --app "${app_name}" -c "${app_name}"
  fi
done <<< "${existing_apps}"

heroku apps:create migarjo-ruby-books --buildpack https://github.com/heroku/heroku-buildpack-ruby.git


git push heroku master

heroku run rake db:migrate

heroku ps:restart
