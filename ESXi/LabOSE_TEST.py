# Gestionnaire de Labs - AP

# KNOWN ISSUES:
# On ne peut pas se log sur win7 avec guacamole -> passer par la console ESXi
# on ne peut pas ajouter un supprimer un pc d'un lab
# Il faudrait ajouter la possibilité de manager un autre pc ajouté à la main
# Parfois, certain win10 ne parviennent pas à rejoindre le domaine, il suffit de rebuild le lab.
# --> erreur difficilement reproductible

# REMARQUES SUR LE CODE:
# La manière de déconnecter les cartes réseau avec terraform est radicale mais pas très propre
# --> Voir lab.removeTfBaliseTag(), lab.disconnectManagementNetwork()
# 

# AVENIR DU CODE
# Interaction utilisateur à revoir
# Portage sur une infra physique: 
# --> Devrait bien s'adapter, principal souci: interfacer les machines virtuelles avec le réseau


from datetime import datetime
import os 
import pickle
import shutil
import random
import time
from samples import *
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

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
        self.network = network(self.name)
        self.IPcounter = 2 # Va permettre d'associer une IP unique à chaque machine

        try:
            os.mkdir("Labs/" + self.name)
        except:
            rep = input("A lab with this name already exists, do you want to override the files ? (y/N) ")
            if rep == "y" or rep == "Y" or rep =="yes":
                shutil.rmtree("Labs/" + self.name)
                os.mkdir("Labs/" + self.name)
            else:
                print("Aborting...")
                exit(1)

    
    def addComputer(self, roles:str):
        # Ajoute un objet ordinateur au Lab mais ne crée pas les fichiers de conf
        self.computers.append(ordinateur(roles=roles, macAddressHostOnly=generateMacAddress(),
            macAddressLanPortGroup=generateMacAddress(), IP=self.network.IPmask+str(self.IPcounter),
            lab=self))
        self.IPcounter += 1

    def getDNSIP(self):
        # Utile pour remplir certains fichiers de configuration ansible
        for ordi in self.computers:
            for role in ordi.roles:
                if role == "createDomain":
                    return ordi.IP.replace("\n", "")
        return "8.8.8.8"

    def getOrdiWithType(self, type):
        # retourne tous les ordinateurs avec le type donné, utilisé dans createAnsible Files
        liste = []
        for ordi in self.computers:
            if ordi.getType() == type:
                liste.append(ordi)
        return liste
        

    def createTfFiles(self):
        # Crée les fichiers de configuration terraform à partir des modèles dans le dossier terraform
        # Remarque: terraform importe tous les fichiers en .tf présents dans le répertoire

        # On commence par cleaner si il y a déjà des fichiers terraform pour pas qu'ils interfèrent
        self.cleanTfFiles()
        
        # Rien à modifier sur le header:
        shutil.copyfile("terraform/header.tf", "Labs/" + self.name + "/header.tf")

        # Pour chaque ordinateur on utilise le sample correspondant:
        for ordi in self.computers:
            importConfigFile(TYPES[ordi.getType()][0], "Labs/" + self.name + '/' + ordi.name + '.tf', 
                {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})

        # On remplit le fichier de configuration:
        importConfigFile("terraform/variableSample.tf", 
            "Labs/" + self.name + "/variables.tf",
            {"ESXiIP":  os.getenv('ESXi'), 
            "ESXiUser":os.getenv('user'), 
            "ESXiPwd":os.getenv('password'),
            "ESXiDatastore": os.getenv('datastore'),
            "VMNetwork":os.getenv('VMNetwork'),
            "HostOnlyNetwork":self.network.name
            })

        # Ces fichiers n'ont pas non plus besoin de modification:
        shutil.copyfile("terraform/versions.tf", "Labs/" + self.name + "/versions.tf")
        shutil.copytree("terraform/.terraform", "Labs/" + self.name + "/.terraform")

    def cleanTfFiles(self):
        test = os.listdir("Labs/" + self.name + '/')
        for item in test:
            if item.endswith(".tf"):
                os.remove(os.path.join("Labs/" + self.name + '/', item))
            elif "terraform" in item:
                try:
                    os.remove(os.path.join("Labs/" + self.name + '/', item))
                except:
                    shutil.rmtree(os.path.join("Labs/" + self.name + '/', item))

    def runTerraform(self):
        # Lance terraform, il faut que la fonction précédente ai été exécutée
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform init")
        os.system("terraform apply -auto-approve")
        os.chdir("../..")

    def getDHCPIPs(self): 
        # Récupère les IPs des ordinateurs du Lab sur le réseau de management (où elles sont attribuées par DHCP), utile pour ansible
        # Si les IDs des machines posent problème, il faut modifier le "cut -c1-4" selon le nombre (ex :"cut -c1-3" pour 100 à 999 ou "cut -c1-5" pour 10000 à 99999)
        for ordi in self.computers:
            id = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | cut -c1-4 | awk '{$1=$1};1'").read().replace("\n", "")
            IP = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
            if IP == '':
                input("press enter to coninue")
                IP = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
                print("après attente IP:")
                print(IP)
                input("press enter to coninue")
            ordi.ESXiID = id
            ordi.dhcpIP = IP 

    def createAnsibleFiles(self):
        # Crée les fichiers de configuration ansible à partir des samples dans ansible/roles/samples et ex nihilo
        self.cleanAnsibleFiles()
        self.buildGuacamoleConfigFile()# fichier de configuration de guacamole qui est téléversé sur le logger par ansible

        # On crée ex nihilo le fichier inventory.yml
        os.system("rm ansible/inventory.yml")
        fichier = open("ansible/inventory.yml", 'a')
        self.getDHCPIPs()

        # on réunit les ordinateurs par type, car il existe un fichier group_vars par type
        for type in TYPES:
            ordis = self.getOrdiWithType(type)
            hosts= ""
            for ordi in ordis:
                hosts += "    "+ordi.dhcpIP+":\n"
            fichier.write(type + ":\n  hosts:\n" + hosts + '\n')
        fichier.close()

        # On crée ex nihilo le fichier detectionlab.yml
        os.system("rm ansible/detectionlab.yml")
        fichier = open("ansible/detectionlab.yml", 'a')
        fichier.write("---\n")
        for ordi in self.computers:
            fichier.write("- hosts: " + ordi.dhcpIP)
            fichier.write("\n  roles:\n")
            ordi.buildAnsibleTasks(self.getDNSIP()) # dans cette fonction sont crée les roles à partir des samples
            for role in ordi.ansibleRoles:
                fichier.write("    - "+ role + "\n")
            fichier.write("  tags: " + ordi.name + "\n\n")
        fichier.close()

    def runAnsible(self):
        # Lance les scripts ansible créés ordinateur par ordinateur
        for ordi in self.computers:
            os.chdir("ansible")
            os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 180")
            os.chdir("..")

    def cleanAnsibleFiles(self):
        # Supprime les fichiers que l'on vient d'ajouter car il faut éventuellement libèrer la place pour un autre lab
        for ordi in self.computers:
            for role in ordi.ansibleRoles:
                if not role in ROLES:
                    try:
                        shutil.rmtree("ansible/roles/" + role)
                    except:
                        pass
        os.system("rm ansible/inventory.yml")
        os.system("rm ansible/detectionlab.yml")
        self.cleanGuacFiles()

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
        self.test()
        chaine = ""
        chaine += "Lab name: "+ self.name + "\n"
        chaine += "\n   Name\t\t\tIP\t\t\tVM's ID\t\tState"
        for ordi in self.computers:
            chaine += "\n - " + ordi.name + "\t\t" + ordi.IP + "\t\t" + str(ordi.ESXiID) + "\t\t" + ordi.state 
        return chaine

    def buildGuacamoleConfigFile(self):
        #File used by guacamole to know how to connect to each machine of the lab
        #That must be done before ansible logger run 
        os.system("rm ../Vagrant/resources/guacamole/user-mapping.xml")
        fichier = open("../Vagrant/resources/guacamole/user-mapping.xml", 'a')
        fichier.write('<user-mapping>\n    <authorize username="lab" password="lab">\n')
        for ordi in self.computers:

            importConfigFile(TYPES[ordi.getType()][1], "tmp.xml", {"computerName": ordi.name, "HostOnlyIP": ordi.IP})
            tmp = open("tmp.xml", 'r')
            fichier.write(tmp.read())
            tmp.close()
            os.system("rm tmp.xml")

        fichier.write("    </authorize>\n</user-mapping>")
        fichier.close()

    def cleanGuacFiles(self):
        #Supprime le fichier temporaire de conf de guacamole
        os.system("rm tmp.xml")
        os.system("rm ../Vagrant/resources/guacamole/user-mapping.xml")

    def test(self):
        #Test que les machines existent et sont up
        for ordi in self.computers:
            state = os.popen("sshpass -p " + os.getenv('password') + " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/power.getstate " + str(ordi.ESXiID)).read().replace("\n", "")
            if "Powered on" in state:
                ordi.state="on"
            elif "Powered off" in state:
                ordi.state = "off"
            else:
                ordi.state = "dead"
    
    def shutdown(self):
        #éteint tous les pc du lab
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/power.shutdown "+ordi.ESXiID)

    def powerUp(self):
        #allume tous les pc du lab
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/power.on "+ordi.ESXiID)

    def disconnectVMFromManagementNetwork(self):
        # utilise terraform pour supprimer les cartes réseaux (management) des ordinateurs du lab
        # should only be run at the end of deployment, reconnection is not possible
        self.removeTfBaliseTag()
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform apply -auto-approve")
        os.chdir("../..")

    def removeTfBaliseTag(self):
        #fonction utilisées dans la fonction précédente pour modifier les fichiers de conf terraform
        #supprimer tous les caractères entre les deux tags <balise> d'un fichier
        for ordi in self.computers:
            fichier = open("Labs/"+self.name+"/"+ordi.name+".tf",'r')
            chaine = fichier.read()
            fichier.close()
            startIndex = chaine.find("<balise>")
            endIndex = chaine.rfind("<balise>")
            if startIndex != -1 and endIndex != -1:
                chaine = chaine[:startIndex] + chaine[endIndex:]
                fichier = open("Labs/"+self.name+"/"+ordi.name+".tf",'w')
                fichier.write(chaine)
                fichier.close()

    
