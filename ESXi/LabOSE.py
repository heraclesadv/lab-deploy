import os
import pickle
import shutil
import random

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
        self.computers = list(ordinateur)
        os.mkdir(self.name + "/") if not os.path.isdir(self.name + "/") else None

        self.IPcounter = 2
    
    def addComputer(self, type, edr):
        self.computers.append(ordinateur(type+str(self.IPcounter), type, edr=edr, macAddressHostOnly=generateMacAddress(),
            macAddressLanPortGroup=generateMacAddress(), IP="192.168."+str(self.id)+"."+str(self.IPcounter),
            lab=self))
        self.IPcounter += 1

    def createTfFiles(self):
        if not "LabOSE.py" in os.listdir('.'):
            print("Not in the right directory !")
            raise Exception
        test = os.listdir(lab.name + '/')
        for item in test:
            if item.endswith(".tf"):
                os.remove(os.path.join(lab.name + '/', item))
        
        shutil.copyfile("terraform/header.tf", lab.name + "/header.tf")

        for ordi in lab.computers:
            if ordi.type == 'win':
                importConfigFile("terraform/winSample.tf", lab.name + '/' + ordi.name, 
                    {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})
            elif ordi.type == 'dc':
                importConfigFile("terraform/dcSample.tf", lab.name + '/' + ordi.name, 
                    {"name": ordi.name, "MACAddressHostOnly":ordi.macAddressHostOnly, "MACAddressLanPortGroup":ordi.macAddressLanPortGroup})
            elif ordi.type == 'logger':
                importConfigFile("terraform/linuxSample.tf", lab.name + '/' + ordi.name, 
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
        self.maxAddressLanPortGroup = macAddressLanPortGroup
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


name = input("Lab name: ").replace(" ", "")
os.mkdir(name)

L = lab("Test")
L.addComputer("logger", "cybereason")
L.addComputer("dc", "harfang")
L.addComputer("win", "cybereason")
L.createTfFiles()



    
