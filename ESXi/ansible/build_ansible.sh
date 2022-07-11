echo "Hello ! This script will configure the WMs."
echo "Guessing Logger IP, this may take a while."

. env.sh 

LOGGER=""

for i in $(seq 130 254)
do 
  result=$(sudo nmap -O 192.168.1.$i | grep ssh)
  if (( ${#result} > 2 )) 
  then
    LOGGER="192.168.1.${i}"
    REP=$(sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -q vagrant@${LOGGER} 'sudo hostname')
    echo $REP
    if [[ "vagrant" == "${REP}" ]]; then 
      echo "Found logger ip: ${LOGGER}"
      break
    fi 
    echo "Found Linux IP, but that's not the logger: ${LOGGER}" 
  fi
done

#A FAIRE : trouver ip plus serieusement, après rebuild du midi , destroy et apply terraform pour test

winId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10/win10.vmx" | cut -c1-3 | awk '{$1=$1};1')
dcId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "dc/dc.vmx" | cut -c1-3 | awk '{$1=$1};1')
loggerId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "logger/logger.vmx" | cut -c1-3 | awk '{$1=$1};1')

WIN10=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/get.guest ${winId} | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'")
DC=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/get.guest ${dcId} | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'")

echo "Found ${WIN10} as win10 IP"
echo "Found ${DC} as DC IP"

###
echo "Creating configuration files ..."

rm inventory.yml

echo "logger:
  hosts:
    ${LOGGER}:
      ansible_user: vagrant
      ansible_password: vagrant
      ansible_port: 22
      ansible_connection: ssh
      ansible_ssh_common_args: '-o UserKnownHostsFile=/dev/null'

dc:
  hosts:
    ${DC}:

win10:
  hosts:
    ${WIN10}:" > inventory.yml
echo "Done !"


#peut être pb si root:
echo "Running ansible playbook on logger..."
ansible-playbook detectionlab.yml --tags "logger"
echo "Done !"

#maintenant que le logger est up, on met wazuh:
echo "Installing Wazuh on logger..."

echo "Preparing distant folder..."
sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'rm -r wazuh'
sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'mkdir wazuh'
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no wazuh-install.sh vagrant@${LOGGER}:~/wazuh/
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no config.yml vagrant@${LOGGER}:~/wazuh/
echo "Done !"

echo "Running installation scripts..."
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --uninstall'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --generate-config-files'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --wazuh-indexer logger'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --start-cluster'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --wazuh-server logger'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --wazuh-dashboard logger' | tee outputpwd.txt
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no outputpwd.txt vagrant@${LOGGER}:~/wazuh/

#on a fini 
echo "Done !"
echo "Wazuh installation over, configuring windows pcs with ansible..."

ansible-playbook detectionlab.yml --tags "dc" 
ansible-playbook detectionlab.yml --tags "win10"
echo "Done !"

echo "Getting Cybereason Ubuntu installer from master (apache server)..."
##WORK HERE



echo "Disconnecting VMs from management network..."

echo "Logger VM id: ${loggerId}"
echo "DC VM id: ${dcId}"
echo "Win10 VM id: ${winId}"

sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${winId} 4000 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${loggerId} 4000 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${dcId} 4000 0"
echo "Done"

echo "The script is over."


