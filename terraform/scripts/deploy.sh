#!/bin/bash

# Agent Chat Application - 一键部署脚本
# 使用方法：./deploy.sh [project_id]

set -e  # 遇到错误立即退出

echo "🚀 Agent Chat Application 部署脚本"
echo "======================================"

# 检查参数
if [ $# -eq 0 ]; then
    echo "❌ 错误：请提供GCP项目ID"
    echo "使用方法: ./deploy.sh <project_id>"
    echo "示例: ./deploy.sh agent-chat-test-123456"
    exit 1
fi

PROJECT_ID=$1
echo "📋 项目ID: $PROJECT_ID"

# 检查必要工具
echo "🔧 检查必要工具..."
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform未安装"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud未安装"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl未安装"; exit 1; }
echo "✅ 所有必要工具已安装"

# 检查gcloud认证
echo "🔐 检查gcloud认证..."
gcloud auth list --format="value(account)" | grep -q "@" || {
    echo "❌ gcloud未认证，请运行: gcloud auth login"
    exit 1
}
echo "✅ gcloud已认证"

# 设置项目
echo "⚙️ 设置GCP项目..."
gcloud config set project $PROJECT_ID

# 准备Terraform配置
echo "📁 准备Terraform配置..."
if [ ! -f "terraform.tfvars" ]; then
    if [ -f "configs/terraform.tfvars.example" ]; then
        cp configs/terraform.tfvars.example terraform.tfvars
        # 替换项目ID
        sed -i '' "s/your-gcp-project-id/$PROJECT_ID/g" terraform.tfvars
        echo "✅ 创建terraform.tfvars文件"
    else
        echo "❌ 找不到configs/terraform.tfvars.example"
        exit 1
    fi
else
    echo "⚠️  terraform.tfvars已存在，跳过创建"
fi

# 初始化Terraform
echo "📦 初始化Terraform..."
terraform init

# 显示部署计划
echo "📋 显示部署计划..."
terraform plan

# 确认部署
read -p "❓ 确认部署吗？(yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ 用户取消部署"
    exit 0
fi

# 开始部署
echo "🚀 开始部署基础设施..."
start_time=$(date +%s)
terraform apply -auto-approve
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "✅ 基础设施部署完成！耗时: ${duration}秒"

# 获取输出信息
echo "📊 部署输出信息:"
terraform output

# 配置kubectl
echo "🔗 配置kubectl访问..."
CLUSTER_NAME=$(terraform output -raw gke_cluster_name 2>/dev/null || echo "agent-chat-cluster")
REGION=$(terraform output -raw region 2>/dev/null || echo "asia-east1")

gcloud container clusters get-credentials $CLUSTER_NAME \
  --region $REGION \
  --project $PROJECT_ID

# 验证集群
echo "🔍 验证集群状态..."
kubectl get nodes
kubectl cluster-info

# 创建测试命名空间
echo "🧪 创建测试环境..."
kubectl create namespace agent-test --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "🎉 部署完成！"
echo ""
echo "下一步操作："
echo "1. 查看集群: kubectl get all -n agent-test"
echo "2. 查看成本估算: 查看 COST_ESTIMATION.md"
echo "3. 测试后清理: ./cleanup.sh $PROJECT_ID"
echo ""
echo "⚠️  重要提醒："
echo "   - 这是真实GCP环境，会产生费用"
echo "   - 建议设置预算告警"
echo "   - 测试后及时运行清理脚本"
echo ""
echo "🕐 部署开始时间: $(date -r $start_time)"
echo "🕐 部署结束时间: $(date)"