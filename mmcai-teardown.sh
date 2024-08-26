#!/bin/bash

source logging.sh

remove_mmcai_manager=false
remove_mmcai_cluster=false
remove_cluster_resources=false
remove_billing_database=false
remove_memverge_secrets=false
remove_namespaces=false
remove_prometheus_crds_namespace=false
remove_nvidia_gpu_operator=false
remove_kubeflow=false

confirm_selection=false

RELEASE_NAMESPACE=mmcai-system

read -p "Remove MMC.AI Manager [y/N]:" remove_mmcai_manager
case $remove_mmcai_manager in
    [Yy]* ) remove_mmcai_manager=true;;
    * ) remove_mmcai_manager=false;;
esac

read -p "Remove MMC.AI Cluster [y/N]:" remove_mmcai_cluster
case $remove_mmcai_cluster in
    [Yy]* ) remove_mmcai_cluster=true;;
    * ) remove_mmcai_cluster=false;;
esac

if $remove_mmcai_cluster; then
    read -p "Remove all cluster resources (e.g. node groups, departments, projects, workloads) [y/N]:" remove_cluster_resources
    case $remove_cluster_resources in
        [Yy]* ) remove_cluster_resources=true;;
        * ) remove_cluster_resources=false;;
    esac

    read -p "Remove billing database [y/N]:" remove_billing_database
    case $remove_billing_database in
        [Yy]* ) remove_billing_database=true;;
        * ) remove_billing_database=false;;
    esac
fi

if $remove_mmcai_manager \
&& $remove_mmcai_cluster; \
then
    read -p "Remove MemVerge image pull secrets [y/N]:" remove_memverge_secrets
    case $remove_memverge_secrets in
        [Yy]* ) remove_memverge_secrets=true;;
        * ) remove_memverge_secrets=false;;
    esac
fi

if $remove_mmcai_manager \
&& $remove_mmcai_cluster \
&& $remove_cluster_resources \
&& $remove_billing_database \
&& $remove_memverge_secrets; \
then
    read -p "Remove namespaces [y/N]:" remove_namespaces
    case $remove_namespaces in
        [Yy]* ) remove_namespaces=true;;
        * ) remove_namespaces=false;;
    esac
fi

if $remove_mmcai_manager \
&& $remove_mmcai_cluster; \
then
    read -p "Remove Prometheus CRDs and namespace [y/N]:" remove_prometheus_crds_namespace
    case $remove_prometheus_crds_namespace in
        [Yy]* ) remove_prometheus_crds_namespace=true;;
        * ) remove_prometheus_crds_namespace=false;;
    esac

    read -p "Remove NVIDIA GPU Operator [y/N]:" remove_nvidia_gpu_operator
    case $remove_nvidia_gpu_operator in
        [Yy]* ) remove_nvidia_gpu_operator=true;;
        * ) remove_nvidia_gpu_operator=false;;
    esac

    read -p "Remove Kubeflow [y/N]:" remove_kubeflow
    case $remove_kubeflow in
        [Yy]* ) remove_kubeflow=true;;
        * ) remove_kubeflow=false;;
    esac
fi

div

echo "COMPONENT: REMOVE"
echo "MMC.AI Manager:" $remove_mmcai_manager
echo "MMC.AI Cluster:" $remove_mmcai_cluster
echo "All cluster resources:" $remove_cluster_resources
echo "Billing database:" $remove_billing_database
echo "MemVerge image pull secrets:" $remove_memverge_secrets
echo "Namespaces:" $remove_namespaces
echo "Prometheus CRDs and namespace:" $remove_prometheus_crds_namespace
echo "NVIDIA GPU Operator:" $remove_nvidia_gpu_operator
echo "Kubeflow:" $remove_kubeflow

div

read -p "Confirm selection [y/N]:" confirm_selection
case $confirm_selection in
    [Yy]* ) confirm_selection=true;;
    * ) confirm_selection=false;;
