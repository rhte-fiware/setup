#!/bin/sh

set -e

# Check if the user is logged in 
if ! oc whoami &> /dev/null; then
    echo -e "Check. You are not logged out. Please log in and run the script again."
    exit 1
else
    echo -e "Check. You are correctly logged in. Continue..."
fi

##
# 0) MONITORING SET UP
## 

if ! oc get cm cluster-monitoring-config -n openshift-monitoring &> /dev/null; then
    echo -e "Check. Cluster monitoring is missing, creating the monitoring stack..."
    oc apply -f openshift-step0-monitoring/prometheus-user-workload-monitoring.yaml
else
    echo -e "Check. Cluster monitoring is ready, do nothing."
fi


##
# 1) CREATE THE PROJECTS
## 

echo -e "\n1) CREATE THE PROJECTS"

oc apply -f openshift-step1

##
# 2) INSTALL THE OPERATORS
## 

echo -e "\n2) INSTALL THE OPERATORS"

oc apply -f openshift-step2

echo -e "\n2.1) Run checks:"


echo -n "Waiting for pods GitOps operator ready..."
while [[ $(oc get pods -l control-plane=controller-manager -n openshift-operators -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

echo -n "Waiting for pods ElasticSearch operator ready..."
while [[ $(oc get pods -l name=elasticsearch-operator -n openshift-operators-redhat -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

echo -n "Waiting for pods OCP Logging operator ready..."
while [[ $(oc get pods -l name=cluster-logging-operator -n openshift-logging -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

echo -e "\n2.2) Enable Cluster Logging web console plugin"
oc patch consoles.operator.openshift.io cluster --patch '{ "spec": { "plugins": ["logging-view-plugin"] }  }' --type=merge

##
# 3) DEPLOY COMPONENTS
## 

echo -e "\n3) DEPLOY COMPONENTS"

oc apply -f openshift-step3


##
# 4) PROVIDE PERMISSIONS TO ARGOCD SA
## 

echo -e "\n4) PROVIDE PERMISSIONS TO ARGOCD SERVCIE ACCOUNT"

oc adm policy add-role-to-user cluster-admin system:serviceaccount:openshift-gitops:argocd-argocd-server -n "rhte-demo"
oc adm policy add-role-to-user cluster-admin system:serviceaccount:openshift-gitops:argocd-argocd-application-controller -n "rhte-demo"

##
# 5) PRINT HOW TO DEPLOY MARINERA
## 

echo -e "\n5) NEXT STEPS"
echo -e ""

echo -e "Execute the following commands to install Marinera:"


echo -e "\tgit clone git@github.com:rhte-fiware/marinera.git"
echo -e "\tcd marinera/fiware-platform"
echo -e "\tgit checkout rhte-demo"
echo -e "\thelm template . | oc -n openshift-gitops apply -f -"
