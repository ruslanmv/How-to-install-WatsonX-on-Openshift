# How to install Watsonx.ai on Openshift


Since 2025, IBM has significantly restricted or phased out new watsonx.ai Lite instance
creation in many regions. If you are in a university lab or academic program and suddenly
found yourself unable to create a new instance, you are not alone — and there is a solid
alternative. You can deploy watsonx.ai yourself on top of Red Hat OpenShift, whether that
is a cloud cluster or something you are running on-premises. That is exactly what this
guide walks you through, from a clean cluster all the way to a working AI environment.

One important thing to know before you start: watsonx.ai is not free even when
self-hosted. It requires a valid IBM license and an active IBM Entitlement Key. If you
are doing this for academic purposes, check with your IBM contact or university program
coordinator to confirm you have the right entitlement in place before going any further.

Before we run anything, let me help you pick the right starting point. If you are working
with a 30-day OpenShift trial or a small PoC cluster, a full watsonx.ai deployment is
simply not going to fit — it needs at least six worker nodes and roughly 1 to 2 TB of
storage depending on which components and models you install. The smarter move in that
case is to start with Watson Studio only. You still get Jupyter notebooks, AutoAI, Data
Refinery and the model training framework, which is more than enough for coursework and
hands-on learning, and it runs comfortably on just three worker nodes with no GPU
required.

If you do have a larger cluster with GPU nodes available and want the full experience with
foundation models like Granite, we cover that path too — just keep reading
past the Watson Studio section. Keep in mind that available models depend on your
entitlement and the IBM catalog version active in your cluster at installation time.

You will also need outbound network access from your cluster to `icr.io` and IBM
endpoints to pull container images. If you are in an air-gapped or restricted network
environment, you will need to mirror the images first — that scenario is outside the
scope of this guide, but the IBM documentation covers it in detail.

---

## Step 0 — Log In as kubeadmin

Most installation steps in this guide require cluster-admin privileges. The easiest way
to get that during setup is to use the built-in `kubeadmin` account. Day-to-day CP4D
operations can and should use regular user accounts, but for the initial deployment you
want to be running as `kubeadmin`.

Start by confirming who you are currently logged in as:

```bash
oc whoami
```

If the output says `kube:admin` you are good to go. If it shows anything else, follow
the steps below to switch before going any further.

**How to log in as kubeadmin from the web console:**

1. Open your cluster's web console URL in a browser and log in as `kubeadmin`.
   On the 30-day trial you can find both the console URL and the kubeadmin password
   on your cluster's detail page at [console.redhat.com](https://console.redhat.com).

2. Once logged in, click **your username in the top-right corner** and select
   **Copy login command**.

3. A new page opens — click **Display Token**.

4. Copy the full command that looks like this:
   ```bash
   oc login --token=sha256~xxxxxxxxxxxxxxxx --server=https://api.your-cluster.com:6443
   ```

5. Paste it into your terminal and press Enter.

Verify it worked:

```bash
oc whoami
# Expected output: kube:admin
```

Once you see `kube:admin` you are ready to proceed. If you share this cluster with a
team during a lab, use this `kubeadmin` session only for installation and admin tasks —
day-to-day lab work should run under individual user accounts once permissions are set
up in Step 2.

---

## Step 1 — Check What You Will Need

Before running a single command, make sure you have these five things ready on your
workstation and your cluster. Think of this as your packing list before a trip —
everything goes much more smoothly when it is all prepared upfront.

**1. An OpenShift cluster running version 4.12 or later.**
You need `cluster-admin` access to it. If you are using the 30-day trial, make sure you
are using the full **OpenShift Cluster Trial** (not the Developer Sandbox — the sandbox
does not support the persistent storage that CP4D needs).

**2. Podman or Docker Desktop on your laptop or workstation.**
The `cpd-cli` tool uses a container internally to run certain management tasks, so one of
these needs to be installed and running before you begin.

