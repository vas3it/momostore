############################################################################
# Данные YC test
############################################################################

locals {
  cloud_id    = "b1g5vaj7usev1602ttda"
  folder_id   = "b1gm1ae6uts1pr387al2"
  k8s_version = "1.22"
  sa_name     = "storageaccount"
}

############################################################################
# Указание на провайдера
############################################################################

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

############################################################################
# Хранение файла с состоянием в бакете S3
############################################################################

backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "momo-terraform"
    region     = "ru-central1"
    key        = "tf_state_s3/terraform.tfstate"
    access_key = "YCAJEEdjCVS1iAVZm1XIF1L97"
    secret_key = "YCOWwd7hmih0ChCRUGyx-86yDb1hhZ7GKuSiBGck"

    skip_region_validation      = true
    skip_credentials_validation = true
  }

}
############################################################################
# Токен для работы с облаком
############################################################################

provider "yandex" {
  token = "y0_AgAAAAAR24UWAATuwQAAAADQqZsYNRHtBszARiGvJBy5AEOMhVbYGHo"
  cloud_id  = "b1g5vaj7usev1602ttda"
  folder_id = "b1gm1ae6uts1pr387al2"
  zone = "ru-central1-a"
}

############################################################################
# Создание необходимых сервисных аккаунтов
############################################################################

resource "yandex_iam_service_account" "storageaccount" {
  name = "storageaccount"
  description = "S3 zonal service account"
}

############################################################################
# Назначение ролей созданным сервисным аккаунтам
############################################################################

resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = "b1gm1ae6uts1pr387al2"
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storageaccount.id}"
}

############################################################################
# Статический ключ
############################################################################

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.storageaccount.id
  description        = "static access key for object storage"
}

############################################################################
# Создание бакетов (для состояний terraform и статики сайта momo)
############################################################################

resource "yandex_storage_bucket" "momo-terraform" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "momo-terraform"
}

resource "yandex_storage_bucket" "momo-pictures" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "momo-pictures"
  anonymous_access_flags {
    read = true
    list = false
  }
}

