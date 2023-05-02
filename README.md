# Momo Store aka Пельменная №2

**Адрес:**
https://momo.surinvas.ru/

<img width="900" alt="image" src="https://user-images.githubusercontent.com/9394918/167876466-2c530828-d658-4efe-9064-825626cc6db5.png">

## Устройство репозитория

Исходный код приложения "Momo Store" хранится в git-репозитории "momostore". 
Приложение поделено на две части frontend (JavaScript/NodeJS ) и backend (Go). 
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




## Frontend

```bash
npm install
NODE_ENV=production VUE_APP_API_URL=http://localhost:8081 npm run serve
```

## Backend

```bash
go run ./cmd/api
go test -v ./... 
```
