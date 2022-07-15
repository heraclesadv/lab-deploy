echo "Hello ! This script will configure the WMs."

echo "Getting IPs from ESXi host..."
. env.sh 

winId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10/win10.vmx" | cut -c1-3 | awk '{$1=$1};1')
winbId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10b/win10b.vmx" | cut -c1-3 | awk '{$1=$1};1')
dcId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "dc/dc.vmx" | cut -c1-3 | awk '{$1=$1};1')
loggerId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "logger/logger.vmx" | cut -c1-3 | awk '{$1=$1};1')

echo "Logger VM id: ${loggerId}"
echo "DC VM id: ${dcId}"
echo "Win10 VM id: ${winId}"
echo "Win10b VM id: ${winbId}"

WIN10=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/get.guest ${winId} | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'")
DC=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/get.guest ${dcId} | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'")
LOGGER=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/get.guest ${loggerId} | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'")
WIN10B=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/get.guest ${winbId} | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'")

echo "Found ${WIN10} as win10 IP"
echo "Found ${WIN10B} as win10B IP"
echo "Found ${DC} as DC IP"
echo "Found ${LOGGER} as LOGGER IP"
echo "Done !"

echo "Creating WinRM configuration file..."
rm var.py

echo "
#Do not touch, file generated to give IPs to winrm script
WIN_IP = '${WIN10}'
WINB_IP = '${WIN10B}'
DC_IP = '${DC}'" > var.py

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
    ${WIN10}:
    
win10b:
  hosts:
    ${WIN10B}:" > inventory.yml


#peut être pb si root:
echo "Running ansible playbook on logger..."
ansible-playbook detectionlab.yml --tags "logger"

#maintenant que le logger est up, on met wazuh:
echo "Installing Wazuh on logger..."

echo "Preparing distant folder..."
sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'rm -r wazuh'
sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'mkdir wazuh'
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no wazuh-install.sh vagrant@${LOGGER}:~/wazuh/
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no config.yml vagrant@${LOGGER}:~/wazuh/

echo "Running installation scripts..."
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --uninstall'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --generate-config-files'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --wazuh-indexer logger'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --start-cluster'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --wazuh-server logger'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'cd wazuh && sudo bash wazuh-install.sh --wazuh-dashboard logger' | tee outputpwd.txt
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no outputpwd.txt vagrant@${LOGGER}:~/wazuh/

echo "Wazuh installation over, configuring windows pcs with ansible... (3 parallel tasks)"

ansible-playbook detectionlab.yml --tags "dc" &
ansible-playbook detectionlab.yml --tags "win10" &
ansible-playbook detectionlab.yml --tags "win10b" &
wait

echo "Getting Cybereason Ubuntu installer from master (apache server)..."
sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'wget "http://192.168.1.52/CybereasonLinux.deb"'
echo "Installing Cybereason Agent..."
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'sudo apt install gdb -y'
sshpass -p "vagrant" sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@${LOGGER} 'sudo dpkg -i CybereasonLinux.deb'

echo "Installing Cybereason agent on Win 10 and DC with python script..."
#On peut avoir besoin d'installer pywinrm en root
python3 winrm_script.py

echo "Disconnecting VMs from management network..."

sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${winId} 4000 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${winbId} 4000 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${loggerId} 4000 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/device.connection ${dcId} 4000 0"


#Ajouter de l'attente et ensuite prendre des snapshot
echo "Waiting a little before taking snapshots..."
sleep 30
echo "Taking snapshots..."
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.create ${winId} Initialisation"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.create ${winbId} Initialisation"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.create ${loggerId} Initialisation"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.create ${dcId} Initialisation"

echo "The script is over."