esac

if ! $confirm_selection; then
    div
    log_good "Aborting..."
    exit 0
fi

div
log_good "Beginning teardown..."

if $remove_mmcai_manager; then
    div
    log_good "Removing MMC.AI Manager..."
    helm uninstall -n $RELEASE_NAMESPACE mmcai-manager
fi

if $remove_cluster_resources; then
    div
    log_good "Removing cluster resources..."
    kubectl delete crd departments.mmc.ai

    kubectl delete crd admissionchecks.kueue.x-k8s.io
    kubectl delete crd clusterqueues.kueue.x-k8s.io
    kubectl delete crd localqueues.kueue.x-k8s.io
    kubectl delete crd multikueueclusters.kueue.x-k8s.io
    kubectl delete crd multikueueconfigs.kueue.x-k8s.io
    kubectl delete crd provisioningrequestconfigs.kueue.x-k8s.io
    kubectl delete crd resourceflavors.kueue.x-k8s.io
    kubectl delete crd workloadpriorityclasses.kueue.x-k8s.io
    kubectl delete crd workloads.kueue.x-k8s.io
fi

if $remove_mmcai_cluster; then
    div
    log_good "Removing MMC.AI Cluster..."
    helm uninstall -n $RELEASE_NAMESPACE mmcai-cluster
fi

if $remove_billing_database; then
    div
    log_good "Removing billing database..."
    wget -O mysql-teardown.sh https://raw.githubusercontent.com/MemVerge/mmc.ai-setup/main/mysql-teardown.sh
    chmod +x mysql-teardown.sh
    ./mysql-teardown.sh
    rm mysql-teardown.sh
    kubectl delete secret -n $RELEASE_NAMESPACE mysql-secret
fi

if $remove_memverge_secrets; then
    div
    log_good "Removing MemVerge image pull secrets..."
    kubectl delete secret -n $RELEASE_NAMESPACE memverge-dockerconfig
    kubectl delete secret -n mmcloud-operator-system memverge-dockerconfig
fi

if $remove_namespaces; then
    div
    log_good "Removing namespaces..."
    kubectl delete namespace $RELEASE_NAMESPACE
    kubectl delete namespace mmcloud-operator-system
fi

if $remove_nvidia_gpu_operator; then
    div
    log_good "Removing NVIDIA GPU Operator..."
    kubectl delete crd nvidiadrivers.nvidia.com
    helm uninstall -n gpu-operator nvidia-gpu-operator
    kubectl delete crd clusterpolicies.nvidia.com
    kubectl delete namespace gpu-operator

    # NFD
    kubectl delete crd nodefeatures.nfd.k8s-sigs.io
    kubectl delete crd nodefeaturerules.nfd.k8s-sigs.io
fi

if $remove_prometheus_crds_namespace; then
    div
    log_good "Removing Prometheus CRDs and namespace..."
    kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
    kubectl delete crd alertmanagers.monitoring.coreos.com
    kubectl delete crd podmonitors.monitoring.coreos.com
    kubectl delete crd probes.monitoring.coreos.com
    kubectl delete crd prometheusagents.monitoring.coreos.com
    kubectl delete crd prometheuses.monitoring.coreos.com
    kubectl delete crd prometheusrules.monitoring.coreos.com
    kubectl delete crd scrapeconfigs.monitoring.coreos.com
    kubectl delete crd servicemonitors.monitoring.coreos.com
    kubectl delete crd thanosrulers.monitoring.coreos.com
    kubectl delete namespace monitoring
fi

if $remove_kubeflow; then
    div
    log_good "Removing Kubeflow..."
    wget -O kubeflow-teardown.sh https://raw.githubusercontent.com/MemVerge/mmc.ai-setup/main/kubeflow-teardown.sh
    chmod +x kubeflow-teardown.sh
    ./kubeflow-teardown.sh
    rm kubeflow-teardown.sh
fi

div
log_good "Done!"
