# Gestionnaire de Labs - AP

# KNOWN ISSUES:
# on ne peut pas supprimer un pc d'un lab (hormis manuellement depuis ESXI)
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


import os 
from Resources.samples import *
from dotenv import load_dotenv
from pathlib import Path
from Resources.labClass import *


load_dotenv()

# On passe aux fonctions qui vont exécuter les commandes de l'utilisateur
def main():


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
            os.system("python3 CreateLab.py")
        
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
            exit(0)
        elif uc == "help":
            fichier = open("Resources/help/help.txt", 'r')
            print(fichier.read())
            fichier.close()
        else:
            print("Command not found !")
        
        while l != None:
            print("A lab is loaded. (list, reset, removesnap, destroy, add, addrole,addusers, unload, rebuild, shutdown, power, show, help, exit)")
            c = input(" >> ").lower()

            if c == "list":
                listLabs(l)
            elif c == "removesnap":
                l.deleteSnapshot()
                l.takeSnapshot()
            elif c == "reset":
                l.restoreSnapshot()
            elif c == "destroy":
                print("Destroying the lab " + l.name)
                os.system("python3 DestroyLab.py "+ l.name)
                l = None 
            elif c == "unload":
                l = None
            elif c == "exit":
                exit(0)
            elif c == "shutdown":
                l.shutdown()
            elif c == "power":
                l.powerUp()
            elif c == "show":
                print(l)
            elif c == "help":
                fichier = open("Resources/help.txt", 'r')
                print(fichier.read())
                fichier.close()
            elif c == "rebuild":
                os.system("python3 RebuildLab.py "+ l.name)
            elif c =="add":
                os.system("python3 AddVm.py "+ l.name) 
            elif c == "addrole":
                os.system("python3 AddRole.py "+ l.name)
            elif c == "addusers":
                os.system("python3 AddUsers.py "+ l.name)
            else:
                print("Command not found !")

if __name__ == "__main__":
    main()

