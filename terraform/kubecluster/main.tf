############################################################################
# Данные YC test
############################################################################

locals {
  cloud_id    = "b1g5vaj7usev1602ttda"
  folder_id   = "b1gm1ae6uts1pr387al2"
  k8s_version = "1.22"
  sa_name     = "k8saccount"
#  sa_name = "service-acc"
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
    key        = "tf_state_managed_kubernetes/terraform.tfstate"
    access_key = "ключ_доступа"
    secret_key = "ключ_секрет"

    skip_region_validation      = true
    skip_credentials_validation = true
  }

}

############################################################################
# Токен для работы с облаком
############################################################################

provider "yandex" {
#  zone = "ru-central1-a"
  folder_id = local.folder_id
  token = "токен са"
}

############################################################################
# Создание необходимых сервисных аккаунтов
############################################################################

#Аккаунт для кластера k8s
resource "yandex_iam_service_account" "k8saccount" {
  name        = local.sa_name
  description = "K8S zonal service account"
}

##Аккаунт для ingress-контроллера ALB
resource "yandex_iam_service_account" "ingressaccount" {
  name        = "ingressaccount"
  description = "acc for ingress"
  folder_id   = "b1gm1ae6uts1pr387al2"
}

############################################################################
# Назначение ролей созданным сервисным аккаунтам
############################################################################


#Роли для аккаунта k8saccount

resource "yandex_resourcemanager_folder_iam_member" "k8s-clusters-agent" {
  # Сервисному аккаунту назначается роль "k8s.clusters.agent".
  folder_id = local.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8saccount.id}"
}


resource "yandex_resourcemanager_folder_iam_member" "vpc-public-admin" {
  # Сервисному аккаунту назначается роль "vpc.publicAdmin".
  folder_id = local.folder_id
  role      = "vpc.publicAdmin"
  member = "serviceAccount:${yandex_iam_service_account.k8saccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  member = "serviceAccount:${yandex_iam_service_account.k8saccount.id}"
}


#Роли для аккаунта ingressaccount

