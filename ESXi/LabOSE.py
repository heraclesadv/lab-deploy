import os
import pickle
import shutil
import random
import sys
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
    def __init__(self, name, id=2, HostOnlyNetworkName=""):
        self.name = name.replace(" ", "")
        self.id = id 
        self.status = "down"
        self.computers = []
        self.HostOnlyNetworkName = HostOnlyNetworkName

        self.IPcounter = 2
    
    def addComputer(self, type, edr):
        self.computers.append(ordinateur(type+str(self.IPcounter), type, edr=edr, macAddressHostOnly=generateMacAddress(),
            macAddressLanPortGroup=generateMacAddress(), IP="192.168."+str(self.id)+"."+str(self.IPcounter),
            lab=self))
        self.IPcounter += 1

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

    def buildRole(self, nom):
        pass

    def buildAnsibleTasks(self):
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
        self.pfIP = "192.168.1.1"

    def pfSenseCmd(self, command:str):
        os.system("sshpass -p " + pfPwd + " ssh -o StrictHostKeyChecking=no " + pfUser + "@" + pfIP + " " + command)
    
    def ESXiCmd(self, command:str):
        print("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + command)
        os.system("sshpass -p " + password+ " ssh -o StrictHostKeyChecking=no " + user + "@" + ESXi + " " + command)

    def removeHostOnlyNetwork(self, lab:lab):
        pass

    def addHostOnlyNetwork(self, lab:lab):
        #Create the Host Only network for a given lab and plug the pfsense
        #https://communities.vmware.com/t5/ESXi-Discussions/Supprimer-le-NIC-d-une-VM-en-ligne-de-commande/m-p/2919769#M282917
        # si ça ne march epas on peut essayer de grep le bon network id à shutdown et garder la même technique
        # ensuite on détruit le portgroup
        # et on peut même essayer de reconfigurer la carte existante vers un autre réseau
        self.ESXiCmd('esxcli network vswitch standard portgroup add --portgroup-name='+lab.HostOnlyNetworkName+' --vswitch-name=hostOnlySwitch')
        self.ESXiCmd('vim-cmd vmsvc/devices.createnic '+str(pfVmId)+' "e1000" "'+lab.HostOnlyNetworkName+'"')

    def removeHostOnlyNetwork(self, lab:lab):
        self.ESXiCmd('vim-cmd vmsvc/device.connection '+str(pfVmId)+' 4000 0')
        self.ESXiCmd('esxcli network vswitch standard portgroup remove --portgroup-name='+lab.HostOnlyNetworkName+' --vswitch-name=hostOnlySwitch')
        
    def disconnectVMfromLPG(self, lab:lab):
        pass

    def createTfVariableFile(self, lab:lab):
        importConfigFile("terraform/variableSample.tf", 
            "Labs/" + lab.name + "/variables.tf",
            {"ESXiIP": ESXi, 
            "ESXiUser":user, 
            "ESXiPwd":password,
            "ESXiDatastore":datastore,
            "VMNetwork":VMNetwork,
            "HostOnlyNetwork":lab.HostOnlyNetworkName
            })

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

    l = lab(name, id=2, HostOnlyNetworkName="HostOnly"+str(2))
    n = network()

    l.addComputer("logger", "cybereason")
    l.addComputer("dc", "harfang")
    l.addComputer("win", "cybereason")
    l.createTfFiles()
    n.addHostOnlyNetwork(l)
    n.createTfVariableFile(l)

    shutil.copyfile("terraform/versions.tf", "Labs/" + name + "/versions.tf")
    shutil.copytree("terraform/.terraform", "Labs/" + name + "/.terraform")
    os.chdir("Labs/"+name+'/')
    os.system("terraform init")
    #os.system("terraform apply")
    os.chdir("../..")

    input("...")
    n.removeHostOnlyNetwork(l)

main()





    
