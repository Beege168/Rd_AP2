#!/bin/bash

# 立即清理 agent-chat- 资源脚本
# 使用方法：./cleanup_now.sh

set -e

echo "🧹 立即清理 agent-chat- 资源"
echo "================================"

PROJECT_ID="rd-ap2"
echo "项目: $PROJECT_ID"

# 0. 先删除GKE集群（最重要，也最耗时）
echo "0. 删除GKE集群..."
echo "   ⚠️ 这可能需要几分钟时间..."
gcloud container clusters delete agent-chat-cluster \
  --region=asia-east1 \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  GKE集群已删除或不存在"

# 等待GKE集群删除完成
echo "   ⏳ 等待GKE集群删除完成..."
sleep 30

# 1. 删除KMS密钥
echo "1. 删除KMS密钥..."
gcloud kms keys delete agent-chat-key \
  --keyring=agent-chat-keyring \
  --location=asia-east1 \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  KMS密钥已删除或不存在"

# 2. 删除KMS密钥环
echo "2. 删除KMS密钥环..."
gcloud kms keyrings delete agent-chat-keyring \
  --location=asia-east1 \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  KMS密钥环已删除或不存在"

# 3. 删除Artifact Registry
echo "3. 删除Artifact Registry..."
gcloud artifacts repositories delete agent-chat-app \
  --location=asia-east1 \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  Artifact Registry已删除或不存在"

# 4. 删除Secret Manager
echo "4. 删除Secret Manager..."
gcloud secrets delete agent-chat-secrets \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  Secret Manager已删除或不存在"

# 5. 删除Firestore数据库
echo "5. 删除Firestore数据库..."
echo "   ⚠️ Firestore删除需要确认..."
gcloud firestore databases delete \
  --database="(default)" \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  Firestore数据库已删除或不存在"

# 6. 删除子网
echo "6. 删除子网..."
gcloud compute networks subnets delete agent-chat-subnet \
  --region=asia-east1 \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  子网已删除或不存在"

# 7. 删除防火墙规则
echo "7. 删除防火墙规则..."
gcloud compute firewall-rules delete agent-chat-network-allow-internal \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  防火墙规则1已删除或不存在"

gcloud compute firewall-rules delete agent-chat-network-allow-ssh \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  防火墙规则2已删除或不存在"

# 8. 删除路由器（如果存在）
echo "8. 删除路由器..."
gcloud compute routers delete agent-chat-network-router \
  --region=asia-east1 \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  路由器已删除或不存在"

# 9. 删除VPC网络
echo "9. 删除VPC网络..."
gcloud compute networks delete agent-chat-network \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  VPC网络已删除或不存在"

# 10. 删除服务账户
echo "10. 删除服务账户..."
gcloud iam service-accounts delete agent-chat-sa@rd-ap2.iam.gserviceaccount.com \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  服务账户已删除或不存在"

echo ""
echo "✅ 清理完成！"
echo ""
echo "建议在GCP控制台确认："
echo "1. GKE集群: https://console.cloud.google.com/kubernetes/clusters"
echo "2. VPC网络: https://console.cloud.google.com/networking/networks"
echo "3. Artifact Registry: https://console.cloud.google.com/artifacts"
echo "4. Firestore: https://console.cloud.google.com/firestore"
echo "5. KMS: https://console.cloud.google.com/security/kms"