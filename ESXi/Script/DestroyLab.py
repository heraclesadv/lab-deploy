
import shutil
import os
from Resources.labClass import *
from Resources.Users import *
import sys


# Détruit tous les fichiers et efface les modifications faites
def main():
    
    lockfile()

    if len(sys.argv) == 2 and (sys.argv[1] == "-h" or sys.argv[1] == "help" ):
        fichier = open("Resources/help/helpDestroyLab.txt", 'r')
        print(fichier.read())
        fichier.close()
        sys.exit()

    #le deuxième argument doit faire référence au nom du Lab mais
    #si il n'est pas renseigné celui-ci sera demandé 
    if len(sys.argv) != 2 :
        b = input("Please enter the name of the lab to destroy: ")
    else :
        b = sys.argv[1]    
    try:
        
        print(b)
        l = loadLab(b)

        os.chdir("../Labs/"+l.name+'/')
        os.system("terraform destroy -auto-approve")
        os.chdir("../../Script")
        l.network.freeHostOnlyNetwork()
        shutil.rmtree("../Labs/"+l.name)
        deleteAllUsersLab(l.name)
        try:
            l.cleanAnsibleFiles()
            
        except:
            pass
    except:
        print("Failed ! Do your lab exists ? ")
    os.system("rm ../lock")
    
    
    
   

if __name__ == "__main__":
    main()