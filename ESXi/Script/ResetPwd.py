import os 
import time
from Resources.samples import *
from Resources.labClass import *
from Resources.Users import *
import sys
from dotenv import load_dotenv


load_dotenv()


def main():

    lockfile()

    if len(sys.argv) == 2 and (sys.argv[1] == "-h" or sys.argv[1] == "help" ):
        fichier = open("Resources/help/helpResetPwd.txt", 'r')
        print(fichier.read())
        fichier.close()
        sys.exit()

    #le deuxième argument doit faire référence au nom du Lab mais
    #si il n'est pas renseigné celui-ci sera demandé 
    if len(sys.argv) == 1 :
        b = input("Please enter the name of the lab to load: ")
    else :
        b = sys.argv[1]    
    try:
        print(b)
        l = loadLab(b)
    except:
        print("Failed ! Do your lab exists ? ")
        sys.exit()
    
    
    id = input("Please enter the user's ID : ")
    UserModifPwd(id, l.name)
    
    # Crée les fichiers de configuration ansible à partir des samples dans ansible/roles/samples et ex nihilo
    print("Creating ansible files...")
    l.cleanAnsibleFiles()
    # fichier de configuration de guacamole qui est téléversé sur le logger par ansible
    l.buildGuacamoleConfigFile()
    # On crée ex nihilo le fichier inventory.yml
    os.system("rm ../ansible/inventory.yml")
    fichier = open("../ansible/inventory.yml", 'a')
    guacaComp=l.name+"ubuntu0"
    mask = l.network.getIPmask()
    for ordi in l.computers:
        id = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | awk '{print $1}' | awk '{$1=$1};1'").read().replace("\n", "")
        IP = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '"+mask+"' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
        ordi.ESXiID = id
        ordi.dhcpIP = IP 

    # on réunit les ordinateurs par type, car il existe un fichier group_vars par type
    for type in TYPES:
        ordis = l.getOrdiWithType(type)
        hosts= ""
        for ordi in ordis:
            hosts += "    "+ordi.dhcpIP+":\n"
        fichier.write(type + ":\n  hosts:\n" + hosts + '\n')
    fichier.close()

    # On crée ex nihilo le fichier detectionlab.yml
    os.system("rm ../ansible/detectionlab.yml")
    fichier = open("../ansible/detectionlab.yml", 'a')
    fichier.write("---\n")
    
    
    for ordi in l.computers:
        if ordi.name == guacaComp:
            fichier.write("- hosts: " + ordi.dhcpIP)
            fichier.write("\n  roles:\n")
            ordi.buildAnsibleTasks(l.getDNSIP()) # dans cette fonction sont crée les roles à partir des samples
            fichier.write("    - "+ "guacamoleActualise" + "\n")
            fichier.write("  tags: " + ordi.name + "\n\n")
    fichier.close()
    print("Running ansible...")
    # Lance les scripts ansible créés ordinateur par ordinateur
    for ordi in l.computers:
        os.chdir("../ansible")
        os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 180")
        os.chdir("../Script")
    time.sleep(5)
    print("Done ! Cleaning...")
    l.cleanAnsibleFiles()
    print("Disconnecting management network...")
    l.disconnectVMFromManagementNetwork()
    print("Taking snapshots...")
    l.takeSnapshotordi(guacaComp)
    print("Saving lab...")
    l.save()
    print(l)  
    os.system("rm ../lock")

if __name__ == "__main__":
    main()