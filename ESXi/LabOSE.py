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
    def __init__(self, name, id=2):
        self.name = name.replace(" ", "")
        self.id = id 
        self.status = "down"
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
                return ordi.IP
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
                raise Exception

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
            IP = os.popen("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + "vim-cmd vmsvc/get.guest "+id+" | grep -m 1 '"+self.network.IPmask+"' | sed 's/[^0-9+.]*//g'").read().replace("\n", "")
            ordi.ESXiID = id
            ordi.dhcpIP = IP 

    def createAnsibleFiles(self):
        os.system("rm ansible/inventory.yml")
        fichier = open("ansible/inventory.yml", 'a')
        self.getDHCPIPs()
        for ordi in self.computers:
            if ordi.type == "logger":
                fichier.write(ordi.name + ":\n  hosts:\n    "+ordi.dhcpIP+":\n      ansible_user: vagrant\n      ansible_password: vagrant\n      ansible_port: 22\n      ansible_connection: ssh\n      ansible_ssh_common_args: '-o UserKnownHostsFile=/dev/null'\n\n")
            else:
                fichier.write(ordi.name + ":\n  hosts:\n    "+ordi.dhcpIP+":")
        fichier.close()

        os.system("rm ansible/detectionlab.yml")
        fichier = open("ansible/detectionlab.yml", 'a')
        fichier.write("---\n")
        for ordi in self.computers:
            fichier.write("- hosts: " + ordi.name)
            fichier.write("\n  roles:\n")
            ordi.buildAnsibleTasks(self.getDHCPIPs())
            for role in ordi.roles:
                fichier.write("    - "+ role + "\n")
            fichier.write("  tags: " + ordi.name + "\n\n")
        fichier.close()

    def runAnsible(self):
        pass 

    def cleanAnsibleFiles():
        pass

    def destroy(self):
        os.chdir("Labs/"+self.name+'/')
        os.system("terraform destroy -auto-approve")
        os.chdir("../..")
        self.network.freeHostOnlyNetwork()
        shutil.rmtree("Labs/"+self.name)

    
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
                "MACAdressHostOnly": self.macAddressHostOnly
            })
        elif self.type == "dc":
            importConfigFile("ansible/roles/samples/dcSample.yml", "ansible/roles/"+self.name+"/tasks/main.yml", {
                "name":self.name,
                "HostOnlyIP": self.IP,
                "MACAdressHostOnly": self.macAddressHostOnly
            })
        elif self.type == "logger":
            importConfigFile("ansible/roles/samples/loggerSample.yml", "ansible/roles/"+self.name+"/tasks/main.yml", {
                "name":self.name,
                "HostOnlyIP": self.IP,
                "MACAdressHostOnly": self.macAddressHostOnly
            })
        else:
            print("Type not found:" + self.type)
            raise Exception

    def buildAnsibleTasks(self, dnsIP):
        self.buildRole(dnsIP)
        self.roles = [self.name]
        if self.type == "win":
            self.roles.append("commonWinEndpoint")
        elif self.type == "dc":
            self.roles.append("dc")
        elif self.type == "logger":
            self.roles.append("logger")

        if self.type == "win" or self.type == "dc":
            self.roles.append("common")

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
                self.IPmask = opts[2]
                return 
        print("No free HostOnly network, please create one more...")
        raise Exception

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
        raise Exception



def main():
    
    name = input("Lab name: ").replace(" ", "")

    try:
        os.mkdir("Labs/" + name)
    except:
        rep = input("A lab with this name already exists, do you want to override the files ? (Y/n)")
        if rep == "" or rep == "y" or rep == "Y" or rep =="yes":
            shutil.rmtree("Labs/" + name)
            os.mkdir("Labs/" + name)
        else:
            print("Aborting...")
            raise Exception

    l = lab(name, id=2)

    l.addComputer("logger", "cybereason")
    l.addComputer("dc", "harfang")
    l.addComputer("win", "cybereason")
    l.createTfFiles()
    l.runTerraform()
    input()
    l.createAnsibleFiles()


    l.destroy()

#main()





    
