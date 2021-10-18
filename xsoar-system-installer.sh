#!/bin/bash
cat <<EOF
__  ______   ___    _    ____    ___           _        _ _
\ \/ / ___| / _ \  / \  |  _ \  |_ _|_ __  ___| |_ __ _| | | ___ _ __
 \  /\___ \| | | |/ _ \ | |_) |  | || '_ \/ __| __/ _  | | |/ _ \ '__|
 /  \ ___) | |_| / ___ \|  _ <   | || | | \__ \ || (_| | | |  __/ |
/_/\_\____/ \___/_/   \_\_| \_\ |___|_| |_|___/\__\__,_|_|_|\___|_|

EOF
echo
echo "=========================================================================="
echo " Check the system for Python, Pip3 and Ansible"
echo " The installation of these components will take about 3-5 mins if you"
echo " have not had them already in your machine"
echo "=========================================================================="
sleep 5
# Install Ansible
echo
echo "Installing Pip3"
osrelease=$(uname -a | cut -d" " -f2)
if [ $osrelease == "ubuntu" ]
then
    apt list --installed | grep python3-pip > /dev/null
    if [ $? -eq 1 ]
    then
        apt-get -y install python3-pip
    fi
elif [ $osrelease == "Centos" ]
then
    rpm -eq | grep python3-pip > /dev/null
    if [ $? -eq 1 ]
    then
        yum -y yum install python3-pip > /dev/null
    fi
else
    echo "You are on Mac, if you have Python3 & Pip3 installed, please select [y] to skip, else select [n] to install Python3 and Pip3"
    read macinstall
    if [ $macinstall == "y" ]
    then
        echo "All good"
    else
        brew install python3
    fi
fi
python3 -m pip install ansible
if [ $? -eq 1 ]
then
    echo "Something wrong, cannot install Ansible, please check it yourself then run the script again"
else
echo
echo "=========================================================================="
echo " First, you need to input basic information about the system such as      "
echo " IP Address/Hostname, SSH username and SSH key path for the script to     "
echo " install to the desired servers correctly.                                "
echo " The script will install NFS, ElasticSearch cluster and XSOAR             "
echo "=========================================================================="
echo

# Collect input from user
xsoarinstaller=$(ls -l | awk '{print $9}' | grep -e 'demistoserver-.*\.sh' | head -1)
# xsoarinstaller=$(find . -name "demisto*.sh" -printf "%f\n" | head -1)
echo "XSOAR-01 IP Address/Hostname:"
read xsoar01host
echo "XSOAR-02 IP Address/Hostname:"
read xsoar02host
echo "NFS Server IP Address/Hostname:"
read nfshost
echo "ElasticSearch 01 IP Address/Hostname:"
read es1host
echo "ElasticSearch 02 IP Address/Hostname:"
read es2host
echo "ElasticSearch 03 IP Address/Hostname:"
read es3host
echo "SSH sudoer username to access all servers:"
read sshuser
echo "Does this user require password for sudo (y/n):"
read sshsudopassword
echo "SSH Private key file (full path):"
read sshkey


# Build Ansible playbook files
cat <<EOF > inventory.yaml
all:
    children:
        # Group XSOAR servers
        xsoar:
            hosts:
                xsoar1:
                    ansible_host: $xsoar01host 
                    ansible_connection: ssh
                    ansible_user: $sshuser
                    ansible_ssh_private_key_file: $sshkey
                    xsoar_installer: $xsoarinstaller
                xsoar2:
                    ansible_host: $xsoar02host 
                    ansible_connection: ssh
                    ansible_user: $sshuser
                    ansible_ssh_private_key_file: $sshkey
        # Group NFS servers
        nfs:
            hosts:
                nfs1:
                    ansible_host: $nfshost
                    ansible_connection: ssh
                    ansible_user: $sshuser
                    ansible_ssh_private_key_file: $sshkey
        # Group ElasticSearch servers
        es:
            hosts:
                es1:
                    ansible_host: $es1host
                    ansible_connection: ssh
                    ansible_user: $sshuser
                    ansible_ssh_private_key_file: $sshkey
                    es_node: node-1
                es2:
                    ansible_host: $es2host
                    ansible_connection: ssh
                    ansible_user: $sshuser
                    ansible_ssh_private_key_file: $sshkey
                    es_node: node-2
                es3:
                    ansible_host: $es3host
                    ansible_connection: ssh
                    ansible_user: $sshuser
                    ansible_ssh_private_key_file: $sshkey
                    es_node: node-3
EOF

cat <<EOF > nfs-server-playbook.yaml
-   name: INSTALL NFS SERVERS
    hosts: nfs
    tasks:
    # Install NFS server on Ubuntu environment
        -   name: Install NFS service on Debian
            become: yes
            apt: 
                name: nfs-kernel-server
                state: present
                update_cache: yes
            when: ansible_os_family == "Debian"
    # Install NFS server on Centos, Redhat environment
        -   name: Install NFS service on RHEL
            become: yes
            yum: 
                name: nfs-utils
                state: present
                update_cache: yes
            when: ansible_os_family == "RedHat"
        -   name: start the nfs service on RHEL
            become: yes
            service:
                name: nfs-server
                state: started
    # Create shared folder
        -   name: Create a shared folder on NFS server Redhat
            become: yes
            file: 
                path: /var/lib/demisto
                state: directory
            when: ansible_os_family == "RedHat"
        -   name: Create a shared folder on NFS server Debian
            become: yes
            file: 
                path: /var/lib/demisto
                owner: nobody
                group: nogroup
                state: directory
            when: ansible_os_family == "Debian"
        -   name: export the nfs setting
            become: yes
            lineinfile:
                path: /etc/exports
                line: /var/lib/demisto    {{ hostvars['xsoar1'].ansible_host }}(rw,sync,no_root_squash,no_subtree_check) {{ hostvars['xsoar2'].ansible_host }}(rw,sync,no_root_squash,no_subtree_check)
                state: present
    # Restart the service on Ubuntu
        -   name: restart the nfs service on Debian
            become: yes
            service:
                name: nfs-kernel-server
                state: restarted
            when: ansible_os_family == "Debian"

    # Restart the service on Centos, Redhat
        -   name: export the nfs setting on RHEL
            become: yes
            command: exportfs -arv 
            when: ansible_os_family == "RedHat"
        -   name: restart the nfs service on RHEL
            become: yes
            service:
                name: nfs-server
                state: restarted
                enabled: yes
            when: ansible_os_family == "RedHat"
    # Add Firewalld rule on Centos, Redhat
        -   name: Set NFS rule on Firewall
            become: yes
            command: '{{ item }}'
            with_items:
                - firewall-cmd --permanent --add-service=nfs
                - firewall-cmd --permanent --add-service=rpc-bind
                - firewall-cmd --permanent --add-service=mountd
                - firewall-cmd --reload
            when: ansible_os_family == "RedHat"
EOF

cat <<EOF > es-cluster-playbook.yaml
# INSTALL ELASTIC SEARCH SERVICE ON ALL HOSTS
-   name: INSTALL ELASTIC SEARCH
    hosts: es
    tasks:
    # Install Java JRE
        -   name: Install Java JRE on Debian
            become: yes
            apt:
                name: default-jre
                state: present
                update_cache: yes
            when: ansible_os_family == "Debian"
        -   name: Install Java JRE on RedHat
            become: yes
            yum:
                name: java-11-openjdk-devel
                state: present
                update_cache: yes
            when: ansible_os_family == "RedHat"
    # [DEBIAN/UBUNTU] Prepare repo and install ES on Debian
        -   name: Download Repo key
            become: yes
            shell: wget -qO apt_key https://artifacts.elastic.co/GPG-KEY-elasticsearch
            args:
                warn: false
            when: ansible_os_family == "Debian"
        -   name: Add Repo key
            become: yes
            command: apt-key add apt_key
            when: ansible_os_family == "Debian"
        -   name: Install apt transport https
            become: yes
            apt:
                name: apt-transport-https
                state: present
            when: ansible_os_family == "Debian"
        -   name: Add ES 7 Repo
            become: yes
            shell:
                cmd: echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
            when: ansible_os_family == "Debian"
        -   name: Install ElasticSearch on Debian
            become: yes
            apt:
                name: elasticsearch
                state: present
                update_cache: yes
            when: ansible_os_family == "Debian"
    
    # [REDHAT/CENTOS] Prepare repo and install ES on RedHat
        -   name: Download Repo key
            become: yes
            shell: rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
            when: ansible_os_family == "RedHat"
        -   name: Create Repo file
            become: yes
            file:
                path: /etc/yum.repos.d/elasticsearch.repo
                state: touch
            when: ansible_os_family == "RedHat"
        -   name: Content of the Repo file
            become: yes
            lineinfile:
                path: /etc/yum.repos.d/elasticsearch.repo
                line: '{{ item }}'
                state: present
            with_items:
            - '[elasticsearch]'
            - name=Elasticsearch repository for 7.x packages
            - baseurl=https://artifacts.elastic.co/packages/7.x/yum
            - gpgcheck=1
            - gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
            - enabled=0
            - autorefresh=1
            - type=rpm-md
            when: ansible_os_family == "RedHat"
        -   name: Install ElasticSearch on RedHat
            become: yes
            yum:
                name: elasticsearch
                state: present
                enablerepo: elasticsearch
                update_cache: yes
            when: ansible_os_family == "RedHat"
        # Add Firewalld rule on Centos, Redhat
        -   name: Add Firewall rule for ES RHEL
            become: yes
            command: '{{ item }}'
            with_items:
                - firewall-cmd --permanent --add-port=9200/tcp
                - firewall-cmd --permanent --add-port=9300/tcp
                - firewall-cmd --reload
            when: ansible_os_family == "RedHat"

# SETTING IN ES CONFIGURATION FILE ON EACH HOST
-   name: SETTING FOR ELASTICSEARCH NODE 1
    hosts: es1
    tasks:
    # Configuration file settings for ES Cluster
        -   name: Set configuration file for Node 1
            become: yes
            lineinfile:
                path: /etc/elasticsearch/elasticsearch.yml
                line: '{{ item }}'
                state: present
            with_items:
                - 'cluster.name: xsoar-db'
                - 'node.name: {{ hostvars["es1"].es_node }}'
                - 'node.master: true'
                - 'node.data: true'
                - 'network.host: {{ hostvars["es1"].ansible_host }}'
                - 'http.port: 9200'
                - 'discovery.seed_hosts: ["{{ hostvars["es1"].ansible_host }}", "{{ hostvars["es2"].ansible_host }}", "{{ hostvars["es3"].ansible_host }}"]'
                - 'cluster.initial_master_nodes: ["{{ hostvars["es1"].es_node }}", "{{ hostvars["es2"].es_node }}", "{{ hostvars["es3"].es_node }}"]'

-   name: SETTING FOR ELASTICSEARCH NODE 2
    hosts: es2
    tasks:
    # Configuration file settings for ES Cluster
        -   name: Set configuration file for Node 2
            become: yes
            lineinfile:
                path: /etc/elasticsearch/elasticsearch.yml
                line: '{{ item }}'
                state: present
            with_items:
                - 'cluster.name: xsoar-db'
                - 'node.name: {{ hostvars["es2"].es_node }}'
                - 'node.master: true'
                - 'node.data: true'
                - 'network.host: {{ hostvars["es2"].ansible_host }}'
                - 'http.port: 9200'
                - 'discovery.seed_hosts: ["{{ hostvars["es1"].ansible_host }}", "{{ hostvars["es2"].ansible_host }}", "{{ hostvars["es3"].ansible_host }}"]'
                - 'cluster.initial_master_nodes: ["{{ hostvars["es1"].es_node }}", "{{ hostvars["es2"].es_node }}", "{{ hostvars["es3"].es_node }}"]'

-   name: SETTING FOR ELASTICSEARCH NODE 3
    hosts: es3
    tasks:
    # Configuration file settings for ES Cluster
        -   name: Set configuration file for Node 3
            become: yes
            lineinfile:
                path: /etc/elasticsearch/elasticsearch.yml
                line: '{{ item }}'
                state: present
            with_items:
                - 'cluster.name: xsoar-db'
                - 'node.name: {{ hostvars["es3"].es_node }}'
                - 'node.master: true'
                - 'node.data: true'
                - 'network.host: {{ hostvars["es3"].ansible_host }}'
                - 'http.port: 9200'
                - 'discovery.seed_hosts: ["{{ hostvars["es1"].ansible_host }}", "{{ hostvars["es2"].ansible_host }}", "{{ hostvars["es3"].ansible_host }}"]'
                - 'cluster.initial_master_nodes: ["{{ hostvars["es1"].es_node }}", "{{ hostvars["es2"].es_node }}", "{{ hostvars["es3"].es_node }}"]'

# START THE SERVICE
-   name: START ES CLUSTER SERVICE
    hosts: es
    tasks:
        -   name: Create ES setting folder
            become: yes
            file: 
                path: /etc/systemd/system/elasticsearch.service.d
                state: directory
        -   name: Create ES setting file
            become: yes
            file: 
                path: /etc/systemd/system/elasticsearch.service.d/startup-timeout.conf
                state: touch
        -   name: Define TimeoutStartSec
            become: yes
            lineinfile: 
                path: /etc/systemd/system/elasticsearch.service.d/startup-timeout.conf
                line: '{{ item }}'
                state: present
            with_items:
                - "[Service]"
                - TimeoutStartSec=180
        -   name: reload deamon
            become: yes
            command: systemctl daemon-reload
        -   name: Start ES Service
            become: yes
            service:
                name: elasticsearch.service
                state: started
                enabled: yes
EOF

cat <<EOF > xsoar-server-playbook.yaml
-   name: INSTALL XSOAR SERVERS
    hosts: xsoar
    tasks:
    # Install NFS client
        -   name: Install NFS client on Debian
            become: yes
            apt:
                name: nfs-common
                state: present
                update_cache: yes
            when: ansible_os_family == "Debian"
        -   name: Install NFS client on RHEL
            become: yes
            yum:
                name: nfs-utils
                state: present
                update_cache: yes
            when: ansible_os_family == "RedHat"
    # Create demisto folder to mount
        -   name: Create demisto folder
            become: yes
            command: mkdir -p /var/lib/demisto
    # Mount to NFS Server shared folder
        -   name: Mount to NFS Server
            become: yes
            command: mount {{ hostvars['nfs1'].ansible_host }}:/var/lib/demisto /var/lib/demisto
        -   name: Mount permanently
            become: yes
            lineinfile: 
                path: /etc/fstab
                line: "{{ hostvars['nfs1'].ansible_host }}:/var/lib/demisto   /var/lib/demisto    nfs defaults    0   0"
                state: present
    # Install XSOAR
        -   name: Run XSOAR installer script
            become: yes
            script:
                chdir: ~
                cmd: './{{ hostvars["xsoar1"].xsoar_installer }} --target installer -- -y -elasticsearch-url=http://{{ hostvars["es1"].ansible_host}}:9200,http://{{ hostvars["es2"].ansible_host }}:9200,http://{{ hostvars["es3"].ansible_host }}:9200'
    # Add Firewalld rule on Centos, Redhat
        -   name: Enable HTTPS on Firewall
            become: yes
            command: '{{ item }}'
            with_items:
                - firewall-cmd --permanent --add-service=https
                - firewall-cmd --reload
            when: ansible_os_family == "RedHat"
    # Check for demisto running service
        -   name: Check demisto service
            become: yes
            service:
                name: demisto
                state: started
EOF

cat <<EOF > main-playbook.yaml
- import_playbook: nfs-server-playbook.yaml
- import_playbook: es-cluster-playbook.yaml
- import_playbook: xsoar-server-playbook.yaml
EOF

# Run Ansible playbook
echo "==========================================================================="
echo " Now starting the installation process of XSOAR's system components.       "
echo " You might need to input BECOME password which is sudo password for $sshuser"
echo "==========================================================================="
sleep 5
if [ $sshsudopassword == 'y' ]
then
    ansible-playbook -i inventory.yaml main-playbook.yaml -K
else
    ansible-playbook -i inventory.yaml main-playbook.yaml
fi
fi