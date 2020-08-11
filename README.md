# anthos-lab

A simple tool to deploy Anthos deployments with ASM. Built with `bash` and
leveraging a simple plugin architecture, it's
easy to read and extend.

## Usage

```
./anthos-lab.sh help
USAGE: ./anthos-lab.sh [cleanup|deploy]

```

### Assumptions 

This tools assumes you're logged into the Google Cloud SDK. To confirm, run this
command and make sure you're logged in as your `google.com` gcloud account. 

```
gcloud auth list
```

You should see output similar to the following: 

```
                                Credentialed Accounts
ACTIVE  ACCOUNT
        insecure-cloudtop-shared-user@cloudtop-prod.google.com.iam.gserviceaccount.com
*       jamieduncan@google.com

To set the active account, run:
    $ gcloud config set account `ACCOUNT`

```

### Environments

This project was originally written to work on a cloudshell instance. After moving to
this git repository, it's now being developed and used on a cloudtop instance.
While I haven't tested it, it would also likely work in the Linux VM on a
corporate Chromebook or a corporate Macbook.

### Configuration Files

Configuration files are kept in the `cfg` directory

* cfg/clusters.conf - a line-delimited file of the clusters you'd like to create or
  clean up. There is a file named `clusters.conf.example` to use as a starting point: 

  ```
  anthos-1
  anthos-2
  ```

* cfg/default.config - a default config file. This is sourced at the beginning of
  the `anthos-lab.sh` script. There's an example named `default.config.example`
  to get your started: 

  ```
  REGION=us-east1
  PROJECT=<YOUR PROJECT>
  CLUSTER_LIST=cfg/clusters.config.example
  ASM_VER=1.6.5-asm.7
  GCP_EMAIL_ADDRESS=<YOUR GCP EMAIL>
  # if addons have dependencies on other addons, they are processed in the order 
  # here
  ADDONS=(asm acm)
  UPDATE_PKGS=false
  ```

#### Enabling addons 

Addons are things that are laid on top of your Anthos cluster once it's
deployed. Currently, there are addons for ACM and ASM. The `ADDONS` parameter in
`default.config` tells the tool which addons to process when deploying or
cleaning up a cluster. They are processed in order.

### Options 

* deploy - deploy clusters from your `clusters.config` file. These will be the
  latest available GKE clusters with ASM deployed using the `ASM_VER` variable
  in `default.config`. Each cluster is 4 nodes of type `e2-standard-4`.

* cleanup - this removes all filesystem artifacts and also all GCP artifacts
  that were created by a `deploy` command.

## Future Work

Down the road, I plan to start adding specific demo scenarios such as
multi-cluster meshes, various app deployments, etc.

## Contributing

To create a plugin, a few steps are required. 

* Create a folder in the `addons` directory for your new addon. 

```
ll addons 
total 12K
drwxr-x--- 2 jamieduncan primarygroup 4.0K Aug 10 18:24 acm
drwxr-x--- 2 jamieduncan primarygroup 4.0K Aug 10 20:26 anthos
drwxr-x--- 2 jamieduncan primarygroup 4.0K Aug 10 18:23 asm
drwxr-x--- 2 jamieduncan primarygroup 4.0K Aug 10 18:23 my_new_addon
```

* Create a `deploy.sh` script for your addon in your new folder. This script
  runs when you execute the `deploy` command. It has access to all parameters set in the `prep` function in the main
  script, including an array of clusters to be created and all configuration
  parameters. Look at the deploy scripts in `acm` and `asm` for usage examples.

* Create a `cleanup.sh` script for your addon in your new folder. This will be
  run when cleaning up a deployment. It also has access to everything created in
  the `prep` function. 

* Include your addon to the `ADDONS` parameter in `default.config`.

Inside your addon folder, you can include any needed files and include them in
your scripts as needed.