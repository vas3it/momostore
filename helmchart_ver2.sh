#!/bin/bash

#Недостаток прав при пуше (403)
#Почему не CI_JOB_TOKEN?
#https://forum.gitlab.com/t/pushing-back-changes-with-ci-job-token-possible/78972

#Решение - PAT
#https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.html

CONTAINER_REGISTRY="gitlab.praktikum-services.ru:5050/v.surin/momostore"

git config --global user.email "$GITLAB_USER_EMAIL"
git config --global user.name "update-bot"

mkdir -p /tmp/momo-store-iac && cd $_
git clone https://gitlab-ci-token:${PAT_TOKEN}@gitlab.praktikum-services.ru/v.surin/momostore.git .
git switch $CI_COMMIT_REF_NAME

# Update helm-chart version
sed -i -e "s/^appVersion.*/appVersion: $VERSION/" -e "s/^version.*/version: $VERSION/" ./momo-store-chart/Chart.yaml

# Update backend version if docker image was build
if docker manifest inspect "$CONTAINER_REGISTRY/momo-backend:$VERSION" > /dev/null ; then
    sed -i -e "/^  - name: backend$/{n;s/^    version.*/    version: $VERSION/;}" ./momo-store-chart/Chart.yaml
    sed -i -e "s/^appVersion.*/appVersion: $VERSION/" -e "s/^version.*/version: $VERSION/" ./momo-store-chart/charts/backend/Chart.yaml
    echo "Backend version has been updated."
else
    echo "Backend docker image didn't build in this pipeline.\nBackend version has not been updated."
fi

# Update frontend version if docker image was build
if docker manifest inspect "$CONTAINER_REGISTRY/momo-frontend:$VERSION" > /dev/null ; then
    sed -i -e "/^  - name: frontend$/{n;s/^    version.*/    version: $VERSION/;}" ./momo-store-chart/Chart.yaml
    sed -i -e "s/^appVersion.*/appVersion: $VERSION/" -e "s/^version.*/version: $VERSION/" ./momo-store-chart/charts/frontend/Chart.yaml
    echo "Frontend version has been updated."
else
    echo "Frontend docker image didn't build in this pipeline.\nFrontend version has not been updated."
fi

git commit -a -m "Updated to version $VERSION"
git push origin $CI_COMMIT_REF_NAME

exit 0
