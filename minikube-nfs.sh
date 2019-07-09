#!/bin/sh

set -o errexit

# BEGIN _functions

# @info:    Prints the ascii logo
asciiLogo()
{
  echo
  echo '                           _             _                                     '
  echo '              _         _ ( )           ( )                    _   _ _____ ____'
  echo '    ___ ___  (_)  ___  (_)| |/ )  _   _ | |_      __          | \ | |  ___/ ___|'
  echo '  /  _ ` _ `\| |/  _ `\| || , <  ( ) ( )|  _`\  / __`\        |  \| | |_  \___ \'
  echo '  | ( ) ( ) || || ( ) || || |\`\ | (_) || |_) )(  ___/        | |\  |  _|  ___) |'
  echo '  (_) (_) (_)(_)(_) (_)(_)(_) (_)`\___/ (_,__/ `\____)        |_| \_|_|   |____/'
  echo
}

# @info:    Prints the usage
usage()
{
  asciiLogo

  cat <<EOF
Usage: $0 [options]

Options:

  -h, --help                Print usage
  -f, --force               Force reconfiguration of nfs
  -p, --profile             Minikube profile to use (default to 'minikube')
  -n, --nfs-config          NFS configuration to use in /etc/exports. (default to '-alldirs -mapall=\$(id -u):\$(id -g)')
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
EOF
  exit 0
}

# @info:    Prints error messages
# @args:    error-message
echoError()
{
  echo "\033[0;31mFAIL\n$1 \033[0m"
}

# @info:    Prints warning messages
# @args:    warning-message
echoWarn()
{
  echo "\033[0;33m$1 \033[0m"
}

# @info:    Prints success messages
# @args:    success-message
echoSuccess()
{
  echo "\033[0;32m$1 \033[0m"
}

# @info:    Prints check messages
# @args:    success-message
echoInfo()
{
  printf "\033[1;34m[INFO] \033[0m$1"
}

# @info:    Prints property messages
# @args:    property-message
echoProperties()
{
  echo "\t\033[0;35m- $1 \033[0m"
}

# @info:    Checks if a given property is set
# @return:  true, if variable is not set; else false
isPropertyNotSet()
{
  if [ -z ${1+x} ]; then return 0; else return 1; fi
}

# @info:    Sets the default properties
setPropDefaults()
{
  prop_profile_name="minikube"
  prop_shared_folders=()
  prop_nfs_config="-alldirs -mapall="$(id -u):$(id -g)
  prop_mount_options="noacl,async,nfsvers=3"
  prop_force_configuration_nfs=false
  prop_use_ip_range=false
}