**3. An IBM Entitlement Key.**
This is essentially a password that lets your cluster pull IBM software images from IBM's
private container registry. You can get yours from the
[IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary) — log
in with your IBM ID, go to *Container Software*, and copy the key. Keep it somewhere safe,
you will need it in a few steps.

**4. The cpd-cli binary.**
This is the command-line tool that drives the entire installation. Use version **14.x**
if you are installing CP4D 5.x (which this guide covers), or **13.x** for the older
CP4D 4.8.x. Download the right version from the
[cpd-cli GitHub releases page](https://github.com/IBM/cpd-cli/releases).

**5. The oc CLI.**
This is OpenShift's own command-line tool, similar to `kubectl` if you have used
Kubernetes before. It needs to be installed on your workstation and already pointed at
your cluster. If you can run `oc whoami` and get back a username, you are all set.

---

## Step 2 — Understand Your User Permissions

This is a short but important step, especially if you are new to OpenShift. Read it once
now and you will save yourself a lot of confusion later.

OpenShift uses a security system called **RBAC** — short for Role-Based Access Control.
The idea is simple: every user on the cluster only has access to the specific resources
they have been explicitly granted. Think of it like a hotel: your key card opens your
room and the gym, but not the kitchen or the control room. Same principle here.

What this means in practice is that some commands in this guide will work straight away
for your user account, while others will require a small permission setup first. For
example, `oc get storageclass` works for almost any user because storage classes are
cluster-wide and readable by default. But a command like
`oc get catsrc -n openshift-marketplace` targets a specific namespace, and if your
account has not been granted access to that namespace, OpenShift will block it.

**How to set up the right permissions now, before you need them.**

If you are the cluster administrator on your trial or lab environment, run this once
with your own username:

```bash
# Grants read-only access to the openshift-marketplace namespace
# Replace "yourusername" with your actual OpenShift login
oc adm policy add-role-to-user view yourusername -n openshift-marketplace
```

If you are a lab participant and someone else manages the cluster, ask your instructor
or cluster admin to run that command for each person doing the lab. It is a safe,
read-only grant — it lets users *see* what is in that namespace, but not change or
delete anything.

For a shared training environment where all participants need broader visibility, the
admin can instead grant a cluster-wide read role:

```bash
# Grants read-only visibility across the entire cluster
oc adm policy add-cluster-role-to-user cluster-reader yourusername
```

Use the first option (namespace-scoped) for most cases. The second is only needed if
participants need to inspect resources across many different namespaces during the lab.

**Quick check — confirm your access is working.**

```bash
# Check 1 — basic cluster access
oc get storageclass

# Check 2 — marketplace namespace access (requires the permission grant above)
oc get catsrc -n openshift-marketplace
```

If both return a table of results, you are good to go. If the second one returns a
`forbidden` error, go back and apply the permission grant above before continuing.

---

## Setting Up the Cluster

The first thing to do is make sure your cluster has the right foundation in place. For a
full watsonx.ai deployment you want at least six worker nodes — on AWS, `m6i.2xlarge`
instances work well. Three of those nodes should be dedicated to **OpenShift Data
Foundation (ODF)**, which is what gives CP4D its storage layer. Head into the OpenShift
web console, open **OperatorHub**, search for *OpenShift Data Foundation* and install it.
Once it is running, it will create the block and file storage classes that every
subsequent step depends on.

If you plan to run foundation models, you also need GPU support. Install the **Node
Feature Discovery (NFD)** operator first — it discovers the hardware capabilities of your
nodes — then install the **NVIDIA GPU Operator** and create a Cluster Policy. Both are
available through OperatorHub. If you are going the Watson Studio–only route, skip GPU
setup entirely and move straight to the next section.

---

## Installing cpd-cli

With the cluster ready, set up the `cpd-cli` tool on your workstation. This is the
command-line interface that drives the entire CP4D installation process.

```bash
# Download the Enterprise Edition for Linux
wget https://github.com/IBM/cpd-cli/releases/download/v14.0.0/cpd-cli-linux-EE-14.0.0.tgz

# Extract and put it on your PATH
mkdir -p ~/cpd && tar -xzf cpd-cli-linux-EE-14.0.0.tgz -C ~/cpd --strip-components=1
export PATH=~/cpd:$PATH

# Confirm it works
cpd-cli version
```

Always match the CLI version to your CP4D version. If you are on CP4D 4.8.x, use v13.x
instead.

---

## Configuring Your Environment Variables

Rather than typing your cluster details into every command, we store them all in a single
file that we source before running anything. Think of `cpd_vars.sh` as the control panel
for your installation — change a value in one place and it propagates everywhere.

Create the file, fill in your actual values, and source it:

```bash
cat > ~/cpd_vars.sh << 'EOF'
# ── Cluster ──────────────────────────────────────────────────────────────────
export OCP_URL=https://YOUR_CLUSTER_API_ADDRESS:6443
export OPENSHIFT_TYPE=self-managed          # or: ROSA, ROKS, ARO
export IMAGE_ARCH=amd64
export OCP_USERNAME=kubeadmin
export OCP_PASSWORD=YOUR_PASSWORD

# ── Login shortcuts ───────────────────────────────────────────────────────────
export SERVER_ARGUMENTS="--server=${OCP_URL}"
export LOGIN_ARGUMENTS="--username=${OCP_USERNAME} --password=${OCP_PASSWORD}"
export CPDM_OC_LOGIN="cpd-cli manage login-to-ocp ${SERVER_ARGUMENTS} ${LOGIN_ARGUMENTS}"

# ── Projects / Namespaces ─────────────────────────────────────────────────────
export PROJECT_CERT_MANAGER=ibm-cert-manager
export PROJECT_LICENSE_SERVICE=ibm-licensing
export PROJECT_SCHEDULING_SERVICE=cpd-scheduler
export PROJECT_CPD_INST_OPERATORS=cpd-operators
export PROJECT_CPD_INST_OPERANDS=cpd-instance

# ── Storage classes — run `oc get storageclass` to check yours ───────────────
export STG_CLASS_BLOCK=ocs-storagecluster-ceph-rbd
export STG_CLASS_FILE=ocs-storagecluster-cephfs

# ── IBM credentials ───────────────────────────────────────────────────────────
export IBM_ENTITLEMENT_KEY=YOUR_ENTITLEMENT_KEY

# ── CP4D version ──────────────────────────────────────────────────────────────
export VERSION=5.0.2

# ── Components ────────────────────────────────────────────────────────────────
export COMPONENTS=ibm-cert-manager,ibm-licensing,scheduler,cpfs,cpd_platform,ws,wml,watsonx_ai
EOF

chmod 700 ~/cpd_vars.sh
source ~/cpd_vars.sh
```

Two things worth noting here. First, check your storage class names with
`oc get storageclass` before proceeding — if they do not match exactly, every
storage-related step will fail silently. Second, the `PROJECT_SCHEDULING_SERVICE`
variable is new in CP4D 5.x. The scheduler now lives in its own namespace, and you will
see it used a few steps ahead.

---

## Logging In and Registering Your Entitlement Key

With the environment sourced, log in to the cluster through `cpd-cli` and register your
IBM entitlement key. This tells your cluster where to pull IBM container images from and
gives it permission to do so.

```bash
# Log in via cpd-cli
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Register the entitlement key as a global pull secret
cpd-cli manage add-icr-cred-to-global-pull-secret \
  --entitled_registry_key=${IBM_ENTITLEMENT_KEY}
```

After running the second command, OpenShift nodes may be cycled or reconfigured to apply
the new pull secret. Give it a few minutes before moving on.

---

## Setting Up the IBM Operator Catalog

This is the step that trips up most people following older tutorials. The old approach —
running `oc apply` against a YAML file on GitHub — no longer works because that registry
has been decommissioned. We now apply the catalog source directly from IBM's container
registry instead.

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
  annotations:
    olm.catalogImageTemplate: "icr.io/cpopen/ibm-operator-catalog:v{kube_major_version}.{kube_minor_version}"
spec:
  displayName: IBM Operator Catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
```

> ⚠️ **Permissions note:** The command above requires `cluster-admin` rights to create
> a `CatalogSource` object. The verification command below requires at minimum the
> `view` role on the `openshift-marketplace` namespace. If you have not done so already,
> refer to **Step 2** at the top of this guide.

Wait a moment then check that it came up correctly:

```bash
# Requires view access to openshift-marketplace — see Step 2 if this fails
oc get catsrc ibm-operator-catalog -n openshift-marketplace
```

You want to see `READY` in the status column. If it shows `CONNECTING` for more than a
few minutes, jump to the troubleshooting section at the end of this post. Everything from
here on depends on this being healthy, so do not skip the verification.

---

## Creating Namespaces and Authorizing the Topology

CP4D uses a layered namespace model: operators live in one project and the actual
workloads (operands) live in another. We also need dedicated namespaces for the cert
manager, licensing service and the scheduler. Create them all now:

```bash
oc new-project ${PROJECT_CERT_MANAGER}
oc new-project ${PROJECT_LICENSE_SERVICE}
oc new-project ${PROJECT_SCHEDULING_SERVICE}
oc new-project ${PROJECT_CPD_INST_OPERATORS}
oc new-project ${PROJECT_CPD_INST_OPERANDS}
```

Then authorize the operator namespace to manage the operand namespace:

```bash
cpd-cli manage authorize-instance-topology \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
```

---

## Installing the Foundational Services

CP4D 5.x has three foundational service layers that need to go in before anything else:
the Certificate Manager, the License Service, and the Scheduling Service. The scheduler
is a new mandatory component in this version — it was not needed in 4.8.x, which is why
many older guides omit it.

```bash
# Certificate Manager and License Service
cpd-cli manage apply-cluster-components \
  --release=${VERSION} \
  --license_acceptance=true \
  --cert_manager_ns=${PROJECT_CERT_MANAGER} \
  --licensing_ns=${PROJECT_LICENSE_SERVICE}

# Scheduling Service — new mandatory step in CP4D 5.x
cpd-cli manage apply-scheduler \
  --release=${VERSION} \
  --license_acceptance=true \
  --scheduler_ns=${PROJECT_SCHEDULING_SERVICE}

# Wire the topology together
cpd-cli manage setup-instance-topology \
  --release=${VERSION} \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --license_acceptance=true \
  --block_storage_class=${STG_CLASS_BLOCK}
```

---

## Installing the Cloud Pak for Data Platform

Now we install the CP4D control plane — the web UI and core platform that everything else
plugs into. This happens in two phases: first the OLM operator objects, then the actual
platform operands. The second command can take 30 to 60 minutes, so this is a good time
to grab a coffee.

```bash
# Phase 1 — OLM operator objects
cpd-cli manage apply-olm \
  --release=${VERSION} \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --components=cpd_platform

# Phase 2 — Platform operands (30–60 minutes)
cpd-cli manage apply-cr \
  --release=${VERSION} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --components=cpd_platform \
  --block_storage_class=${STG_CLASS_BLOCK} \
  --file_storage_class=${STG_CLASS_FILE} \
  --license_acceptance=true
```

Once it finishes, retrieve your console URL and initial admin credentials:

```bash
cpd-cli manage get-cpd-instance-details \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --get_admin_initial_credentials=true
```

Open that URL in a browser and verify you can log in before continuing. It is worth
confirming the platform is healthy at this point rather than discovering a problem two
hours later.

---

## Installing the Watsonx.ai Service

With the platform running, it is time to add watsonx.ai on top. Same two-phase pattern
as before — OLM objects first, then the custom resource. Expect this one to take 60 to
90 minutes.

```bash
# Phase 1 — OLM objects
cpd-cli manage apply-olm \
  --release=${VERSION} \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --components=watsonx_ai

# Phase 2 — Custom resource (60–90 minutes)
cpd-cli manage apply-cr \
  --components=watsonx_ai \
  --release=${VERSION} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --block_storage_class=${STG_CLASS_BLOCK} \
  --file_storage_class=${STG_CLASS_FILE} \
  --license_acceptance=true
```

You can watch the progress live with:

```bash
cpd-cli manage get-cr-status --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
```

---

## Adding Foundation Models

Once watsonx.ai is up, it ships without any language models pre-loaded — you choose and
activate exactly the ones you need. Each model requires a dedicated GPU worker node, so
add one to your cluster before patching. On AWS a `g5.8xlarge` works well (32 vCPU,
128 GB RAM, A10G GPU). On Azure, use `Standard_NC24ads_A100_v4`, and on IBM Cloud,
`gx3.16x80.l4`.

With the GPU node ready, patch the watsonx.ai custom resource to activate your models:

```bash
oc patch watsonxaiifm watsonxaiifm-cr \
  --namespace=${PROJECT_CPD_INST_OPERANDS} \
  --type=merge \
  --patch='{
    "spec": {
      "install_model_list": [
        "ibm-granite-13b-chat-v2",
        "ibm-granite-20b-code-instruct-r1-1",
        "meta-llama-llama-2-13b-chat"
      ]
    }
  }'