class ordinateur:
    # Classe qui représente un ordinateur du lab
    def __init__(self,roles:str="", macAddressHostOnly="", macAddressLanPortGroup="", IP="", lab:lab=None):
        
        self.roles = roles.split(" ") 
        self.ansibleRoles = [] #filled by buildAnsibleTasks
        self.macAddressHostOnly = macAddressHostOnly
        self.macAddressLanPortGroup = macAddressLanPortGroup
        self.IP = IP #host only ip
        self.lab = lab
        self.ESXiID = 1500 # Va être changé quand il sera connu
        self.dhcpIP = "" # idem
        self.state = "dead"
        self.name = lab.name + self.getType() + str(len(self.lab.computers))

    def getType(self):
        for role in self.roles:
            if role in TYPES:
                return role
        return None

    def buildAnsibleTasks(self, dnsIP:str) -> str:
        # Choisit les rôles ansible à attribuer à chacun des ordinateurs
        for role in self.roles:
            if ROLES[role][0] == "":
                self.ansibleRoles.append(role)
            else:
                nom = self.name + role
                os.system("mkdir ansible/roles/" + nom)
                os.system("mkdir ansible/roles/"+nom+"/tasks")
                importConfigFile("ansible/roles/samples/"+ROLES[role][0], "ansible/roles/"+nom+"/tasks/main.yml", {
                    "name":self.name,
                    "HostOnlyIP": self.IP,
                    "DNSServer": dnsIP,
                    "MACAdressHostOnly": self.macAddressHostOnly.replace(":", "-"),
                    "gateway":self.lab.network.IPmask+"1",
                    "DCIP": dnsIP
                })
                self.ansibleRoles.append(nom)

