app_name=$1

# Check for existing pipelines on Heroku. If it already exists, delete it
existing_pipelines=$(heroku pipelines)
while read -r line; do
  if [[ ${line} == "${app_name}" ]]; then
    echo "Pipeline already exists. Destroying existing app..."
    heroku apps:destroy --app "${app_name}" -c "${app_name}"
  fi
done <<< "${existing_apps}"

heroku apps:create migarjo-ruby-books --buildpack https://github.com/heroku/heroku-buildpack-ruby.git

heroku pipelines:create migarjo-ruby-books \
  --app=migarjo-ruby-books \
  --stage=production

git push heroku master

heroku run rake db:migrate

heroku ps:restart
