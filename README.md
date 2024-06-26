# How to install  Watsonx.ai on Openshift


This guide provides comprehensive instructions for a quick proof-of-concept (PoC) installation of Watsonx.ai on OpenShift. Watsonx.ai can be installed on top of OpenShift, whether on a public cloud or on-premises.

## Introduction

Watsonx.ai is IBM's advanced AI and machine learning platform designed to deliver powerful analytics and insights. Installing Watsonx.ai on OpenShift allows you to leverage OpenShift's robust orchestration capabilities while harnessing the power of Watsonx.ai for data science and AI workloads. This tutorial will guide you through the steps to get Watsonx.ai up and running on your OpenShift cluster.

## Prerequisites

Before starting the installation, ensure you have the following:

- A running OpenShift Container Platform (OCP) cluster.
- Administrative access to the OpenShift cluster.
- A workstation with Podman or Docker Desktop installed.
- An IBM Cloud account to obtain the entitlement key.

## Installation Steps

### Step 1: Setting Up the OpenShift Cluster

1. **Have a running OCP cluster**:
   - Ensure you have an OpenShift cluster running with sufficient resources. For example, a cluster with 6 worker nodes (m6i.2xlarge) on AWS, where 3 nodes are allocated for OpenShift Data Foundation (ODF).

2. **Install OpenShift Data Foundation (ODF)**:
   - Use the Operator Hub on the OpenShift web interface to install ODF.

### Step 2: Installing Node Feature Discovery and NVIDIA GPU Operator

3. **Install Node Feature Discovery (NFD)**:
   - From the Operator Hub on the OpenShift web interface, install the NFD operator and create an instance of NFD.
   - Refer to the [NVIDIA documentation](https://docs.nvidia.com/datacenter/cloud-native/openshift/23.9.1/install-nfd.html) for detailed instructions.

4. **Install NVIDIA GPU Operator**:
   - From the Operator Hub on the OpenShift web interface, install the NVIDIA GPU Operator and create an instance of Cluster Policy.
   - Refer to the [NVIDIA documentation](https://docs.nvidia.com/datacenter/cloud-native/openshift/23.9.1/install-gpu-ocp.html) for detailed instructions.

### Step 3: Preparing Your Workstation

5. **Install Cloud Pak for Data CLI**:
   - Install the Cloud Pak for Data command-line interface (cpd-cli) on your workstation.
   - Refer to the [IBM documentation](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=workstation-installing-cloud-pak-data-cli) for detailed instructions.

### Step 4: Configuring the Environment

6. **Create an Environment Variable File**:
   - Create a file for environment variables and source it.
   - Follow the instructions provided [here](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=information-setting-up-installation-environment-variables).
   - A sample environment variables file ([cpd_vars.sh](cpd_vars.sh)) is available for reference.

### Step 5: Logging in to OpenShift Cluster

7. **Login to the OCP Cluster using cpd-cli**:
   ```sh
   cpd-cli manage login-to-ocp --username=${OCP_USERNAME} --password=${OCP_PASSWORD} --server=${OCP_URL}
   ```

### Step 6: Obtaining IBM Entitlement Key

8. **Get IBM Entitlement Key**:
   - Log in to [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary) to obtain your entitlement key.
   - Update the global pull secret:
     ```sh
     cpd-cli manage add-icr-cred-to-global-pull-secret \
       --entitled_registry_key=${IBM_ENTITLEMENT_KEY}
     ```

### Step 7: Setting Up OpenShift Namespaces

9. **Create Namespaces in OpenShift**:
   - Create two namespaces: `cpd-operators` and `cp4d`.
   ```sh
   oc create namespace cpd-operators
   oc create namespace cp4d
   ```

10. **Authorize Project Permissions**:
    - Ensure the operator project can watch the Cloud Pak for Data project.
    ```sh
    cpd-cli manage authorize-instance-topology \
      --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
      --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
    ```

### Step 8: Installing IBM Cloud Pak Foundational Services

11. **Install Foundational Services**:
    ```sh
    cpd-cli manage apply-cluster-components \
      --release=${VERSION} \
      --license_acceptance=true \
      --cert_manager_ns=${PROJECT_CERT_MANAGER} \
      --licensing_ns=${PROJECT_LICENSE_SERVICE}
    ```

12. **Set Up Instance Topology**:
    ```sh
    cpd-cli manage setup-instance-topology \
      --release=${VERSION} \
      --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
      --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
      --license_acceptance=true \
      --block_storage_class=${STG_CLASS_BLOCK}
    ```

### Step 9: Installing IBM Cloud Pak for Data

13. **Review the License for CP4D**:
    ```sh
    cpd-cli manage get-license \
      --release=4.8.1 \
      --license-type=SE
    ```

14. **Install Cloud Pak for Data Platform Operator**:
    ```sh
    cpd-cli manage apply-olm \
      --release=${VERSION} \
      --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
      --components=cpd_platform
    ```

15. **Install the Operands**:
    ```sh
    cpd-cli manage apply-cr \
      --release=${VERSION} \
      --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
      --components=cpd_platform \
      --block_storage_class=${STG_CLASS_BLOCK} \
      --file_storage_class=${STG_CLASS_FILE} \
      --license_acceptance=true
    ```

### Step 10: Accessing Cloud Pak for Data

16. **Get Cloud Pak for Data Web Interface URL and Credentials**:
    ```sh
    cpd-cli manage get-cpd-instance-details \
      --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
      --get_admin_initial_credentials=true
    ```

### Step 11: Installing Watsonx.ai Service

17. **Create OLM Objects for Watsonx.ai**:
    ```sh
    cpd-cli manage apply-olm \
      --release=${VERSION} \
      --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
      --components=watsonx_ai
    ```

18. **Create Custom Resource for Watsonx.ai**:
    ```sh
    cpd-cli manage apply-cr \
      --components=watsonx_ai \
      --release=${VERSION} \
      --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
      --block_storage_class=${STG_CLASS_BLOCK} \
      --file_storage_class=${STG_CLASS_FILE} \
      --license_acceptance=true
    ```

19. **Monitor the Installation**:
    - Monitor the `cpd_instance_ns` namespace for any errors.
    ```sh
    cpd-cli manage get-cr-status --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
    ```

### Step 12: Adding Foundation Models

20. **Add Extra OpenShift Worker Node**:
    - If you want to install models like meta-llama-llama-2-13b-chat, add an extra OpenShift worker node (e.g., g5.8xlarge type on AWS).
    - Refer to the [resource requirements](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=setup-adding-foundation-models).

21. **Patch Watsonx.ai to Add Foundation Models**:
    ```sh
    oc patch watsonxaiifm watsonxaiifm-cr \
      --namespace=${PROJECT_CPD_INST_OPERANDS} \
      --type=merge \
      --patch='{"spec":{"install_model_list": ["meta-llama-llama-2-70b-chat","ibm-granite-13b-chat-v2"]}}'
    ```

## Conclusion

By following these steps, you will have a functional Watsonx.ai environment running on OpenShift. This setup allows you to leverage the robust capabilities of both OpenShift and Watsonx.ai to run complex AI and data science workloads efficiently. If you encounter any issues, refer to the respective IBM and NVIDIA documentation links provided throughout this guide for additional support.
