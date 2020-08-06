# anthos-lab

A simple tool to deploy Anthos deployments with ASM. Built with `bash`, it's
easy to read and extend.

## Usage

```
./anthos-lab.sh help
USAGE: ./anthos-lab.sh [deploy|cleanup|redeploy]

```

### Config Files 

* clusters.conf - a line-delimited file of the clusters you'd like to create or
  clean up. Example: 

  ```
  anthos-1
  anthos-2
  ```

* default.config - a default config file. This is sourced at the beginning of
  the `anthos-lab.sh` script. Example: 

  ```
  REGION=us-east1
  PROJECT=jamieduncan
  CLUSTER_LIST=clusters.config
  ASM_VER=1.6.5-asm.7
  GCP_EMAIL_ADDRESS=jamieduncan@google.com
  ```

### Options 

* deploy - deploy clusters from your `clusters.config` file. These will be the
  latest available GKE clusters with ASM deployed using the `ASM_VER` variable
  in `default.config`. Each cluster is 4 nodes of type `e2-standard-4`.

* cleanup - this removes all filesystem artifacts and also all GCP artifacts
  that were created by a `deploy` command.

* redeploy - this cleans up old clusters and redploys them as fresh instances.
  This is useful if you get something too far off line to repair.

## Future Work

Down the road, I plan to start adding specific demo scenarios such as
multi-cluster meshes, various app deployments, etc.