class network:
    # Est lié à un lab, permet de gérer tous les aspects liés au réseau
    def __init__(self,labname:str):
        self.name = ""
        self.IPmask = ""
        self.labname=labname
        self.getHostOnlyNetwork()
    
    def ESXiCmd(self, command:str):
        # Exécute une commande sur l'ESXi, utilisée partout
        print(os.getenv('user') + "@" + os.getenv('ESXi') + " " + command)
        os.system("sshpass -p " + os.getenv('password') + " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + command)
    
    def getHostOnlyNetwork(self):
        # Chosit un des réseaux disponibles dans Networks.txt
        # pour en ajouter un il faut l'ajouter sur l'ESXi , y connecter le pfsense et configure le pare-feu de ce dernier pour donner l'accès à internet
        fichier = open("Networks.txt", 'r')
        liste = fichier.readlines()
        fichier.close()
        for i in range(len(liste)):
            opts = liste[i].split(" ")
            host_id = ''.join(filter(lambda i: i.isdigit(), opts[0]))
            lab_id = ''.join(filter(lambda i: i.isdigit(), self.labname))
            if opts[1] == "unused" and host_id == lab_id:
                liste[i] = opts[0] + " used " + opts [2]
                fichier = open("Networks.txt", 'w')
                fichier.writelines(liste)
                fichier.close()
                self.name = opts[0]
                self.IPmask = opts[2].replace("\n", "")
                return 
        print("No free HostOnly network with this number, please create or free the appropriate one")
        os.system("rm lock_test")
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

def ask(question) -> bool:
    #fonction de simplification
    rep = input(question + " (y/N)").lower().replace(" ", "")
    return rep == "yes" or rep == "y" or rep == "oui" or rep == "o"

def createLab() -> lab:

    name = input("Lab name: ").replace(" ", "")
    l = lab(name)
    l.addComputer("ubuntu guacamole")
    while True:
        c = input("add >> ")
        if c.replace(" ", "") == "":
            break
        ca = c.split(" ")
        for d in ca:
            if not d in ROLES:
                print("Role "+d+" does not exist, computer not added.")
                break
        else:
            l.addComputer(c)
            print("Computer added.")

    l.createTfFiles()

    if not ask("Files created, go ? It's the right moment to edit the terraform files !"):
        print("Aborting...")
        l.network.freeHostOnlyNetwork()
        shutil.rmtree("Labs/" + name)
        return None

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
    l.disconnectVMFromManagementNetwork()
    time.sleep(15)
    print("Taking snapshots...")
    l.takeSnapshot()
    print("Saving lab...")
    l.save()
    print("Creation over, lab created.")
    print(l)
    return l




def loadLab(name) -> lab:
    with open("Labs/"+name+"/pickleDump", "rb") as fichier:
        l = pickle.load(fichier)
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

def main():
    if os.path.exists("lock_test"):
        print("The script did not finish as expected, or someone else is using the script. Two labs cannot be either created or destroyed at the same time, doing so could result in the loss of both labs and a script failure. If you are sure to be the only one using this script, please remove the lock_test file. In case of a script failure, check configuration files.")
        exit(1)
    fichier = open("lock_test", 'w')
    fichier.write(datetime.now().strftime("%H:%M:%S"))
    fichier.close()

    print("Hello ! Welcome on labs management console !\nIt's important to exit the script properly, by typing exit.")
    while True:
        l = None
        print("No lab loaded. (create / list / load / help / exit)")
        uc = input(" >> ")
        cs = uc.split(" ")
        if len(cs) > 1:
            uc = cs[0]
        uc = uc.lower()

        if uc == "create":
            l = createLab()
        elif uc == "list":
            listLabs(l)
        elif uc == "load":
            if len(cs) > 1:
                b = cs[1]
            else:
                b = input("Please enter the name of the lab to load: ")
            try:
                print(b)
                l = loadLab(b)
            except:
                print("Failed ! Do your lab exists ? ")
        elif uc == "exit":
            os.system("rm lock_test")
            exit(0)
        elif uc == "help":
            fichier = open("help.txt", 'r')
            print(fichier.read())
            fichier.close()
        else:
            print("Command not found !")
        
        while l != None:
            print("A lab is loaded. (list, reset, destroy, add, unload, rebuild, shutdown, power, show, help, exit)")
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
                os.system("rm lock_test")
                exit(0)
            elif c == "shutdown":
                l.shutdown()
            elif c == "power":
                l.powerUp()
            elif c == "show":
                print(l)
            elif c == "help":
                fichier = open("help.txt", 'r')
                print(fichier.read())
                fichier.close()
            elif c == "rebuild":
                os.chdir("Labs/"+l.name+'/')
                os.system("terraform destroy -auto-approve")
                os.chdir("../..")
                try:
                    l.cleanAnsibleFiles()
                except:
                    pass
                print("Recreating terraform files...")
                l.createTfFiles()
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
                l.disconnectVMFromManagementNetwork()
                print("Taking snapshots...")
                l.takeSnapshot()
                print("Saving lab...")
                l.save()
                print(l)
            elif c =="add":
                
                while True:
                    c = input("add >> ")
                    if c.replace(" ", "") == "":
                        break
                    ca = c.split(" ")
                    for d in ca:
                        if not d in ROLES:
                            print("Role "+d+" does not exist, computer not added.")
                            break
                    else:
                        l.addComputer(c)
                        print("Computer added.")
                print("Recreating terraform files...")

                os.mkdir("Labs/" + l.name + '_add/')
                shutil.copyfile("terraform/header.tf", "Labs/" + l.name + "_add/header.tf")
                # Pour chaque ordinateur on utilise le sample correspondant pour les ordinateurs non existants et on le copy dans le dossier "_add":
                listNewComp = []
                for ordi in l.computers:
                    filename = 'Labs/' + l.name + '/' + ordi.name + '.tf'
                    
                    if not os.path.exists(filename) :
                        importConfigFile(TYPES[ordi.getType()][0], "Labs/" + l.name + '/' + ordi.name + '.tf', 
                            {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})
                        shutil.copyfile("Labs/" + l.name + '/' + ordi.name + '.tf', "Labs/" + l.name + '_add/' + ordi.name + '.tf')
                        listNewComp.append(ordi.name)

                # On remplit le fichier de configuration:
                importConfigFile("terraform/variableSample.tf", 
                    "Labs/" + l.name + "_add/variables.tf",
                    {"ESXiIP":  os.getenv('ESXi'), 
                    "ESXiUser":os.getenv('user'), 
                    "ESXiPwd":os.getenv('password'),
                    "ESXiDatastore": os.getenv('datastore'),
                    "VMNetwork":os.getenv('VMNetwork'),
                    "HostOnlyNetwork":l.network.name
                    })

                # Ces fichiers n'ont pas non plus besoin de modification:
                shutil.copyfile("terraform/versions.tf", "Labs/" + l.name + "_add/versions.tf")
                shutil.copytree("terraform/.terraform", "Labs/" + l.name + "_add/.terraform")

                if not ask("Files created, go ? It's the right moment to edit the terraform files !"):
                    print("Aborting...")
                    l.network.freeHostOnlyNetwork()
                    shutil.rmtree("Labs/" + l.name +"_event")
                    return None
                               
                print("Running Terraform ...")
                os.chdir("Labs/"+l.name+'_add/')
                os.system("terraform init")
                os.system("terraform apply -auto-approve")
                os.chdir("../..")
                time.sleep(15)
                print("Creating ansible files...")
                
                # Crée les fichiers de configuration ansible à partir des samples dans ansible/roles/samples et ex nihilo
                l.cleanAnsibleFiles()
                l.buildGuacamoleConfigFile()# fichier de configuration de guacamole qui est téléversé sur le logger par ansible
                # On crée ex nihilo le fichier inventory.yml
                os.system("rm ansible/inventory.yml")
                fichier = open("ansible/inventory.yml", 'a')

                for ordi in l.computers:
                    id = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | cut -c1-4 | awk '{$1=$1};1'").read().replace("\n", "")
                    IP = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
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
                os.system("rm ansible/detectionlab.yml")
                fichier = open("ansible/detectionlab.yml", 'a')
                fichier.write("---\n")
                guacaComp=l.name+"ubuntu0"
                for ordi in l.computers:
                    if ordi.name == guacaComp:
                        fichier.write("- hosts: " + ordi.dhcpIP)
                        fichier.write("\n  roles:\n")
                        ordi.buildAnsibleTasks(l.getDNSIP()) # dans cette fonction sont crée les roles à partir des samples
                        fichier.write("    - "+ "guacamoleActualise" + "\n")
                        fichier.write("  tags: " + ordi.name + "\n\n")
                    elif ordi.name in listNewComp :
                        fichier.write("- hosts: " + ordi.dhcpIP)
                        fichier.write("\n  roles:\n")
                        ordi.buildAnsibleTasks(l.getDNSIP()) # dans cette fonction sont crée les roles à partir des samples
                        for role in ordi.ansibleRoles:
                            fichier.write("    - "+ role + "\n")
                        fichier.write("  tags: " + ordi.name + "\n\n")
                fichier.close()
                input("reegarder fichier detectionlab.yml et inventory.yml")
                print("Running ansible...")
                # Lance les scripts ansible créés ordinateur par ordinateur
                for ordi in l.computers:
                    os.chdir("ansible")
                    os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 180")
                    os.chdir("..")
                time.sleep(5)
                print("Done ! Cleaning...")
                l.cleanAnsibleFiles()
                print("Disconnecting management network...")
                l.disconnectVMFromManagementNetwork()
                print("Taking snapshots...")
                l.takeSnapshot()
                print("Saving lab...")
                l.save()
                print(l)  
                shutil.rmtree("Labs/" + l.name + '_add/') 

            else:
                print("Command not found !")

if __name__ == "__main__":
    main()