resource "yandex_resourcemanager_folder_iam_binding" "ingressaccount-albe" {
  #Сервисному аккаунту назначается роль "alb.editor"
  folder_id   = "b1gm1ae6uts1pr387al2"
  role        = "alb.editor"
  members     = [
    "serviceAccount:${yandex_iam_service_account.ingressaccount.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "ingressaccount-vpcpa" {
  #Сервисному аккаунту назначается роль "vpc.publicAdmin"  
  folder_id   = "b1gm1ae6uts1pr387al2"
  role        = "vpc.publicAdmin"
  members     = [
    "serviceAccount:${yandex_iam_service_account.ingressaccount.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "ingressaccount-cmd" {
  #Сервисному аккаунту назначается роль "certificate-manager.certificates.downloader"
  folder_id   = "b1gm1ae6uts1pr387al2"
  role        = "certificate-manager.certificates.downloader"
  members     = [
    "serviceAccount:${yandex_iam_service_account.ingressaccount.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "ingressaccount-cv" {
  #Сервисному аккаунту назначается роль "compute.viewer"
  folder_id   = "b1gm1ae6uts1pr387al2"
  role        = "compute.viewer"
  members     = [
    "serviceAccount:${yandex_iam_service_account.ingressaccount.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "ingressaccount-impul" {
  #Сервисному аккаунту назначается роль "container-registry.images.puller"
  folder_id   = "b1gm1ae6uts1pr387al2"
  role        = "container-registry.images.puller"
  members     = [
    "serviceAccount:${yandex_iam_service_account.ingressaccount.id}",
  ]
}

############################################################################
# Ключи
############################################################################
resource "yandex_kms_symmetric_key" "kms-key" {
  # Ключ для шифрования важной информации, такой как пароли, OAuth-токены и SSH-ключи.
  name              = "kms-key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 год.
}

resource "yandex_kms_symmetric_key_iam_binding" "viewer" {
  symmetric_key_id = yandex_kms_symmetric_key.kms-key.id
  role             = "viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8saccount.id}",
  ]
}

############################################################################
# Создаём сеть и адресацию
############################################################################

resource "yandex_vpc_network" "k8snet" {
  name = "k8snet"
}

resource "yandex_vpc_subnet" "k8ssubnet" {
  name = "subnet-for-nodes"
  description = "Subnet for worker nodes"
  v4_cidr_blocks = ["10.1.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8snet.id
}

############################################################################
# Создаём кластер "k8s-zonal"
############################################################################

resource "yandex_kubernetes_cluster" "k8s-zonal" {
  name = "kubecluster-for-momoapp"
  network_id = yandex_vpc_network.k8snet.id
  master {
    version = local.k8s_version
    zonal {
      zone      = yandex_vpc_subnet.k8ssubnet.zone
      subnet_id = yandex_vpc_subnet.k8ssubnet.id
    }
    public_ip = true
    security_group_ids = [
    yandex_vpc_security_group.for-k8s-nodegroup.id,
    yandex_vpc_security_group.api-for-k8s.id
    ]
  }
  service_account_id      = yandex_iam_service_account.k8saccount.id
  node_service_account_id = yandex_iam_service_account.k8saccount.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-clusters-agent,
    yandex_resourcemanager_folder_iam_member.vpc-public-admin,
    yandex_resourcemanager_folder_iam_member.images-puller
  ]
  kms_provider {
    key_id = yandex_kms_symmetric_key.kms-key.id
  }
}

############################################################################
# Описываем четыре необходимых security_group
############################################################################


#Группа for-k8s-nodegroup

resource "yandex_vpc_security_group" "for-k8s-nodegroup" {
  name        = "for-k8s-nodegroup"
  description = "Правила группы обеспечивают базовую работоспособность кластера. Примените ее к кластеру и группам узлов."
  network_id  = yandex_vpc_network.k8snet.id
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol       = "ANY"
    description    = "Правило разрешает взаимодействие под-под и сервис-сервис. Укажите подсети вашего кластера и сервисов."
    v4_cidr_blocks = concat(yandex_vpc_subnet.k8ssubnet.v4_cidr_blocks, ["10.1.0.0/16", "10.112.0.0/16", "10.96.0.0/16"])
#    v4_cidr_blocks = concat(yandex_vpc_subnet.k8ssubnet.v4_cidr_blocks)
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "ICMP"
    description    = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks = ["172.16.0.0/12", "10.0.0.0/8", "192.168.0.0/16"]
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
  depends_on = [
    yandex_vpc_network.k8snet
  ]
}


#Группа pub-for-nodegroup

resource "yandex_vpc_security_group" "pub-for-nodegroup" {
  name        = "pub-for-nodegroup"
  description = "Правила группы разрешают подключение к сервисам из интернета. Примените правила только для групп узлов."
  network_id  = yandex_vpc_network.k8snet.id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавьте или измените порты на нужные вам."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
  depends_on = [
    yandex_vpc_network.k8snet
  ]
}


#Группа ssh-for-nodegroup

resource "yandex_vpc_security_group" "ssh-for-nodegroup" {
  name        = "ssh-for-nodegroup"
  description = "Правила группы разрешают подключение к узлам кластера по SSH. Примените правила только для групп узлов."
  network_id  = yandex_vpc_network.k8snet.id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к узлам по SSH с указанных IP-адресов."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  depends_on = [
    yandex_vpc_network.k8snet
  ]
}


# Группа api-for-k8s (значение v4_cidr_blocks)

resource "yandex_vpc_security_group" "api-for-k8s" {
  name        = "api-for-k8s"
  description = "Правила группы разрешают доступ к API Kubernetes из интернета. Примените правила только к кластеру."
  network_id  = yandex_vpc_network.k8snet.id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 6443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
  depends_on = [
    yandex_vpc_network.k8snet
  ]
}

############################################################################
# Создаём группу узлов "k8s-node-group"
############################################################################

resource "yandex_kubernetes_node_group" "k8s-node-group" {
#Указываем в каком кластере
  cluster_id = yandex_kubernetes_cluster.k8s-zonal.id
#Задаём имя
  name       = "k8s-node-group"
#Шаблон инстанса
  instance_template {
    name       = ""
    platform_id = ""
#Сетевой интерфейс с nat
    network_interface {
      nat                = true
#Указываем подсеть
      subnet_ids         = [yandex_vpc_subnet.k8ssubnet.id]
#Обязательно добавляем в нужные нам yandex_vpc_security_group
      security_group_ids = [
        yandex_vpc_security_group.pub-for-nodegroup.id,
        yandex_vpc_security_group.ssh-for-nodegroup.id,
        yandex_vpc_security_group.for-k8s-nodegroup.id
      ]
    }
    container_runtime {
     type = "containerd"
    }
#    labels {
#      "n"="1"
#    }
  }
  scale_policy {
    fixed_scale {
      size = 3
    }
  }
  depends_on = [
    yandex_kubernetes_cluster.k8s-zonal
  ]
}

############################################################################
# Конец
############################################################################
