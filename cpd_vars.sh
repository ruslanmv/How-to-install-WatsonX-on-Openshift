#!/usr/bin/env bash
#===============================================================================
# Cloud Pak for Data — Installation Variables
# CP4D 5.0.2 · cpd-cli 14.0.2 · OpenShift 4.12+
#
# Usage:
#   chmod 700 cpd_vars.sh
#   source cpd_vars.sh
#
# ⚠️  Never commit this file to version control — it contains secrets.
#===============================================================================


# ------------------------------------------------------------------------------
# Client workstation (optional overrides)
# ------------------------------------------------------------------------------
# Uncomment to override the default cpd-cli workspace directory.
# export CPD_CLI_MANAGE_WORKSPACE=~/cpd-workspace

# Uncomment to pass extra arguments to the OLM utils container at launch.
# export OLM_UTILS_LAUNCH_ARGS=


# ------------------------------------------------------------------------------
# Cluster
# ------------------------------------------------------------------------------
# API endpoint of your OpenShift cluster (include port 6443).
export OCP_URL=https://api.your-cluster.example.com:6443

# Cluster type: self-managed | ROSA | ROKS | ARO
export OPENSHIFT_TYPE=self-managed

# CPU architecture: amd64 | ppc64le | s390x
export IMAGE_ARCH=amd64

# Authentication — use either username/password OR token (not both).
export OCP_USERNAME=kubeadmin
export OCP_PASSWORD=your-password-here
# export OCP_TOKEN=                   # Uncomment and use instead of password if preferred

# Convenience login shortcuts used by cpd-cli manage commands.
export SERVER_ARGUMENTS="--server=${OCP_URL}"
export LOGIN_ARGUMENTS="--username=${OCP_USERNAME} --password=${OCP_PASSWORD}"
# export LOGIN_ARGUMENTS="--token=${OCP_TOKEN}"    # Token-based alternative

export CPDM_OC_LOGIN="cpd-cli manage login-to-ocp ${SERVER_ARGUMENTS} ${LOGIN_ARGUMENTS}"
export OC_LOGIN="oc login ${OCP_URL} ${LOGIN_ARGUMENTS}"


# ------------------------------------------------------------------------------
# Projects / Namespaces
# ------------------------------------------------------------------------------
# Foundational services — do not change these names unless IBM guidance says so.
export PROJECT_CERT_MANAGER=ibm-cert-manager
export PROJECT_LICENSE_SERVICE=ibm-licensing

# ✅ CORRECTED: IBM naming convention for CP4D 5.x is ibm-cpd-scheduler
#    (not cpd-scheduler — updated to match IBM's published 5.0.2 examples)
export PROJECT_SCHEDULING_SERVICE=ibm-cpd-scheduler

# Operator and operand namespaces for your CP4D instance.
export PROJECT_CPD_INST_OPERATORS=cpd-operators
export PROJECT_CPD_INST_OPERANDS=cpd-instance


# ------------------------------------------------------------------------------
# Storage classes
# ------------------------------------------------------------------------------
# Set these to match your cluster's actual storage class names.
# Run `oc get storageclass` to list what is available on your cluster.
# The examples below are common names — yours may differ by platform and
# deployment mode. Always verify before running any install commands.

# ── ODF / OpenShift Data Foundation (on-prem or ROKS) — common example ──────
export STG_CLASS_BLOCK=ocs-storagecluster-ceph-rbd
export STG_CLASS_FILE=ocs-storagecluster-cephfs

# ── AWS ROSA with EFS — common example ──────────────────────────────────────
# export STG_CLASS_BLOCK=gp3-csi
# export STG_CLASS_FILE=efs-nfs-client

# ── IBM Cloud ROKS — common example ─────────────────────────────────────────
# export STG_CLASS_BLOCK=ibmc-block-gold
# export STG_CLASS_FILE=ibmc-file-gold-gid

# ── Azure ARO — common example ───────────────────────────────────────────────
# export STG_CLASS_BLOCK=managed-premium
# export STG_CLASS_FILE=azurefile-csi


# ------------------------------------------------------------------------------
# IBM Entitled Registry
# ------------------------------------------------------------------------------
# Obtain your key from: https://myibm.ibm.com/products-services/containerlibrary
# ⚠️  Keep this value secret — treat it like a password.
export IBM_ENTITLEMENT_KEY=your-entitlement-key-here


