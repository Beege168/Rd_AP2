terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0"
    }
  }

  # 使用本地状态（简化部署）
  # backend "gcs" {
  #   bucket = "rd-ap2-tf-state"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # 使用访问令牌进行认证（可选）
  access_token = var.google_access_token != "" ? var.google_access_token : null
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # 使用访问令牌进行认证（可选）
  access_token = var.google_access_token != "" ? var.google_access_token : null
}

# 启用必要的API
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudbuild.googleapis.com"
  ])

  service = each.key

  disable_dependent_services = true
  disable_on_destroy         = true
}

# 创建VPC网络
resource "google_compute_network" "agent_chat_network" {
  name                    = var.network_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

# 创建子网
resource "google_compute_subnetwork" "agent_chat_subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.agent_chat_network.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# 创建防火墙规则
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.agent_chat_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.subnet_cidr]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.agent_chat_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# 创建NAT网关
resource "google_compute_router" "agent_chat_router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.agent_chat_network.id
}

resource "google_compute_router_nat" "agent_chat_nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.agent_chat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# 创建服务账户
resource "google_service_account" "agent_chat_sa" {
  account_id   = var.service_account_name
  display_name = "Agent Chat Application Service Account"
}

# 授予服务账户权限
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/compute.admin",
    "roles/storage.admin",
    "roles/artifactregistry.admin",
    "roles/secretmanager.admin",
    "roles/cloudkms.admin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent_chat_sa.email}"
}

# 创建GKE集群
resource "google_container_cluster" "agent_chat_cluster" {
  name     = var.cluster_name
  location = var.region

  # 删除默认节点池
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.agent_chat_network.name
  subnetwork = google_compute_subnetwork.agent_chat_subnet.name

  # 启用Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # 启用Shielded Nodes增强安全性
  enable_shielded_nodes = true

  # 禁用删除保护以便可以销毁集群
  deletion_protection = false

  # 配置私有集群
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # IP分配策略
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  depends_on = [
    google_project_service.apis,
    google_compute_subnetwork.agent_chat_subnet
  ]
}

# 创建节点池（使用抢占式实例降低成本）
resource "google_container_node_pool" "agent_chat_nodes" {
  name       = var.node_pool_name
  location   = var.region
  cluster    = google_container_cluster.agent_chat_cluster.name
  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    preemptible     = true  # 使用抢占式实例降低成本
    machine_type    = var.machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.agent_chat_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity配置
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# 创建Firestore数据库
resource "google_firestore_database" "agent_chat_db" {
  name        = var.firestore_database_name
  location_id = var.firestore_location_id
  type        = var.firestore_type
  concurrency_mode = "OPTIMISTIC"

  depends_on = [google_project_service.apis]
}

# 创建Artifact Registry用于存储容器镜像
resource "google_artifact_registry_repository" "agent_repo" {
  provider = google-beta

  location      = var.region
  repository_id = "agent-chat-app"
  format        = "DOCKER"
  description   = "Repository for Agent Chat Application container images"

  depends_on = [google_project_service.apis]
}

# 创建Secret Manager用于存储敏感信息
resource "google_secret_manager_secret" "agent_secrets" {
  secret_id = "agent-chat-secrets"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# 创建KMS密钥环和密钥
resource "google_kms_key_ring" "agent_keyring" {
  name     = "agent-chat-keyring"
  location = var.region

  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "agent_key" {
  name            = "agent-chat-key"
  key_ring        = google_kms_key_ring.agent_keyring.id
  rotation_period = "7776000s"  # 90天

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

# 输出重要信息
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.agent_chat_cluster.name
}

output "gke_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.agent_chat_cluster.endpoint
  sensitive   = true
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.agent_chat_network.name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.agent_chat_subnet.name
}

output "firestore_database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.agent_chat_db.name
}

output "service_account_email" {
  description = "The email of the service account"
  value       = google_service_account.agent_chat_sa.email
}

output "artifact_registry_repository" {
  description = "The name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.agent_repo.name
}

output "secret_manager_secret" {
  description = "The name of the Secret Manager secret"
  value       = google_secret_manager_secret.agent_secrets.name
}

output "kms_keyring" {
  description = "The name of the KMS keyring"
  value       = google_kms_key_ring.agent_keyring.name
}

output "kms_key" {
  description = "The name of the KMS key"
  value       = google_kms_crypto_key.agent_key.name
}

output "cluster_connection_command" {
  description = "Command to configure kubectl for the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.agent_chat_cluster.name} --region ${var.region} --project ${var.project_id}"
}

output "artifact_registry_url" {
  description = "URL for the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.agent_repo.repository_id}"
}