# @info:    Parses and validates the CLI arguments
parseCli()
{
  for i in "${@}"
  do
    case $i in
      -s=*|--shared-folder=*)
      local shared_folder="${i#*=}"
      shift

      if [ ! -d "$shared_folder" ]; then
        echoError "Given shared folder '$shared_folder' does not exist!"
        exit 1
      fi

      prop_shared_folders+=("$shared_folder")
      ;;

      -p=*|--profile=*)
      prop_profile_name="${i#*=}"
      ;;

      -n=*|--nfs-config=*)
        prop_nfs_config="${i#*=}"
      ;;

      -m=*|--mount-opts=*)
        prop_mount_options="${i#*=}"
      ;;

      -f|--force)
      prop_force_configuration_nfs=true
      ;;

      -i|--use-ip-range)
      prop_use_ip_range=true
      ;;

      --ip=*)
      prop_use_ip="${i#*=}"
      ;;

      -h|--help)
      usage
      ;;

      *)
        echoError "Unknown argument '$i' given"
        usage
      ;;
    esac
  done

  if [ ${#prop_shared_folders[@]} -eq 0 ]; then
    prop_shared_folders+=("/Users")
  fi;

  echoInfo "Configuration:"

  echo #EMPTY
  echo #EMPTY

  echoProperties "Profile Name: $prop_profile_name"
  for shared_folder in "${prop_shared_folders[@]}"
  do
    echoProperties "Shared Folder: $shared_folder"
  done

  echoProperties "Mount Options: $prop_mount_options"
  echoProperties "Force: $prop_force_configuration_nfs"

  echo #EMPTY

}

# @info:    Checks if the machine is running
# @return:  (none)
checkMachineRunning()
{
  echoInfo "Checking if machine is running ... \t\t"

  # "|| true" because minikube fails with non-zero exit code which
  # makes the shell exit because we've set errexit
  machine_state=$(minikube status -p $prop_profile_name --format "{{.Host}}" || true)

  if [ "Running" != "${machine_state}" ]; then
    echoError "The machine in profile '$1' is not running!";
    exit 1;
  fi

  echoSuccess "OK"
}

# @info:    Loads mandatory properties from the machine
# @return:  (none)
lookupMandatoryProperties()
{
  echoInfo "Lookup mandatory properties ... \t\t\t"

  prop_machine_ip=$(minikube ip -p $prop_profile_name)

  prop_network_id=$(VBoxManage showvminfo $prop_profile_name --machinereadable |
    grep hostonlyadapter | cut -d'"' -f2)
  if [ "" = "${prop_network_id}" ]; then
    echoError "Could not find the virtualbox net name!"; exit 1
  fi

  prop_nfshost_ip=$(VBoxManage list hostonlyifs |
    grep "${prop_network_id}$" -A 3 | grep IPAddress |
    cut -d ':' -f2 | xargs);
  if [ "" = "${prop_nfshost_ip}" ]; then
    echoError "Could not find the virtualbox net IP!"; exit 1
  fi

  echoSuccess "OK"
}

# @info:    Configures the NFS
configureNFS()
{
  echoInfo "Configure NFS ... \n"

  if isPropertyNotSet $prop_machine_ip; then
    echoError "'prop_machine_ip' not set!"; exit 1;
  fi

  echoWarn "\n !!! Sudo will be necessary for editing /etc/exports !!!"

  # Update the /etc/exports file and restart nfsd

  local exports_begin="# minikube-nfs-begin $prop_profile_name #"
  local exports_end="# minikube-nfs-end $prop_profile_name #"

  # Remove old minikube-nfs exports
  local exports=$(cat /etc/exports | \
    tr "\n" "\r" | \
    sed "s/${exports_begin}.*${exports_end}//" | \
    tr "\r" "\n"
  )

  # Write new exports blocks beginning
  exports="${exports}\n${exports_begin}\n"

  local machine_ip=$prop_machine_ip
  if [ "$prop_use_ip_range" = true ]; then
    machine_ip="-network ${machine_ip%.*}"
  fi

  for shared_folder in "${prop_shared_folders[@]}"
  do
    # Add new exports
    exports="${exports}\"$shared_folder\" $machine_ip $prop_nfs_config\n"
  done

  # Write new exports block ending
  exports="${exports}${exports_end}"
  # Export to file
  printf "$exports" | sudo tee /etc/exports >/dev/null

  sudo nfsd restart ; sleep 2 && sudo nfsd checkexports

  echoSuccess "\t\t\t\t\t\t\tOK"
}

# @info:    Configures the machine to mount nfs
configureBoot2Docker()
{
  echoInfo "Configuring machine... \t\t\t\t"

  if isPropertyNotSet $prop_profile_name; then
    echoError "'prop_profile_name' not set!"; exit 1;
  fi
  if isPropertyNotSet $prop_nfshost_ip; then
    echoError "'prop_nfshost_ip' not set!"; exit 1;
  fi

  # render bootlocal.sh and copy bootlocal.sh over to machine
  # (this will override an existing /var/lib/boot2docker/bootlocal.sh)

  local bootlocalsh='#!/bin/sh
# Plain `umount` fails with error "... is not an NFS filesystem"
# This explains the issue and suggests using `-i` to workaround:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=799668
sudo umount -i /Users'

  for shared_folder in "${prop_shared_folders[@]}"
  do
    bootlocalsh="${bootlocalsh}
sudo mkdir -p \""$shared_folder"\""
  done

  bootlocalsh="${bootlocalsh}
sudo /usr/local/etc/init.d/nfs-client start"

  for shared_folder in "${prop_shared_folders[@]}"
  do
    bootlocalsh="${bootlocalsh}
sudo mount -t nfs -o "$prop_mount_options" "$prop_nfshost_ip":\""$shared_folder"\" \""$shared_folder"\""
  done

  local file="/var/lib/boot2docker/bootlocal.sh"

  minikube ssh -p $prop_profile_name \
    "echo '$bootlocalsh' | sudo tee $file && sudo chmod +x $file && sync" > /dev/null

  sleep 2

  echoSuccess "OK"
}

# @info:    Restarts machine
restartMachine()
{
  if isPropertyNotSet $prop_profile_name; then
    echoError "'prop_profile_name' not set!"; exit 1;
  fi

  echoInfo "Stopping machine ...\n"
  minikube stop -p $prop_profile_name
  echoSuccess "\t\t\t\t\t\t\tOK"

  echoInfo "Starting machine ...\n"
  minikube start -p $prop_profile_name
  echoSuccess "\t\t\t\t\t\t\tOK"
}

# @return:  'true', if NFS is mounted; else 'false'
isNFSMounted()
{
  for shared_folder in "${prop_shared_folders[@]}"
  do
    local nfs_mount=$(minikube ssh -p $prop_profile_name "sudo mount" |
      grep "$prop_nfshost_ip:$prop_shared_folders on")
    if [ "" = "$nfs_mount" ]; then
      echo "false";
      return;
    fi
  done

  echo "true"
}

# @info:    Verifies that NFS is successfully mounted
verifyNFSMount()
{
  echoInfo "Verify NFS mount ... \t\t\t\t"

  local attempts=10

  while [ ! $attempts -eq 0 ]; do
    sleep 1
    [ "$(isNFSMounted $prop_profile_name)" = "true" ] && break
    attempts=$(($attempts-1))
  done

  if [ $attempts -eq 0 ]; then
    echoError "Cannot detect the NFS mount :("; exit 1
  fi

  echoSuccess "OK"
}

# @info:    Displays the finish message
showFinish()
{
  echo "\033[0;36m"
  echo "--------------------------------------------"
  echo
  echo " The minikube profile '$prop_profile_name'"
  echo " is now mounted with NFS!"
  echo
  echo " ENJOY high speed mounts :D"
  echo
  echo "--------------------------------------------"
  echo "\033[0m"
}

# END _functions

setPropDefaults

parseCli "$@"

checkMachineRunning

lookupMandatoryProperties

if [ "$prop_force_configuration_nfs" = false ] && [ "$(isNFSMounted)" = "true" ]; then
    echoSuccess "\n NFS already mounted." ; showFinish ; exit 0
fi

echo #EMPTY LINE

echoProperties "Machine IP: $prop_machine_ip"
echoProperties "Network ID: $prop_network_id"
echoProperties "NFSHost IP: $prop_nfshost_ip"

echo #EMPTY LINE

configureNFS

configureBoot2Docker
restartMachine

verifyNFSMount

showFinish
