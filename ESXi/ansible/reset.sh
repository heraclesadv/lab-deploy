echo "This script is going to reset the lab by using snapshots, if it fails you may want to rebuild it."

. env.sh

echo "Getting VM's IDs..."

winId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10/win10.vmx" | cut -c1-3 | awk '{$1=$1};1')
winbId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10b/win10b.vmx" | cut -c1-3 | awk '{$1=$1};1')
wincId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "win10c/win10c.vmx" | cut -c1-3 | awk '{$1=$1};1')
dcId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "dc/dc.vmx" | cut -c1-3 | awk '{$1=$1};1')
loggerId=$(sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/getallvms" | grep "logger/logger.vmx" | cut -c1-3 | awk '{$1=$1};1')

echo "Logger VM id: ${loggerId}"
echo "DC VM id: ${dcId}"
echo "Win10 VM id: ${winId}"
echo "Win10b VM id: ${winbId}"
echo "Win10c VM id: ${wincId}"

sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${winId} 2 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${winbId} 2 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${wincId} 2 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${loggerId} 2 0"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/snapshot.revert ${dcId} 2 0"

echo "Machines reverted, starting them..."

sleep 5

sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/power.on ${loggerId}"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/power.on ${dcId}"
sleep 15
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/power.on ${winId}"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/power.on ${winbId}"
sshpass -p "${PSW}" ssh -o StrictHostKeyChecking=no ${USR}@${IP} "vim-cmd vmsvc/power.on ${wincId}"

