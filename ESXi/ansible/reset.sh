echo "This script is going to reset the lab by using snapshots, if it fails you may want to rebuild it."

. env.sh

echo "Getting VM's IDs..."

winId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10/win10.vmx" | cut -c1-3 | awk '{$1=$1};1')
winbId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10b/win10b.vmx" | cut -c1-3 | awk '{$1=$1};1')
dcId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "dc/dc.vmx" | cut -c1-3 | awk '{$1=$1};1')
loggerId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "logger/logger.vmx" | cut -c1-3 | awk '{$1=$1};1')

echo "Logger VM id: ${loggerId}"
echo "DC VM id: ${dcId}"
echo "Win10 VM id: ${winId}"
echo "Win10b VM id: ${winbId}"

sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${winId} 1 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${winbId} 1 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${loggerId} 1 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${dcId} 1 0"

#puis il faut démarrer les machines dans le bon ordre
