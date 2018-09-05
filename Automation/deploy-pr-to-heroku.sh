org_name=$1
repo_name=$2
branch_name=$3

api_domain="https://github.michaeljohnson.io/api/v3"
git_domain="git@github.michaeljohnson.io"

pr_api_url="${api_domain}/repos/${org_name}/${repo_name}/pulls?base=master&head=${org_name}:${branch_name}"

pr_response=$(curl --request GET \
  --url ${pr_api_url} \
  --header 'authorization: Bearer ${GITHUB_TOKEN}')

pr=$(echo ${pr_response} | jq '.[].number')

app_name="${pipeline_name}-pr-${pr}"

git clone ${git_domain}:${org_name}/${repo_name}.git ${pipeline_name} -c http.sslVerify=false

cd ${pipeline_name}

git checkout ${branch_name}


# Check for existing app on Heroku. If it already exists, delete it
existing_apps=$(heroku apps)
while read -r line; do
  if [[ ${line} == "${app_name}" ]]; then
    echo "Deployment already exists. Destroying existing app..."
    heroku apps:destroy --app "${app_name}" -c "${app_name}"
  fi
done <<< "${existing_apps}"


# Create a deployment in GitHub
generate_deploy_body() {
  cat<<EOF
  {
    "ref": "${branch_name}",
    "environment": "review"
  }
EOF
}

deploy_response=$(curl -X POST -k \
  --url ${api_domain}/repos/${org_name}/${repo_name}/deployments \
  --header 'authorization: Bearer ${GITHUB_TOKEN}' \
  --header 'content-type: application/json' \
  --data "$(generate_deploy_body)")

deployment_id=$(echo ${deploy_response} | jq '.id')

# Send a pending status to the GitHub Deployment
generate_status_body() {
  cat<<EOF
  {
    "state": "pending",
    "log_url": "https://dashboard.heroku.com/apps/${app_name}/logs"
  }
EOF
}

curl -X POST -k \
  --url ${api_domain}/repos/${org_name}/${repo_name}/deployments/${deployment_id}/statuses \
  --header 'authorization: Bearer ${GITHUB_TOKEN}' \
  --header 'content-type: application/json' \
  --header 'Accept: application/vnd.github.ant-man-preview+json' \
  --data "$(generate_status_body)"


# Create Heroku App for this PR and add it to the pipeline
heroku apps:create ${app_name} --buildpack https://github.com/heroku/heroku-buildpack-ruby.git

heroku pipelines:add ${pipeline_name} \
  --app=${app_name} \
  --stage=review

git push heroku +HEAD:master
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

# Send deployment results to GitHub
if [[ ${heroku_status} == *"up"* ]]; then
  generate_status_body() {
    cat<<EOF
    {
      "state": "success",
      "log_url": "https://dashboard.heroku.com/apps/${app_name}/logs",
      "environment_url": "https://${app_name}.herokuapp.com"
    }
EOF
  }

  curl -X POST -k \
    --url ${api_domain}/repos/${org_name}/${repo_name}/deployments/${deployment_id}/statuses \
    --header 'authorization: Bearer ${GITHUB_TOKEN}' \
    --header 'content-type: application/json' \
    --header 'Accept: application/vnd.github.ant-man-preview+json' \
    --data "$(generate_status_body)"
else
  echo "Error: Heroku deployment failed. Current dyno status is:"
  echo ${heroku_status}

  generate_status_body() {
    cat<<EOF
    {
      "state": "failure",
      "log_url": "https://dashboard.heroku.com/apps/${app_name}/logs",
    }
EOF
  }

  curl -X POST -k \
    --url ${api_domain}/repos/${org_name}/${repo_name}/deployments/${deployment_id}/statuses \
    --header 'authorization: Bearer ${GITHUB_TOKEN}' \
    --header 'content-type: application/json' \
    --header 'Accept: application/vnd.github.ant-man-preview+json' \
    --data "$(generate_status_body)"
fi

# Clean up after ourselves
cd ..
rm -rf ${pipeline_name}
