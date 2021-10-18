# XSOAR-HA-Ansible-playbook
Ansible playbook for XSOAR install in HA mode

## Purpose
<img width="520" alt="image" src="https://user-images.githubusercontent.com/41276379/137814717-a5cea4a4-45bd-4540-b2cd-7feab0add36c.png">

From 6.1, XSOAR supports the Active-Active high availability design with the support of NFS for configuration store and ElasticSearch for shared database. 
Using this model, we need to:
- Install the NFS and ES first
- Mount the /var/lib/demisto folder on XSOAR servers to NFS
- Connect to ES with the XSOAR installation arguments 

## Ansible
Ansible is such a good tool to deploy a bundle of servers automatically, and XSOAR HA is time consuming enough to automate its deployment. This playbook is packed to a shell script to:
- Run on any Ubuntu, Centos or MacOS client machine
- Check and install Python and Ansible if not installed
- Install 1 NFS, 3 ElasticSearch nodes, 2 XSOAR and make them up and running

Please feel free to expand the deployment and add best practice hardening configurations of your needs.

## Usage
### Prepare the remote servers
- The script will install on 6 servers of the XSOAR HA solution (similar to the above diagram)
- You need to install Linux (Ubuntu 18.04+/Centos 8/RHEL 8) by yourself on the 6 servers
- Configure SSH with SSH Key 

### On your client machine
The client machine is the one you run this script. It can be your Mac, Ubuntu or Centos. 
- Make sure that you have your SSH key somewhere on the client and you know its path (e.g ~/.ssh/my-key)
- Put the script and XSOAR installer script in the same folder
<img width="265" alt="image" src="https://user-images.githubusercontent.com/41276379/137814175-d2e7f37b-3548-4b4b-b9aa-2c39da839277.png">
- Run the script:

> chmod +x xsoar-system-installer.sh
> 
> ./xsoar-system-install.sh
> 
- The script will ask for: IP Address of the 6 servers, SSH username and path to the SSH key
- Have a cup of coffee and enjoy your XSOAR HA servers :)
