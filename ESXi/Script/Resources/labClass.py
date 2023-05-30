import os 
import pickle
import shutil
import random
from datetime import datetime
from Resources.samples import *
from Resources.networkClass import *
from openpyxl import load_workbook
import json



class lab:
    def __init__(self, name:str):
        self.name = name.replace(" ", "")
        self.computers = []
        self.network = network(self.name)
        self.IPcounter = 2 # Va permettre d'associer une IP unique à chaque machine

        try:
            os.mkdir("../Labs/" + self.name)
        except:
            rep = input("A lab with this name already exists, do you want to override the files ? (y/N) ")
            if rep == "y" or rep == "Y" or rep =="yes":
                shutil.rmtree("../Labs/" + self.name)
                os.mkdir("../Labs/" + self.name)
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

        os.chdir("..")
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
        os.chdir("Script")

    def cleanTfFiles(self):
        test = os.listdir("../Labs/" + self.name + '/')
        for item in test:
            if item.endswith(".tf"):
                os.remove(os.path.join("../Labs/" + self.name + '/', item))
            elif "terraform" in item:
                try:
                    os.remove(os.path.join("../Labs/" + self.name + '/', item))
                except:
                    shutil.rmtree(os.path.join("../Labs/" + self.name + '/', item))

    def runTerraform(self):
        # Lance terraform, il faut que la fonction précédente ai été exécutée
        os.chdir("../Labs/"+self.name+'/')
        os.system("terraform init")
        os.system("terraform apply -auto-approve")
        os.chdir("../../Script")

    def getDHCPIPs(self): 
        # Récupère les IPs des ordinateurs du Lab sur le réseau de management (où elles sont attribuées par DHCP), utile pour ansible
        # Si les IDs des machines posent problème, il faut modifier le "awk '{print $1}'" selon le nombre (ex :"cut -c1-3" pour 100 à 999 ou "cut -c1-5" pour 10000 à 99999)
        for ordi in self.computers:
            os.system("sleep 10")
            id = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | awk '{print $1}' | awk '{$1=$1};1'").read().replace("\n", "")
            IP = os.popen("sshpass -p " + os.getenv('password')+ " ssh -o StrictHostKeyChecking=no " + os.getenv('user') + "@" + os.getenv('ESXi') + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
            if IP == '':
                input("press enter to coninue")
                os.system("sleep 10")
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
        os.system("rm ../ansible/inventory.yml")
        fichier = open("../ansible/inventory.yml", 'a')
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
        os.system("rm ../ansible/detectionlab.yml")
        fichier = open("../ansible/detectionlab.yml", 'a')
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
            os.chdir("../ansible")
            os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 180")
            os.chdir("../Script")

    def cleanAnsibleFiles(self):
        # Supprime les fichiers que l'on vient d'ajouter car il faut éventuellement libèrer la place pour un autre lab
        for ordi in self.computers:
            for role in ordi.ansibleRoles:
                if not role in ROLES:
                    try:
                        shutil.rmtree("../ansible/roles/" + role)
                    except:
                        pass
        os.system("rm ../ansible/inventory.yml")
        os.system("rm ../ansible/detectionlab.yml")
        self.cleanGuacFiles()

    def deleteSnapshot(self):
        #Prendre une snapshot à la fin de l'installation
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.removeall "+ordi.ESXiID)

    def takeSnapshot(self):
        # Prendre une snapshot à la fin de l'installation
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break
        now =datetime.now()
        time = now.strftime("%d-%m-%Y")
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.create "+ordi.ESXiID+" AutoSnap_"+time)

    def takeSnapshotordi(self, ordiname):
        # Prendre une snapshot à la fin de l'installation
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break
        now =datetime.now()
        time = now.strftime("%d-%m-%Y")
        for ordi in self.computers:
            if ordiname == ordi.name :
                self.network.ESXiCmd("vim-cmd vmsvc/snapshot.create "+ordi.ESXiID+" AutoSnap_"+time)

    def restoreSnapshot(self):
        #Will restore the snapshot took by takeSnapshot at the end of install
        #In fact it restore the first snapshot taken
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.revert "+ordi.ESXiID+" 1 0")
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/power.on " + ordi.ESXiID)

    def save(self):
        # Save the self (lab) object so we can load it later
        with open("../Labs/"+self.name+"/pickleDump", "wb") as fichier:
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
        os.chdir("..")
        #File used by guacamole to know how to connect to each machine of the lab
        #That must be done before ansible logger run 
        os.system("rm ../Vagrant/resources/guacamole/user-mapping.xml")
        fichier = open("../Vagrant/resources/guacamole/user-mapping.xml", 'a')

        
        with open("Script/Resources/users.json") as fp:
            json_object = json.load(fp)      
        #ligne = 1
        fichier.write('<user-mapping>\n')
        for dict in json_object:
            if dict['Lab'] == self.name:
                fichier.write('    <authorize username="'+dict['ID']+'" password="'+dict['PWD']+'" encoding="md5">\n')
                for ordi in self.computers:
                    if ordi.name != self.name+"ubuntu0" :
                        importConfigFile(TYPES[ordi.getType()][1], "tmp.xml", {"computerName": ordi.name, "HostOnlyIP": ordi.IP})
                        tmp = open("tmp.xml", 'r')
                        fichier.write(tmp.read())
                        tmp.close()
                        os.system("rm tmp.xml")
                fichier.write("    </authorize>\n")
            #ligne +=1

        fichier.write("</user-mapping>")
##########################################################################################
        fichier.close()
        os.chdir("Script")

    def cleanGuacFiles(self):
        #Supprime le fichier temporaire de conf de guacamole
        os.system("rm ../tmp.xml")
        os.system("rm ../../Vagrant/resources/guacamole/user-mapping.xml")

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
        os.chdir("../Labs/"+self.name+'/')
        os.system("terraform apply -auto-approve")
        os.chdir("../../Script")

    def removeTfBaliseTag(self):
        #fonction utilisées dans la fonction précédente pour modifier les fichiers de conf terraform
        #supprimer tous les caractères entre les deux tags <balise> d'un fichier
        for ordi in self.computers:
            fichier = open("../Labs/"+self.name+"/"+ordi.name+".tf",'r')
            chaine = fichier.read()
            fichier.close()
            startIndex = chaine.find("<balise>")
            endIndex = chaine.rfind("<balise>")
            if startIndex != -1 and endIndex != -1:
                chaine = chaine[:startIndex] + chaine[endIndex:]
                fichier = open("../Labs/"+self.name+"/"+ordi.name+".tf",'w')
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
        os.chdir("..")
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
        os.chdir("Script")

       
def loadLab(name) -> lab:
    with open("../Labs/"+name+"/pickleDump", "rb") as fichier:
        l = pickle.load(fichier)
    return l

def listLabs(l=None):
    for dir in os.listdir("../Labs/"):
        try:
            if l.name == dir:
                print(" * " + dir)
            else:
                print("   " + dir)
        except:
            print("   " + dir)

def ask(question) -> bool:
    #fonction de simplification
    rep = input(question + " (y/N)").lower().replace(" ", "")
    return rep == "yes" or rep == "y" or rep == "oui" or rep == "o"


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

def lockfile() :
    if os.path.exists("../lock"):
        print("The script did not finish as expected, or someone else is using the script. Two labs cannot be either created or destroyed at the same time, doing so could result in the loss of both labs and a script failure. If you are sure to be the only one using this script, please remove the lock file. In case of a script failure, check configuration files.")
        exit(1)
    fichier = open("../lock", 'w')
    fichier.write(datetime.now().strftime("%H:%M:%S"))
    fichier.close()
