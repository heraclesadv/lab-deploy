# Gestionnaire de Labs - AP

import datetime
import os 
import pickle
import shutil
import random
import time
from env import * #le fichier env.py est à remplir selon le sample

def generateMacAddress():
    # Génère une adresse MAC aléatoirement, les risques de collision sont faibles
    return "02:00:00:%02x:%02x:%02x" % (random.randint(0, 255),
                             random.randint(0, 255),
                             random.randint(0, 255))

def importConfigFile(sampleFile:str, destFile:str, options:dict):
    # Permet de copier un sample et de remplir les champs entre < et >
    # exemple : options = {"name":"logger", "MACAddressHostOnly":"AAA", "MACAddressLanPortGroup":"BBB"}
    fichier = open(sampleFile, 'r')
    sampleText = fichier.read()
    fichier.close()

    for key in options:
        sampleText = sampleText.replace('<' + key + '>', options[key])
    
    fichier = open(destFile, 'w')
    fichier.write(sampleText)
    fichier.close()


class lab:
    def __init__(self, name:str):
        self.name = name.replace(" ", "")
        self.computers = []
        self.network = network()
        self.IPcounter = 2 # Va permettre d'associer une IP unique à chaque machine
    
    def addComputer(self, type:str, edr:str):
        # Ajoute un objet ordinateur au Lab mais ne crée pas les fichiers de conf
        self.computers.append(ordinateur(self.name+type.capitalize()+str(self.IPcounter), type, edr=edr, macAddressHostOnly=generateMacAddress(),
            macAddressLanPortGroup=generateMacAddress(), IP=self.network.IPmask+str(self.IPcounter),
            lab=self))
        self.IPcounter += 1

    def getDNSIP(self):
        # Utile pour remplir certains fichiers de configuration ansible
        for ordi in self.computers:
            if ordi.type == "dc":
                return ordi.IP.replace("\n", "")
        return "8.8.8.8"

    def createTfFiles(self):
        # Crée les fichiers de configuration terraform à partir des modèles dans le dossier terraform
        # Remarque: terraform importe tous les fichiers en .tf présents dans le répertoire

        # On commence par cleaner si il y a déjà des fichiers terraform pour pas qu'ils interfèrent
        test = os.listdir("Labs/" + self.name + '/')
        for item in test:
            if item.endswith(".tf"):
                os.remove(os.path.join("Labs/" + self.name + '/', item))
        
        # Rien à modifier sur le header:
        shutil.copyfile("terraform/header.tf", "Labs/" + self.name + "/header.tf")

        # Pour chaque ordinateur on utilise le sample correspondant:
        for ordi in self.computers:
            if ordi.type == 'win':
                importConfigFile("terraform/winSample.tf", "Labs/" + self.name + '/' + ordi.name + '.tf', 
                    {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})
            elif ordi.type == 'dc':
                importConfigFile("terraform/dcSample.tf", "Labs/" + self.name + '/' + ordi.name + '.tf', 
                    {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})
            elif ordi.type == 'logger':
                importConfigFile("terraform/linuxSample.tf", "Labs/" + self.name + '/' + ordi.name + '.tf', 
                    {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})
            else:
                print("Type not found for computer " + ordi.name)
                exit(1)

        # On remplit le fichier de configuration:
        importConfigFile("terraform/variableSample.tf", 
            "Labs/" + self.name + "/variables.tf",
            {"ESXiIP": ESXi, 
            "ESXiUser":user, 
            "ESXiPwd":password,
            "ESXiDatastore":datastore,
            "VMNetwork":VMNetwork,
            "HostOnlyNetwork":self.network.name
            })

        # Ces fichiers n'ont pas non plus besoin de modification:
        shutil.copyfile("terraform/versions.tf", "Labs/" + self.name + "/versions.tf")
        shutil.copytree("terraform/.terraform", "Labs/" + self.name + "/.terraform")

    def runTerraform(self):
        # Lance terraform, il faut que la fonction précédente ai été exécutée
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform init")
        os.system("terraform apply -auto-approve")
        os.chdir("../..")

    def getDHCPIPs(self): 
        # Récupère les IPs des ordinateurs du Lab sur le réseau de management (où elles sont attribuées par DHCP), utile pour ansible
        for ordi in self.computers:
            id = os.popen("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | cut -c1-3 | awk '{$1=$1};1'").read().replace("\n", "")
            IP = os.popen("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
            ordi.ESXiID = id
            ordi.dhcpIP = IP 

    def createAnsibleFiles(self):
        # Crée les fichiers de configuration ansible à partir des samples dans ansible/roles/samples et ex nihilo

        self.buildGuacamoleConfigFile()# fichier de configuration de guacamole qui est téléversé sur le logger par ansible

        # On crée ex nihilo le fichier inventory.yml
        os.system("rm ansible/inventory.yml")
        fichier = open("ansible/inventory.yml", 'a')
        self.getDHCPIPs()
        for ordi in self.computers:
            if ordi.type == "logger":
                fichier.write(ordi.name + ":\n  hosts:\n    "+ordi.dhcpIP+":\n      ansible_user: vagrant\n      ansible_password: vagrant\n      ansible_port: 22\n      ansible_connection: ssh\n      ansible_ssh_common_args: '-o UserKnownHostsFile=/dev/null'\n\n")
                os.system("rm resources/01-netcfg.yml")
                importConfigFile("resources/01-netcfgSample.yaml", "resources/01-netcfg.yaml", {"loggerIP":ordi.IP, "mask": self.network.IPmask}) # fichier de conf supp. pour le logger
            else:
                fichier.write(ordi.name + ":\n  hosts:\n    "+ordi.dhcpIP+":\n\n")
        fichier.close()

        # On crée ex nihilo le fichier detectionlab.yml
        os.system("rm ansible/detectionlab.yml")
        fichier = open("ansible/detectionlab.yml", 'a')
        fichier.write("---\n")
        for ordi in self.computers:
            fichier.write("- hosts: " + ordi.name)
            fichier.write("\n  roles:\n")
            ordi.buildAnsibleTasks(self.getDNSIP()) # dans cette fonction sont crée les roles à partir des samples
            for role in ordi.roles:
                fichier.write("    - "+ role + "\n")
            fichier.write("  tags: " + ordi.name + "\n\n")
        fichier.close()

    def runAnsible(self):
        # Lance les scripts ansible créés ordinateur par ordinateur
        for ordi in self.computers:
            os.chdir("ansible")
            os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 30")
            os.chdir("..")

    def cleanAnsibleFiles(self):
        # Supprime les fichier que l'on vient d'ajouter car il faut éventuellement libèrer la place pour un autre lab
        for ordi in self.computers:
            shutil.rmtree("ansible/roles/" + ordi.name)
        os.system("rm ansible/inventory.yml")
        os.system("rm ansible/detectionlab.yml")
        os.system("rm resources/01-netcfg.yaml")
        shutil.rmtree("ansible/roles/commonWinEndpoint")

    def destroy(self):
        # Détruit tous les fichiers et efface les modifications faites
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform destroy -auto-approve")
        os.chdir("../..")
        self.network.freeHostOnlyNetwork()
        shutil.rmtree("Labs/"+self.name)
        try:
            self.cleanAnsibleFiles() # Peut échouer si les fichiers n'existent pas
        except:
            pass

    def disconnectManagementNetwork(self):
        # A la fin de la construction on déconnecte le réseau de management pour segmenter
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/device.connection "+ordi.ESXiID+" 4000 0")

    def connectManagementNetwork(self):
        # Faire l'opération inverse si nécessaire (inutilisé)
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/device.connection "+ordi.ESXiID+" 4000 1")

    def takeSnapshot(self):
        # Prendre une snapshot à la fin de l'installation
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break

        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.create "+ordi.ESXiID+" AutoSnapshot")

    def restoreSnapshot(self):
        #Will restore the snapshot took by takeSnapshot at the end of install
        #In fact it restore the first snapshot taken
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.revert "+ordi.ESXiID+" 1 0")
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/power.on " + ordi.ESXiID)

    def save(self):
        # Save the self (lab) object so we can load it later
        with open("Labs/"+self.name+"/pickleDump", "wb") as fichier:
            pickle.dump(self, fichier)

    def __str__(self):
        # Used to print the lab
        chaine = ""
        chaine += "Lab name: "+ self.name
        chaine += "\n   Name\t\tIP\t\tEDR\t\tVM's ID"
        for ordi in self.computers:
            chaine += "\n - " + ordi.name + "\t\t" + ordi.IP + "\t\t" + ordi.edr + "\t\t" + str(ordi.ESXiID)
        return chaine

    def buildGuacamoleConfigFile(self):
        #File used by guacamole to know how to connect to each machine of the lab
        #That must be done before ansible logger run 
        os.system("rm ../Vagrant/resources/guacamole/user-mapping.xml")
        fichier = open("../Vagrant/resources/guacamole/user-mapping.xml", 'a')
        fichier.write('<user-mapping>\n    <authorize username="vagrant" password="vagrant">\n')
        for ordi in self.computers:
            if ordi.type == "logger":
                fichier.write('        <connection name="'+ordi.name+'">\n            <protocol>ssh</protocol>\n            <param name="hostname">'+ordi.IP+'</param>\n            <param name="port">22</param>\n            <param name="username">vagrant</param>\n            <param name="password">vagrant</param>\n        </connection>\n\n')
            elif ordi.type == "dc":
                fichier.write('        <connection name="'+ordi.name+' - Domain Admin">\n            <protocol>rdp</protocol>\n            <param name="hostname">'+ordi.IP+'</param>\n            <param name="port">3389</param>\n            <param name="username">administrator</param>\n            <param name="password">vagrant</param>\n            <param name="domain">windomain</param>\n            <param name="create-drive-path">true</param>\n            <param name="enable-drive">true</param>\n            <param name="drive-path">/etc/guacamole/shares/'+ordi.name+'</param>\n            <param name="security">nla</param>\n            <param name="ignore-cert">true</param>\n        </connection>\n\n')
            else:
                fichier.write('        <connection name="'+ordi.name+' - Domain User">\n            <protocol>rdp</protocol>\n            <param name="hostname">'+ordi.IP+'</param>\n            <param name="port">3389</param>\n            <param name="username">vagrant</param>\n            <param name="password">vagrant</param>\n            <param name="domain">windomain</param>\n            <param name="create-drive-path">true</param>\n            <param name="enable-drive">true</param>\n            <param name="drive-path">/etc/guacamole/shares/'+ordi.name+'</param>\n            <param name="security">nla</param>\n            <param name="ignore-cert">true</param>\n        </connection>\n\n')
        fichier.write("    </authorize>\n</user-mapping>")
        fichier.close()

    
class ordinateur:
    # Classe qui représente un ordinateur du lab
    def __init__(self, name:str, type:str, edr:str=None, macAddressHostOnly="", macAddressLanPortGroup="", IP="", lab:lab=None):
        self.name = name
        self.type = type # logger, dc or win
        self.edr = edr #cybereason or harfang
        self.roles =  [] #filled by buildAnsibleTasks
        self.macAddressHostOnly = macAddressHostOnly
        self.macAddressLanPortGroup = macAddressLanPortGroup
        self.IP = IP #host only ip
        self.lab = lab
        self.ESXiID = 0 # Va être changé quand il sera connu
        self.dhcpIP = "" # idem

    def buildRole(self, dnsIP:str):
        #Construit le rôle associé à la machine à partir des templates
        os.system("mkdir ansible/roles/" + self.name)
        os.system("mkdir ansible/roles/"+self.name+"/tasks")
        if self.type == "win":
            importConfigFile("ansible/roles/samples/winSample.yml", "ansible/roles/"+self.name+"/tasks/main.yml", {
                "name":self.name,
                "HostOnlyIP": self.IP,
                "DNSServer": dnsIP,
                "MACAdressHostOnly": self.macAddressHostOnly.replace(":", "-"),
                "gateway":self.lab.network.IPmask+"1"
            })
        elif self.type == "dc":
            importConfigFile("ansible/roles/samples/dcSample.yml", "ansible/roles/"+self.name+"/tasks/main.yml", {
                "name":self.name,
                "HostOnlyIP": self.IP,
                "MACAdressHostOnly": self.macAddressHostOnly.replace(":", "-"),
                "gateway":self.lab.network.IPmask+"1"
            })
            os.system("mkdir ansible/roles/commonWinEndpoint")
            os.system("mkdir ansible/roles/commonWinEndpoint/tasks")
            importConfigFile("ansible/roles/samples/commonWinEndpointSample.yml", "ansible/roles/commonWinEndpoint/tasks/main.yml", {
                "DCIP":self.IP
            }) # on en profite pour construire le rôle commun aux endpoints win, cette sépération est devenue inutile avec le temps
        elif self.type == "logger":
            importConfigFile("ansible/roles/samples/loggerSample.yml", "ansible/roles/"+self.name+"/tasks/main.yml", {
                "name":self.name,
                "HostOnlyIP": self.IP,
                "MACAdressHostOnly": self.macAddressHostOnly.replace(":", "-")
            })
        else:
            print("Type not found:" + self.type)
            exit(1)

    def buildAnsibleTasks(self, dnsIP:str):
        # Choisit les rôles ansible à attribuer à chacun des ordinateurs
        self.buildRole(dnsIP)
        self.roles = [self.name]
        if self.type == "win":
            self.roles.append("commonWinEndpoint")

        if "cybereason" in self.edr:
            self.roles.append("cybereasonWin" if self.type == "dc" or self.type == "win" else "cybereasonUbuntu")
        if "harfang" in self.edr:
            self.roles.append("harfangWin" if self.type == "dc" or self.type == "win" else "harfangUbuntu")

class network:
    # Est lié à un lab, permet de gérer tous les aspects liés au réseau
    def __init__(self):
        self.name = ""
        self.IPmask = ""
        self.getHostOnlyNetwork()
    
    def ESXiCmd(self, command:str):
        # Exécute une commande sur l'ESXi, utilisée partout
        print(user + "@" + ESXi + " " + command)
        os.system("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + command)
    
    def getHostOnlyNetwork(self):
        # Chosit un des réseaux disponibles dans Networks.txt
        # pour en ajouter un il faut l'ajouter sur l'ESXi , y connecter le pfsense et configure le pare-feu de ce dernier pour donner l'accès à internet
        fichier = open("Networks.txt", 'r')
        liste = fichier.readlines()
        fichier.close()
        for i in range(len(liste)):
            opts = liste[i].split(" ")
            if opts[1] == "unused":
                liste[i] = opts[0] + " used " + opts [2]
                fichier = open("Networks.txt", 'w')
                fichier.writelines(liste)
                fichier.close()
                self.name = opts[0]
                self.IPmask = opts[2].replace("\n", "")
                return 
        print("No free HostOnly network, please create one more...")
        exit(1)

    def freeHostOnlyNetwork(self):
        # Inverse de la fonction précédente.
        fichier = open("Networks.txt", 'r')
        liste = fichier.readlines()
        fichier.close()
        for i in range(len(liste)):
            opts = liste[i].split(" ")
            if opts[0] == self.name:
                liste[i] = opts[0] + " unused " + opts[2]
                fichier = open("Networks.txt", 'w')
                fichier.writelines(liste)
                fichier.close()
                return 
        print("Network to be freed not found !")
        exit(1)

# On passe aux fonctions qui vont exécuter les commandes de l'utilisateur

def createLab() -> lab:

    name = input("Lab name: ").replace(" ", "")

    try:
        os.mkdir("Labs/" + name)
    except:
        rep = input("A lab with this name already exists, do you want to override the files ? (y/N) ")
        if rep == "y" or rep == "Y" or rep =="yes":
            shutil.rmtree("Labs/" + name)
            os.mkdir("Labs/" + name)
        else:
            print("Aborting...")
            shutil.rmtree("Labs/" + name)
            exit(1)

    l = lab(name)

    a = "start"
    while not a in ["", "cybereason", "harfang"]:
        a = input("Which EDR for your logger ? (Cybereason, harfang, leave empty for none) ").lower()
    l.addComputer("logger", a)

    a = "start"
    while not a in ["", "cybereason", "harfang"]:
        a = input("Which EDR for your DC ? (Cybereason, harfang, leave empty for none) ").lower()
    l.addComputer("dc", a)

    while True:
        print(l)
        res = input("Do you want to add a windows pc ? (y/N)")
        if res != "y" and res != "Y" and res != "yes":
            break
        a = "start"
        while not a in ["", "cybereason", "harfang"]:
            a = input("Which EDR for your PC ? (Cybereason, harfang, leave empty for none) ").lower()
        l.addComputer("win", a)

    l.createTfFiles()
    res = input("Files created, go ? (y/N) ")
    if res != "y" and res != "Y" and res != "yes":
        print("Aborting...")
        shutil.rmtree("Labs/" + name)

        exit(1)

    print("Running Terraform ...")
    l.runTerraform()
    time.sleep(15)
    print("Creating ansible files...")
    l.createAnsibleFiles()
    print("Running ansible...")
    l.runAnsible()
    time.sleep(5)
    print("Done ! Cleaning...")
    l.cleanAnsibleFiles()
    print("Disconnecting management network...")
    l.disconnectManagementNetwork()
    print("Taking snapshots...")
    l.takeSnapshot()
    print("Saving lab...")
    l.save()
    print("Creation over, lab created:")
    print(l)
    return l

def loadLab(name) -> lab:
    with open("Labs/"+name+"/pickleDump", "rb") as fichier:
        l = pickle.load(fichier)
    print("Lab loaded:")
    print(l)
    return l

def listLabs(l=None):
    for dir in os.listdir("Labs/"):
        try:
            if l.name == dir:
                print(" * " + dir)
            else:
                print("   " + dir)
        except:
            print("   " + dir)

if os.path.exists("lock"):
    print("The script did not finish as expected, or someone else is using the script. Two labs cannot be either created or destroyed at the same time, doing so could result in the loss of both labs and a script failure. If you are sure to be the only one using this script, please remove the lock file. In case of a script failure, check configuration files.")
    raise Exception
fichier = open("lock", 'w')
fichier.write(datetime.now().strftime("%H:%M:%S"))
fichier.close()

print("Hello ! Welcome on labs management console ! ")
while True:
    l = None
    print("No lab is actually loaded, you can create one, or select an existing one.")
    print("(create / list / load / exit)")
    uc = input(" >> ").lower()

    if uc == "create":
        l = createLab()
    elif uc == "list":
        listLabs(l)
    elif uc == "load":
        b = input("Please enter the name of the lab to load: ")
        try:
            l = loadLab(b)
        except:
            print("Failed ! Do your lab exists ? ")
    elif uc == "exit":
        os.system("rm lock")
        exit(0)
    else:
        print("Command not found !")
    
    while l != None:
        print("A lab is loaded ! ")
        print(l)
        print("(list, reset, destroy, unload, rebuild, connect, disconnect, exit)")
        c = input(" >> ").lower()

        if c == "list":
            listLabs(l)
        elif c == "reset":
            l.restoreSnapshot()
        elif c == "destroy":
            print("Destroying the lab " + l.name)
            l.destroy()
            l = None 
        elif c == "unload":
            l = None
        elif c == "exit":
            os.system("rm lock")
            exit(0)
        elif c == "connect":
            l.connectManagementNetwork()
        elif c == "disconnect":
            l.disconnectManagementNetwork()
        elif c == "rebuild":
            os.chdir("Labs/"+l.name+'/')
            os.system("terraform destroy -auto-approve")
            os.chdir("../..")
            try:
                l.cleanAnsibleFiles()
            except:
                pass
            print("Running Terraform ...")
            l.runTerraform()
            time.sleep(15)
            print("Creating ansible files...")
            l.createAnsibleFiles()
            print("Running ansible...")
            l.runAnsible()
            time.sleep(5)
            print("Done ! Cleaning...")
            l.cleanAnsibleFiles()
            print("Disconnecting management network...")
            l.disconnectManagementNetwork()
            print("Taking snapshots...")
            l.takeSnapshot()
            print("Saving lab...")
            l.save()
            print("Creation over, lab created:")
            print(l)
        else:
            print("Command not found !")