```

> Available models depend on your IBM entitlement and the catalog version active in your
> cluster. For the full up-to-date list and GPU requirements, see the
> [IBM documentation on adding foundation models](https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=setup-adding-foundation-models).

---

## The Lightweight Path: Watson Studio Only

If you are working within the constraints of a free trial cluster or a smaller on-prem
environment, skip the watsonx.ai steps above entirely and install Watson Studio instead.
You get Jupyter notebooks, AutoAI, Data Refinery and the model training framework —
which covers the vast majority of academic lab scenarios — with just three worker nodes,
no GPU, and roughly 500 GB of storage.

Follow every step above up through the CP4D platform installation, then replace the
watsonx.ai step with this:

```bash
# Watson Studio — OLM objects
cpd-cli manage apply-olm \
  --release=${VERSION} \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --components=ws

# Watson Studio — operands
cpd-cli manage apply-cr \
  --components=ws \
  --release=${VERSION} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --block_storage_class=${STG_CLASS_BLOCK} \
  --file_storage_class=${STG_CLASS_FILE} \
  --license_acceptance=true
```

Monitor it the same way:

```bash
cpd-cli manage get-cr-status --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
```

**A word on R Studio specifically.** If your goal is to run R Studio for data science
coursework, you cannot install it as a standalone service — it will fail. In CP4D 5.x,
R Studio is bundled as an extension of Watson Studio, not a separate component. Install
Watson Studio first using the commands above, and then enable R Studio from the CP4D
console under **Services → Instances → Watson Studio → R Studio**. It takes just a few
clicks from inside the UI and does not require any additional CLI work.

---

## How Much Resource Do You Actually Need?

Here is a quick reference so you can size your cluster before starting rather than
hitting capacity issues halfway through:

| Component | CPU (cores) | RAM (GB) | Storage |
|---|---|---|---|
| CP4D Platform | 16 | 64 | 100 GB block |
| Watson Studio (`ws`) | 20 | 80 | 200 GB file |
| Watson Machine Learning (`wml`) | 16 | 64 | 100 GB block |
| watsonx.ai (no models) | 32 | 128 | 500 GB |
| Each foundation model (e.g., Granite 13B) | GPU required | 32+ | 50–100 GB |

These are minimums for a working installation. Total storage for a full watsonx.ai
deployment with a few models typically lands between 1 and 2 TB depending on which
components you enable. Production deployments should add headroom on top of these numbers.

---

## When Things Go Wrong

Even when you follow every step carefully, a few things have a habit of going sideways.
Here are the ones I have seen most often and how to fix them.

### You get a "forbidden" error on an oc get command

This is an RBAC permissions issue, not a problem with your installation. OpenShift
controls access to resources at the namespace level, and some namespaces — like
`openshift-marketplace` — require an explicit permission grant before a regular user can
read from them.

The fix is straightforward. Ask your cluster administrator to run:

```bash
# Replace "yourusername" with the actual OpenShift username
oc adm policy add-role-to-user view yourusername -n openshift-marketplace
```

If you are the admin on your own trial cluster, run it yourself. After that, any `oc get`
command targeting the `openshift-marketplace` namespace will work as expected. For a
broader read-only view across the whole cluster, the admin can alternatively grant:

```bash
oc adm policy add-cluster-role-to-user cluster-reader yourusername
```

Use the namespace-scoped option (first command) for shared lab environments, and the
cluster-reader option only when a user genuinely needs visibility across all namespaces.

### The catalog source stays in CONNECTING

This usually means the cluster cannot reach `icr.io`. Make sure your cluster has
outbound internet access to IBM container registry endpoints — this is a requirement for
any connected installation. Start by checking the catalog pod's logs:

```bash
oc get pods -n openshift-marketplace | grep ibm-operator
oc logs <pod-name> -n openshift-marketplace
```

Then verify that your global pull secret actually includes the IBM registry credentials:

```bash
oc get secret pull-secret -n openshift-config \
  -o jsonpath='{.data.\.dockerconfigjson}' \
  | base64 --decode | jq '.auths | keys'
