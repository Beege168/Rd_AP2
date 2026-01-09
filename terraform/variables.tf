variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "google_access_token" {
  description = "Google Cloud access token for authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "asia-east1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "asia-east1-a"
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "agent-chat-network"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "agent-chat-subnet"
}

variable "subnet_cidr" {
  description = "The CIDR range for the subnet"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "The CIDR range for pods"
  type        = string
  default     = "10.20.0.0/14"
}

variable "services_cidr" {
  description = "The CIDR range for services"
  type        = string
  default     = "10.24.0.0/20"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "agent-chat-cluster"
}

variable "node_pool_name" {
  description = "The name of the node pool"
  type        = string
  default     = "agent-chat-pool"
}

variable "machine_type" {
  description = "The machine type for nodes"
  type        = string
  default     = "e2-small" # 最小实例类型，成本最低
}

variable "node_count" {
  description = "The initial number of nodes"
  type        = number
  default     = 1 # 最小节点数，demo环境足够
}

variable "min_node_count" {
  description = "The minimum number of nodes"
  type        = number
  default     = 1 # 保持最小以控制成本
}

variable "max_node_count" {
  description = "The maximum number of nodes"
  type        = number
  default     = 2 # 限制最大节点数，防止意外扩展
}


variable "service_account_name" {
  description = "The name of the service account"
  type        = string
  default     = "agent-chat-sa"
}

variable "firestore_database_name" {
  description = "The name of the Firestore database"
  type        = string
  default     = "(default)"
}

variable "firestore_location_id" {
  description = "The location ID for Firestore"
  type        = string
  default     = "asia-east1"
}

variable "firestore_type" {
  description = "The type of Firestore database"
  type        = string
  default     = "FIRESTORE_NATIVE"
}

