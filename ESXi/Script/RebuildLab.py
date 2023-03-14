from datetime import datetime
import os 
import time
from Resources.samples import *
from Resources.labClass import *
import sys
from dotenv import load_dotenv

load_dotenv()

# Détruit tous les fichiers et recrée l'ensemble des VMs avec leurs roles
def main():
    if len(sys.argv) == 2 and (sys.argv[1] == "-h" or sys.argv[1] == "help" ):
        fichier = open("Resources/help/helpRebuildLab.txt", 'r')
        print(fichier.read())
        fichier.close()
        sys.exit()

    #le deuxième argument doit faire référence au nom du Lab mais
    #si il n'est pas renseigné celui-ci sera demandé 
    if len(sys.argv) != 2 :
        b = input("Please enter the name of the lab to rebuild: ")
    else :
        b = sys.argv[1]    
    try:
        print(b)
        l = loadLab(b)
    except:
        print("Failed ! Do your lab exists ? ")
        sys.exit()

    os.chdir("../Labs/"+l.name+'/')
    os.system("terraform destroy -auto-approve")
    os.chdir("../../Script")
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

if __name__ == "__main__":
    main()