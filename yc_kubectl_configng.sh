#!/bin/bash

#Скачиваем и устанавливаем CLI YC (неинтерактивный режим)
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh |     bash -s -- -i ./yc -n
#Переходим в каталог ./yc/bin
cd ./yc/bin
#Задаём конфигурацию профиля sa
./yc config set service-account-key ${YC_SA_KEY}
./yc config set cloud-id ${YC_CLOUD_ID}
./yc config set folder-id ${YC_FOLDER_ID}
#Проверяем видимость кубекластера в YC
./yc managed-kubernetes cluster list
#Конфигурируем kubeconfig
./yc managed-kubernetes cluster get-credentials ${YC_CLUSTER_ID} --external
#Добавляем manespace в kubeconfig
sed -i '9i\    namespace: momo-vas' /root/.kube/config
