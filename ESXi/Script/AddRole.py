import os 
import shutil
import time
from Resources.samples import *
from Resources.labClass import *
import sys
from dotenv import load_dotenv

load_dotenv()

#Permet d'ajouter un ou plusieurs roles sur une des VMs d'un LAB

def main():

    lockfile()

    if len(sys.argv) == 2 and (sys.argv[1] == "-h" or sys.argv[1] == "help" ):
        fichier = open("Resources/help/helpAddRole.txt", 'r')
        print(fichier.read())
        fichier.close()
        sys.exit()

    #le deuxième argument doit faire référence au nom du Lab mais
    #si il n'est pas renseigné celui-ci sera demandé 
    if len(sys.argv) == 1 :
        b = input("Please enter the name of the lab >> ")
    else:
        b = sys.argv[1]
    try:
        print(b)
        l = loadLab(b)
    except:
        print("Failed ! Do your lab exists ? ")
        sys.exit()
    
    #le troisème argument doit faire référence au nom de la VM 
    #si il n'est pas renseigné celui-ci sera demandé 
    if len(sys.argv) >= 3  :
        c = sys.argv[2]
    else :
        chaine = "\n   Name"
        for ordi in l.computers:
            chaine += "\n - " + ordi.name 
        print(chaine)
        c = input("Please enter the name of the VM >> ")
    
    li =os.listdir("../Labs/" + l.name+"/")
    ca=[x.split('.')[0] for x in li]    
    notexist = True
    while notexist :
        for d in ca:
            if c == d:    
                notexist = False
        if c =="" :
            print("Aborting...")
            shutil.rmtree("../Labs/" + l.name +"_add")
            return None
        elif notexist:
            print("VM doesn't exist")
            c = input("Please enter the name of the VM >> ")
    
    #Si il y a plus de 4 arguments chaque role correspondra à un role 
    #si il n'y en a pas de renseigné ceeux-ci seront demandés 
    if len(sys.argv) > 3 :
        c2 = ""
        for rol in range(3,len(sys.argv)) :
            c2 += sys.argv[rol]
            if rol != len(sys.argv)-1 :
                c2 += " " 
    else :
        c2 = input("Please enter the name of the roles >> ")

    rolenotexit = True
    while rolenotexit :
        ca2 = c2.split(" ")
        for d in ca2:
            if not d in ROLES:
                print("Role "+d+" does not exist")
                c2 = input("Please enter the name of the roles >> ")
                break
        else:
            rolenotexit = False


    #On nettoie les fichiers
    l.cleanAnsibleFiles()

    #On crée le fichier inventory.yml
    os.system("rm ../ansible/inventory.yml")
    fichier = open("../ansible/inventory.yml", 'a')
    for ordi in l.computers:
        id = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | cut -c1-4 | awk '{$1=$1};1'").read().replace("\n", "")
        IP = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
        ordi.ESXiID = id
        ordi.dhcpIP = IP 
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
        if c in ordi.name :
            ordi.ansibleRoles = []
            fichier.write("- hosts: " + ordi.dhcpIP)
            fichier.write("\n  roles:\n")
            for role in ca2:
                if ROLES[role][0] == "":
                    ordi.ansibleRoles.append(role)
                else:
                    nom = ordi.name + role
                    os.system("mkdir ../ansible/roles/" + nom)
                    os.system("mkdir ../ansible/roles/"+nom+"/tasks")
                    importConfigFile("../ansible/roles/samples/"+ROLES[role][0], "../ansible/roles/"+nom+"/tasks/main.yml", {
                        "name":ordi.name,
                        "HostOnlyIP": ordi.IP,
                        "DNSServer": l.getDNSIP(),
                        "MACAdressHostOnly": ordi.macAddressHostOnly.replace(":", "-"),
                        "gateway":ordi.lab.network.IPmask+"1",
                        "DCIP": l.getDNSIP()
                    })
                    ordi.ansibleRoles.append(nom)
            for d in ordi.ansibleRoles:
                fichier.write("    - "+ d + "\n")
            fichier.write("  tags: " + ordi.name + "\n\n")
    fichier.close()
    
    # Lance les scripts ansible créés ordinateur par ordinateur
    print("Running ansible...")
    for ordi in l.computers:
        os.chdir("../ansible")
        os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 180")
        os.chdir("../Script")
        ordi.getType()
    time.sleep(5)
    

    l.cleanAnsibleFiles()
    print("Done ! Cleaning...")
    l.takeSnapshot()
    print("Saving lab...")
    l.save()
    os.system("rm ../lock")

if __name__ == "__main__":
    main()