# ------------------------------------------------------------------------------
# Private container registry (air-gapped / mirrored installs only)
# ------------------------------------------------------------------------------
# For standard connected installations, leave this section commented out.
#
# ⚠️  IMPORTANT: Uncommenting these five variables alone is NOT sufficient for
#    a mirrored deployment. Air-gapped installs require a full image-mirroring
#    workflow (cpd-cli manage mirror-images + catalog mirroring) in addition to
#    these credentials. Refer to IBM's mirrored installation documentation:
#    https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=installing-mirroring-images
#
# export PRIVATE_REGISTRY_LOCATION=registry.example.com:5000
# export PRIVATE_REGISTRY_PUSH_USER=push-user
# export PRIVATE_REGISTRY_PUSH_PASSWORD=push-password
# export PRIVATE_REGISTRY_PULL_USER=pull-user
# export PRIVATE_REGISTRY_PULL_PASSWORD=pull-password


# ------------------------------------------------------------------------------
# Cloud Pak for Data version
# ------------------------------------------------------------------------------
# CP4D 5.0.2 uses cpd-cli 14.0.2 — always align the binary version to match.
export VERSION=5.0.2


# ------------------------------------------------------------------------------
# Components
# ------------------------------------------------------------------------------
# Specify the components to install as a comma-separated list.
# Choose ONE of the profiles below and uncomment it.
#
# Component reference:
#   ibm-cert-manager   — Certificate Manager (always required)
#   ibm-licensing      — License Service (always required)
#   scheduler          — Scheduling Service (always required in CP4D 5.x)
#   cpfs               — Cloud Pak Foundational Services (always required)
#   cpd_platform       — CP4D control plane / web UI (always required)
#   ws                 — Watson Studio
#   wml                — Watson Machine Learning
#   watsonx_ai         — watsonx.ai (commonly installed alongside ws and wml;
#                        foundation models require GPU capacity)
#   rstudio            — R Studio extension (enabled via Watson Studio UI, not CLI)
#   db2oltp            — Db2 OLTP
#   dv                 — Data Virtualization
#   analyticsengine    — Analytics Engine powered by Apache Spark

# ── Profile 1: Platform only (foundation, no services) ───────────────────────
# export COMPONENTS=ibm-cert-manager,ibm-licensing,scheduler,cpfs,cpd_platform

# ── Profile 2: Watson Studio only — recommended for academic labs / free trial
# Minimum viable setup; enables Jupyter, AutoAI, Data Refinery, and R Studio UI
export COMPONENTS=ibm-cert-manager,ibm-licensing,scheduler,cpfs,cpd_platform,ws

# ── Profile 3: Watson Studio + Machine Learning ───────────────────────────────
# Adds model training and deployment; no LLMs / foundation models
# export COMPONENTS=ibm-cert-manager,ibm-licensing,scheduler,cpfs,cpd_platform,ws,wml

# ── Profile 4: Full watsonx.ai — requires GPU worker nodes ───────────────────
# export COMPONENTS=ibm-cert-manager,ibm-licensing,scheduler,cpfs,cpd_platform,ws,wml,watsonx_ai

# To skip specific components during a partial upgrade or re-run:
# export COMPONENTS_TO_SKIP=<component-ID-1>,<component-ID-2>


# ------------------------------------------------------------------------------
# Validation — print a summary on source
# ------------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CP4D Environment Variables Loaded"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cluster         : ${OCP_URL}"
echo "  OCP type        : ${OPENSHIFT_TYPE} (${IMAGE_ARCH})"
echo "  CP4D version    : ${VERSION}"
echo "  Scheduler NS    : ${PROJECT_SCHEDULING_SERVICE}"
echo "  Operators NS    : ${PROJECT_CPD_INST_OPERATORS}"
echo "  Operands NS     : ${PROJECT_CPD_INST_OPERANDS}"
echo "  Block storage   : ${STG_CLASS_BLOCK}"
echo "  File storage    : ${STG_CLASS_FILE}"
echo "  Components      : ${COMPONENTS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Warn if placeholder values are still set
if [[ "${OCP_PASSWORD}" == "your-password-here" || \
      "${IBM_ENTITLEMENT_KEY}" == "your-entitlement-key-here" ]]; then
  echo ""
  echo "  ⚠️  WARNING: Placeholder values detected."
  echo "     Update OCP_PASSWORD and IBM_ENTITLEMENT_KEY before running cpd-cli."
  echo ""
fi
