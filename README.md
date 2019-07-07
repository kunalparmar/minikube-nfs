# Minikube NFS

Activates [NFS](https://en.wikipedia.org/wiki/Network_File_System) for an
existing boot2docker box created through
[Minikube](https://github.com/kubernetes/minikube).

## Requirements

* Mac OS X 10.9+
* [Minikube](https://github.com/kubernetes/minikube) 1.2.0+

## Install

### [Homebrew](http://brew.sh/)

```sh
brew install minikube-nfs
```

### Standalone

```sh
curl -s https://raw.githubusercontent.com/kunalparmar/minikube-nfs/master/minikube-nfs.sh |
  tee /usr/local/bin/minikube-nfs > /dev/null && \
  chmod +x /usr/local/bin/minikube-nfs
```


## Supports

* Virtualbox

## Usage

```sh


                       ##         .
                 ## ## ##        ==               _   _ _____ ____
              ## ## ## ## ##    ===              | \ | |  ___/ ___|
          /"""""""""""""""""\___/ ===            |  \| | |_  \___ \
     ~~~ {~~ ~~~~ ~~~ ~~~~ ~~~ ~ /  ===- ~~~     | |\  |  _|  ___) |
          \______ o           __/                |_| \_|_|   |____/
            \    \         __/
             \____\_______/


Usage: $ minikube-nfs [options]

Options:

  -f, --force               Force reconfiguration of nfs
  -p, --profile             Minikube profile to use (default to 'minikube')
  -n, --nfs-config          NFS configuration to use in /etc/exports. (default to '-alldirs -mapall=$(id -u):$(id -g)')
  -s, --shared-folder,...   Folder to share (default to /Users)
  -m, --mount-opts          NFS mount options (default to 'noacl,async,nfsvers=3')
  -i, --use-ip-range        Changes the nfs export ip to a range (e.g. -network 192.168.99.100 becomes -network 192.168.99)
      --ip                  Configures the minikube machine to connect to your host machine via a specific ip address

Examples:

  $ minikube-nfs

    > Configure the /Users folder with NFS

  $ minikube-nfs test

    > Configure the /Users folder with NFS in minikube profile named "test"

  $ minikube-nfs --shared-folder=/Users --shared-folder=/var/www

    > Configures the /Users and /var/www folder with NFS

  $ minikube-nfs --shared-folder=/var/www --nfs-config="-alldirs -maproot=0"

    > Configure the /var/www folder with NFS and the options '-alldirs -maproot=0'

  $ minikube-nfs --mount-opts="noacl,async,nolock,vers=3,udp,noatime,actimeo=1"

    > Configure the /User folder with NFS and specific mount options.

  $ minikube-nfs --ip 192.168.1.12

    > minikube machine will connect to your host machine via this address
```

## Credits

Heavily inspired by [docker-machine-nfs](https://github.com/adlogix/docker-machine-nfs).
