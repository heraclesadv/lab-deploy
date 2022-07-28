import os
import pickle
import shutil
import random
import time
from env import *

def generateMacAddress():
    return "02:00:00:%02x:%02x:%02x" % (random.randint(0, 255),
                             random.randint(0, 255),
                             random.randint(0, 255))

def importConfigFile(sampleFile:str, destFile:str, options:dict):
    #options = {"name":"logger", "MACAddressHostOnly":"AAA", "MACAddressLanPortGroup":"BBB"}
    fichier = open(sampleFile, 'r')
    sampleText = fichier.read()
    fichier.close()

    for key in options:
        sampleText = sampleText.replace('<' + key + '>', options[key])
    
    fichier = open(destFile, 'w')
    fichier.write(sampleText)
    fichier.close()


class lab:
    def __init__(self, name):
        self.name = name.replace(" ", "")
        self.computers = []
        self.network = network()
        self.IPcounter = 2
    
    def addComputer(self, type, edr):
        self.computers.append(ordinateur(type+str(self.IPcounter), type, edr=edr, macAddressHostOnly=generateMacAddress(),
            macAddressLanPortGroup=generateMacAddress(), IP=self.network.IPmask+str(self.IPcounter),
            lab=self))
        self.IPcounter += 1

    def getDNSIP(self):
        for ordi in self.computers:
            if ordi.type == "dc":
                return ordi.IP.replace("\n", "")
        return "8.8.8.8"

    def createTfFiles(self):
        test = os.listdir("Labs/" + self.name + '/')
        for item in test:
            if item.endswith(".tf"):
                os.remove(os.path.join("Labs/" + self.name + '/', item))
        
        shutil.copyfile("terraform/header.tf", "Labs/" + self.name + "/header.tf")

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

        importConfigFile("terraform/variableSample.tf", 
            "Labs/" + self.name + "/variables.tf",
            {"ESXiIP": ESXi, 
            "ESXiUser":user, 
            "ESXiPwd":password,
            "ESXiDatastore":datastore,
            "VMNetwork":VMNetwork,
            "HostOnlyNetwork":self.network.name
            })

        shutil.copyfile("terraform/versions.tf", "Labs/" + self.name + "/versions.tf")
        shutil.copytree("terraform/.terraform", "Labs/" + self.name + "/.terraform")

    def runTerraform(self):
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform init")
        os.system("terraform apply -auto-approve")
        os.chdir("../..")

    def getDHCPIPs(self): 
        for ordi in self.computers:
            id = os.popen("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + "vim-cmd vmsvc/getallvms | grep \"" + ordi.name + "/" + ordi.name + ".vmx\" | cut -c1-3 | awk '{$1=$1};1'").read().replace("\n", "")
            IP = os.popen("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '192.168.1.' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
            ordi.ESXiID = id
            ordi.dhcpIP = IP 

    def createAnsibleFiles(self):
        self.buildGuacamoleConfigFile()
        os.system("rm ansible/inventory.yml")
        fichier = open("ansible/inventory.yml", 'a')
        self.getDHCPIPs()
        for ordi in self.computers:
            if ordi.type == "logger":
                fichier.write(ordi.name + ":\n  hosts:\n    "+ordi.dhcpIP+":\n      ansible_user: vagrant\n      ansible_password: vagrant\n      ansible_port: 22\n      ansible_connection: ssh\n      ansible_ssh_common_args: '-o UserKnownHostsFile=/dev/null'\n\n")
                os.system("rm resources/01-netcfg.yml")
                importConfigFile("resources/01-netcfgSample.yaml", "resources/01-netcfg.yaml", {"loggerIP":ordi.IP})
            else:
                fichier.write(ordi.name + ":\n  hosts:\n    "+ordi.dhcpIP+":\n\n")
        fichier.close()

        os.system("rm ansible/detectionlab.yml")
        fichier = open("ansible/detectionlab.yml", 'a')
        fichier.write("---\n")
        for ordi in self.computers:
            fichier.write("- hosts: " + ordi.name)
            fichier.write("\n  roles:\n")
            ordi.buildAnsibleTasks(self.getDNSIP())
            for role in ordi.roles:
                fichier.write("    - "+ role + "\n")
            fichier.write("  tags: " + ordi.name + "\n\n")
        fichier.close()

    def runAnsible(self):
        for ordi in self.computers:
            os.chdir("ansible")
            os.system("ansible-playbook detectionlab.yml --tags \""+ordi.name+"\" --timeout 30")
            os.chdir("..")

    def cleanAnsibleFiles(self):
        for ordi in self.computers:
            shutil.rmtree("ansible/roles/" + ordi.name)
        os.system("rm ansible/inventory.yml")
        os.system("rm ansible/detectionlab.yml")
        os.system("rm resources/01-netcfg.yaml")
        shutil.rmtree("ansible/roles/commonWinEndpoint")

    def destroy(self):
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform destroy -auto-approve")
        os.chdir("../..")
        self.network.freeHostOnlyNetwork()
        shutil.rmtree("Labs/"+self.name)
        try:
            self.cleanAnsibleFiles()
        except:
            pass

    def disconnectManagementNetwork(self):
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/device.connection "+ordi.ESXiID+" 4000 0")

    def connectManagementNetwork(self):
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/device.connection "+ordi.ESXiID+" 4000 1")

    def takeSnapshot(self):
        for ordi in self.computers:
            if ordi.ESXiID == 0:
                self.getDHCPIPs()
                break

        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.create "+ordi.ESXiID+" InstallationOver")

    def restoreSnapshot(self):
        #Will restore the snapshot took by takeSnapshot at the end of install
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/snapshot.revert "+ordi.ESXiID+" 1 0")
        for ordi in self.computers:
            self.network.ESXiCmd("vim-cmd vmsvc/power.on " + ordi.ESXiID)

    def save(self):
        with open("Labs/"+self.name+"/pickleDump", "wb") as fichier:
            pickle.dump(self, fichier)

    def __str__(self):
        chaine = ""
        chaine += "Lab name: "+ self.name
        chaine += "\n   Name\t\tIP\t\tEDR\t\tVM's ID"
        for ordi in self.computers:
            chaine += "\n - " + ordi.name + "\t\t" + ordi.IP + "\t\t" + ordi.edr + "\t\t" + str(ordi.ESXiID)
        return chaine

    def buildGuacamoleConfigFile(self):
        pass
        #That must be done before ansible logger run 
        # YET TO BE DONE
        # autre chose à faire: copier le HAProxy qui pointe vers .2. pour en faire un qui pointe vers chaque lab
        # 

    
class ordinateur:
    def __init__(self, name:str, type:str, edr:str=None, macAddressHostOnly="", macAddressLanPortGroup="", IP="", lab:lab=None):
        self.name = name
        self.type = type # logger, dc or win
        self.edr = edr #cybereason or harfang
        self.roles =  [] #filled by buildAnsibleTasks
        self.macAddressHostOnly = macAddressHostOnly
        self.macAddressLanPortGroup = macAddressLanPortGroup
        self.IP = IP #host only ip
        self.lab = lab
        self.ESXiID = 0
        self.dhcpIP = ""

    def buildRole(self, dnsIP):
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
            })
        elif self.type == "logger":
            importConfigFile("ansible/roles/samples/loggerSample.yml", "ansible/roles/"+self.name+"/tasks/main.yml", {
                "name":self.name,
                "HostOnlyIP": self.IP,
                "MACAdressHostOnly": self.macAddressHostOnly.replace(":", "-")
            })
        else:
            print("Type not found:" + self.type)
            exit(1)

    def buildAnsibleTasks(self, dnsIP):
        self.buildRole(dnsIP)
        self.roles = [self.name]
        if self.type == "win":
            self.roles.append("commonWinEndpoint")

        if "cybereason" in self.edr:
            self.roles.append("cybereasonWin" if self.type == "dc" or self.type == "win" else "cybereasonUbuntu")
        if "harfang" in self.edr:
            self.roles.append("harfangWin" if self.type == "dc" or self.type == "win" else "harfangUbuntu")

class network:
    def __init__(self):
        self.name = ""
        self.IPmask = ""
        self.getHostOnlyNetwork()
    
    def ESXiCmd(self, command:str):
        print("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + command)
        os.system("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + command)
    
    def getHostOnlyNetwork(self):
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

print("Hello ! Welcome on labs management console ! ")
while True:
    l = None
    print("No lab is actually loaded, you can create one, or select an existing one.")
    print("(create / list / load )")
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
    else:
        print("Command not found !")
    
    while l != None:
        print("A lab is loaded ! ")
        print(l)
        print("(list, reset, destroy, unload, rebuild)")
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
        elif c == "rebuild":
            os.chdir("Labs/"+l.name+'/')
            os.system("terraform destroy -auto-approve")
            os.chdir("../..")
            l.cleanAnsibleFiles()
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
            print("Taking snapshots...")
            l.takeSnapshot()
            print("Saving lab...")
            l.save()
            print("Creation over, lab created:")
            print(l)
        else:
            print("Command not found !")