```

You should see `icr.io` in that list. If you do not, re-run the
`add-icr-cred-to-global-pull-secret` command and allow a few minutes for nodes to be
reconfigured.

### A custom resource is stuck in InProgress

Get the detailed status first — it usually tells you exactly what is blocked:

```bash
cpd-cli manage get-cr-status --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
```

Then look at the pods that are not healthy:

```bash
oc get pods -n ${PROJECT_CPD_INST_OPERANDS} | grep -v Running | grep -v Completed
oc logs <pod-name> -n ${PROJECT_CPD_INST_OPERANDS} --previous
```

The most common culprits are insufficient PVC quota, a wrong storage class name, or a
node that has run out of memory. Check all three before assuming something more exotic
is wrong.

### Storage class not found

Run `oc get storageclass` and compare the output against what you have in `cpd_vars.sh`.
The names must match character for character — a wrong suffix like `-csi` vs no suffix
is enough to break things. Correct the variable, re-source the file, and retry.

### OLM objects fail to apply

Make sure the catalog source is in `READY` state before running any `apply-olm` command.
If it is not, delete and re-apply it:

```bash
oc delete catsrc ibm-operator-catalog -n openshift-marketplace
# Then re-run the catalog source creation from the step above
```

---

## Wrapping Up

That covers everything from a fresh OpenShift cluster to a fully running watsonx.ai
environment — or a lean Watson Studio installation if you are working with limited
resources. The three things that catch most people are the decommissioned catalog
registry (fixed by using `icr.io/cpopen` directly), the missing scheduler namespace in
CP4D 5.x (fixed by adding `apply-scheduler` and `PROJECT_SCHEDULING_SERVICE` to your
setup), and RBAC permission errors on verification commands (fixed with a single
`oc adm policy` command before you start). Get those three right and the rest of the
installation follows a clean, predictable path.

For further reading:
- [IBM Cloud Pak for Data 5.0.x documentation](https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x)
- [cpd-cli releases on GitHub](https://github.com/IBM/cpd-cli/releases)
- [IBM Container Library — entitlement key](https://myibm.ibm.com/products-services/containerlibrary)
- [IBM Skills Network](https://skills.network/) — for academic program access requests
