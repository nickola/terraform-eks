# About

Simple configuration for provisioning AWS (Amazon Web Services)
EKS (Elastic Kubernetes Service) cluster with Terraform.

Can be used as a module, for example (EKS cluster in `us-east-1` region
within `us-east-1a` and `us-east-1b` availability zones with 2 node groups):

```terraform
module "terraform_eks" {
  source = "../modules/terraform-eks"
  region = "us-east-1"

  # VPC
  vpc_name               = "kubernetes-vpc"
  vpc_availability_zones = ["a", "b"] # At least 2 are required
  vpc_private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"] # Not less than number of availability zones
  vpc_public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"] # Not less than number of availability zones

  # EKS
  eks_name        = "kubernetes"
  eks_version     = "1.24"
  eks_node_groups = [
    {name = "node-group-1", instance_type = "t2.micro", min_size = 2, max_size = 3, desired_size = 2},
    {name = "node-group-2", instance_type = "t2.small", min_size = 2, max_size = 3, desired_size = 2}
  ]
}
```

# Contents

- [Getting access to AWS](#getting-access-to-aws)
- [Provisioning EKS cluster](#provisioning-eks-cluster)
- [Kubernetes workload examples](#kubernetes-workload-examples)
  - [Pod](#pod)
  - [Deployment with podAntiAffinity](#deployment-with-podantiaffinity)
  - [Autoscaling](#autoscaling)
  - [CronJob with Role](#cronjob-with-role)
- [Which resources were created in AWS](#which-resources-were-created-in-aws)
  - [VPC (Virtual Private Cloud)](#vpc-virtual-private-cloud)
  - [EKS (Elastic Kubernetes Service)](#eks-elastic-kubernetes-service)

# Getting access to AWS

Make sure that you have access to AWS:

```console
$ aws sts get-caller-identity

{
    "UserId": "...",
    "Account": "...",
    ...
}
```

If you don't have access - check the configuration in `~/.aws`.
You can configure AWS using this command:

```console
$ aws configure

AWS Access Key ID [None]: <access_key_id>
AWS Secret Access Key [None]: <secret_access_key>
Default region name [None]: <region>
Default output format [None]: yaml
```

Or you can use environment variables:

```console
export AWS_REGION=...
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

# Provisioning EKS cluster

Check and update settings in the `variables.tf` file or
use this `terraform-eks` as a module (see an example in [About](#about) section).

Initialize Terraform (it will download required modules and provider plugins):

```console
$ terraform init

Initializing modules...
Initializing the backend...
Initializing provider plugins...

Terraform has been successfully initialized!
```

Check actions that will be performed:

```console
$ terraform plan

Plan: ... to add, 0 to change, 0 to destroy.
```

Apply the configuration (confirm with `yes`):

```console
$ terraform apply

Do you want to perform these actions?
  ...
  Only 'yes' will be accepted to approve.

  Enter a value: yes
  ...

Apply complete! Resources: ... added, 0 changed, 0 destroyed.

Outputs:

aws_region = "..."
eks_endpoint = "https://...eks.amazonaws.com"
eks_name = "..."
eks_security_group_id = "..."
```

Check the `outputs` above (or run `terraform output`) and update your local credentials for `kubectl`
using the following command (`~/.kube/config` file will be overwritten, create a backup if needed):

```console
$ aws eks update-kubeconfig --region <aws_region> --name <eks_name>

Updated context ... in .../.kube/config
```

Check nodes in the provisioned EKS cluster:

```console
$ kubectl get nodes

NAME               STATUS ROLES   AGE   VERSION
ip-...ec2.internal Ready  <none>  ...   ...
ip-...ec2.internal Ready  <none>  ...   ...
```

Congratulations, you can use your new Kubernetes cluster!

# Kubernetes workload examples

We will use the `default` namespace for all examples.
If you want to use specific namespace, just create it (`kubectl create namespace example`)
and specify in the `kubectl` commands below (as `--namespace example`).

## Pod

Let's deploy and check a `Pod` that do nothing:

```console
$ kubectl apply --filename ./_workload/pod.yaml

pod/pod-do-nothing created
```

```console
$ kubectl get pods

NAME           READY STATUS  RESTARTS AGE
pod-do-nothing 1/1   Running 0        ...
```

```console
$ kubectl logs --follow pod-do-nothing

I am doing nothing and show this message every 5 seconds (date: YYYY-MM-DD HH:MM:05 UTC)...
I am doing nothing and show this message every 5 seconds (date: YYYY-MM-DD HH:MM:10 UTC)...
I am doing nothing and show this message every 5 seconds (date: YYYY-MM-DD HH:MM:15 UTC)...
```

Let's delete it:

```console
$ kubectl delete  --filename ./_workload/pod.yaml

pod "pod-do-nothing" deleted
```

## Deployment with podAntiAffinity

Let's deploy and check a `Deployment` with `podAntiAffinity`,
it will try to start replicas in different availability zones (if possible).

This `Deployment` runs `nginx` and creates `Service` (`type: LoadBalancer`), so we will check response from `nginx`.

```console
$ kubectl apply --filename ./_workload/deployment-availability-zones.yaml

configmap/deployment-availability-zones created
deployment.apps/deployment-availability-zones created
```

```console
$ kubectl get deployments

NAME                          READY UP-TO-DATE AVAILABLE AGE
deployment-availability-zones 2/2   2          2         ...
```

```console
$ kubectl get pods --output wide

NAME                              READY STATUS  RESTARTS AGE   IP         NODE
deployment-availability-zones-... 1/1   Running 0        ...   10.0.1.103 ip-10-0-1-46.ec2.internal
deployment-availability-zones-... 1/1   Running 0        ...   10.0.2.106 ip-10-0-2-188.ec2.internal
```

Pods were deployed to nodes in different subnets (different availability zones).

Let's increase number of replicas:

```console
$ scale deployment deployment-availability-zones --replicas 3

deployment.apps/deployment-availability-zones scaled
```

```console
$ kubectl get pods --output wide

NAME                              READY STATUS  RESTARTS AGE   IP         NODE
deployment-availability-zones-... 1/1   Running 0        ...   10.0.1.212 ip-10-0-1-123.ec2.internal
deployment-availability-zones-... 1/1   Running 0        ...   10.0.1.103 ip-10-0-1-46.ec2.internal
deployment-availability-zones-... 1/1   Running 0        ...   10.0.2.106 ip-10-0-2-188.ec2.internal
```

New pod was scheduled to node within the same availability zone, because we have only 2 availability zones.

Let's check `nginx` response:

```console
$ kubectl get service

NAME                          TYPE         CLUSTER-IP EXTERNAL-IP                     PORT(S)      AGE
deployment-availability-zones LoadBalancer ...        a...us-east-1.elb.amazonaws.com 80:30768/TCP ...
```

```console
$ curl http://a...us-east-1.elb.amazonaws.com

I am nginx from pod: deployment-availability-zones-...
```

Let's delete it:

```console
$ kubectl delete --filename ./_workload/deployment-availability-zones.yaml

deployment.apps "deployment-availability-zones" deleted
```

## Autoscaling

To use `HorizontalPodAutoscaler` we need to install the Kubernetes Metrics Server,
is not deployed by default in Amazon EKS cluster:

```console
$ kubectl apply --filename https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

...
deployment.apps/metrics-server created
...
```

Let's deploy and check this autoscaling example:

```console
$ kubectl apply --filename ./_workload/autoscaling.yaml

deployment.apps/deployment-use-cpu created
horizontalpodautoscaler.autoscaling/autoscaling created
```

```console
$ kubectl get horizontalpodautoscalers

NAME        REFERENCE                     TARGETS       MINPODS MAXPODS REPLICAS AGE
autoscaling Deployment/deployment-use-cpu <unknown>/10% 1       2       1        ...
```

```console
$ kubectl get pods

NAME                   READY STATUS  RESTARTS AGE
deployment-use-cpu-... 1/1   Running 0        ...
```

Let's wait for a few minutes and check again:

```console
$ kubectl get horizontalpodautoscalers

NAME        REFERENCE                     TARGETS  MINPODS MAXPODS REPLICAS AGE
autoscaling Deployment/deployment-use-cpu 100%/10% 1       2       2        ...
```

```console
$ kubectl get pods

NAME                   READY STATUS  RESTARTS AGE
deployment-use-cpu-... 1/1   Running 0        ...
deployment-use-cpu-... 1/1   Running 0        ...
```

It works, second pod was created by `HorizontalPodAutoscaler`.

Let's delete it:

```console
$ kubectl delete --filename ./_workload/autoscaling.yaml

deployment.apps "deployment-use-cpu" deleted
horizontalpodautoscaler.autoscaling "autoscaling" deleted
```

```console
$ kubectl delete --filename https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

...
deployment.apps "metrics-server" deleted
...
```

## CronJob with Role

Let's deploy and check a `CronJob` with a `Role` that shows pods in a namespace every 5 minutes:

```console
$ kubectl apply --filename ./_workload/cronjob-role.yaml

role.rbac.authorization.k8s.io/cronjob-show-pods created
serviceaccount/cronjob-show-pods created
rolebinding.rbac.authorization.k8s.io/cronjob-show-pods created
cronjob.batch/cronjob-show-pods created
```

```console
$ kubectl get cronjobs

NAME              SCHEDULE    SUSPEND ACTIVE LAST SCHEDULE AGE
cronjob-show-pods 0/5 * * * * False   0      <none>        ...
```

Let's wait for ~5 minutes and check again:

```console
$ kubectl get cronjobs

NAME              SCHEDULE    SUSPEND ACTIVE LAST SCHEDULE AGE
cronjob-show-pods 0/5 * * * * False   0      5s            ...
```

It was executed, let's check logs:

```console
$ kubectl get pods

NAME                 READY STATUS    RESTARTS AGE
cronjob-show-pods-... 0/1  Completed 0        ...
```

```console
$ kubectl logs cronjob-show-pods-...

+ kubectl get pods
NAME                  READY STATUS  RESTARTS AGE
cronjob-show-pods-... 1/1   Running 0        ...
```

It works, we can see pods list (`cronjob-show-pods-...` had the `Running` status at that time).

Let's delete it:

```console
$ kubectl delete --filename ./_workload/cronjob-role.yaml

role.rbac.authorization.k8s.io "cronjob-show-pods" deleted
serviceaccount "cronjob-show-pods" deleted
rolebinding.rbac.authorization.k8s.io "cronjob-show-pods" deleted
cronjob.batch "cronjob-show-pods" deleted
```

# Which resources were created in AWS

Below is a brief description of the actions that were performed in AWS.

## VPC (Virtual Private Cloud)

- Create VPC.
- Create public subnets.
- Create private subnets.
- Create Internet Gateway for VPC.
- Create Elastic IPs for NAT Gateways.
- Create NAT Gateways in public subnets (one NAT Gateway per availability zone).
- Create route table and default route for public subnets (to Internet Gateway).
- Create route tables and default route for private subnets (to corresponding NAT Gateways in public subnets).

## EKS (Elastic Kubernetes Service)

- Create Roles in IAM (Identity and Access Management) for EKS (EKS make calls to other AWS services).
- Create Security Groups for EKS cluster and nodes.
- Create EKS cluster with defined node groups (nodes in private subnets).
- Kubernetes control plane runs in an account managed by AWS
  (on its own set of Amazon EC2 instances in multiple availability zones).
