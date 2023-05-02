# Momo Store aka Пельменная №2

**Адрес:**
https://momo.surinvas.ru/

<img width="900" alt="image" src="https://user-images.githubusercontent.com/9394918/167876466-2c530828-d658-4efe-9064-825626cc6db5.png">

## Устройство репозитория

Исходный код приложения "**Momo Store**" хранится в git-репозитории "momostore". 
Приложение поделено на две части **frontend** (JavaScript/NodeJS ) и **backend** (Go). 
Компоненты частей распологаются в репозитории в одноимённых директориях.

Основной сценарий по развёртыванию необходимой инфраструктуры для приложения так же хранится в git-репозитории (IaC).

Директории: 

**./terraform/S3buckets**

Сценарий создания бакетов для статики сайта и для хранения состояния terraform (.tf)

**./terraform/kubecluster**

Сценарий, который включает в себя:
- необходимые аккаунты для работы отдельных сервисов (managed kubernetes, ingress)
- назначение аккаунтам ролей
- генерация ключа
- сетевая стуктура (рабочая сеть, подсети)
- сетевые доступы и правила
- группы безопасности
- описание характеристик создаваемых worker nodes

**yc_kubectl_configng.sh**

Скрипт служит для настройки с помощью CLI YC kubeconfig и доступа к кластеру kubernetes из CI

## Развёртывание приложения

Развёртывание (deploy) приложения осуществляется с помощью работы (job) в пайплане (pipline) в Gitlab CI.
Изменение (commit) в любом файле одной из директорий (backend или frontend) приводит к запуску пайпланов по каждой части отдельно (gitlab module-pipelines).

Процесс состоит из двух пайпланов и пяти работ:

**Пайплайн 1 (Downstream):**

1. Тестирование (SAST, Sonarqube, go-tests)
1. Сборка (в docker image, хранение gitlab docker registry)
1. Обновление версии helm-chart

**Пайплайн 2 (trigger):**

1. Развёртывание приложения в кластере kubernetis с помощью helm (deploy)
1. Отправка новой версии helm-chart приложения в репозиторий Nexus (https://nexus.k8s.praktikum-services.tech/repository/momo-store-helm-surin-vasiliy-11/)

**Пайплайны описаны в файлах: **

- .gitlab-ci.yml (stages: - module-pipelines)
- bb.yml (downstream backend)
- fb.yml (downstream frontend)
- deploy-upload-chart.yml (trigger, развёртывание приложения и отправка helm-chart в репозиторий)

**Правила сборки docker-image описаны в файлах:**

- docker-compose.yml
- ./backend/Dockerfile
- ./frontend/Dockerfile
- docker-compose.yml
- .env.backend и .env.frontend (необходимые переменные)

**Скрипты:**

helmchart_ver2.sh - версионирование helm-chart-а приложения (запрос актуальной версии с помощью docker manifest, внесение изменений git clone, cat/sed, git push)

**Переменные:**

Помимо служебных переменных CI_ , необходимые переменные сохранены в Settings/CI\CD/Variables

Сборка частей приложений

**Frontend**

```bash
npm install
NODE_ENV=production VUE_APP_API_URL=http://localhost:8081 npm run serve
```

**Backend**

```bash
go run ./cmd/api
go test -v ./... 
```

## Релизный цикл/версионирование

Подразумевается классическая схема:

- S - минимальные изменения, как правило, исправление багов (изменение третьей цифры номера версии)
- M - более серьезные изменения, в частности, правка БД (изменение второй цифры номера версии)
- L - действительно масштабные изменения (изменение первой цифры номера версии)

В нашем случае используется схема "S", то есть **1.0.<версия>**
Третье значение привязано к номеру пайплайна (переменная **CI_PIPELINE_ID**).
Версия назначается тегу docker-образа и версии helm-chart (общая версия+версия части приложения - backend или frontend)
Версии "M" и "L" меняются в описании пайплайна руками, после например оценки важности и масштабности вносимых изменений.
