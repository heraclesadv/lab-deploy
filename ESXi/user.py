from LabOSE import *
import getpass 

def run():
    if os.path.exists("lock"):
        print("The script did not finish as expected, or someone else is using the script. Two labs cannot be either created or destroyed at the same time, doing so could result in the loss of both labs and a script failure. If you are sure to be the only one using this script, please remove the lock file. In case of a script failure, check configuration files.")
        exit(1)
    fichier = open("lock", 'w')
    fichier.write(datetime.now().strftime("%H:%M:%S"))
    fichier.close()

    print("Hello ! Welcome on the restricted lab management console !\nIt's important to exit the script properly, by typing exit.")
    while True:
        l = None
        print("No lab is actually loaded, you can create one, or select an existing one.")
        print("(list / load / exit)")
        uc = input(" >> ").lower()

        if uc == "list":
            listLabs(l)
        elif uc == "load":
            b = input("Please enter the name of the lab to load: ")
            try:
                l = loadLab(b)
            except:
                print("Failed ! Do your lab exists ? ")

            pwd = getpass.getpass("Please enter the password of the lab: ")
            if pwd != l.pwd:
                print("Wrong password !")
                l = None
            else:
                print("Successfully logged in !")
        elif uc == "exit":
            os.system("rm lock")
            exit(0)
        else:
            print("Command not found !")
        
        while l != None:
            print(l)
            print("(reset, unload, exit)")
            c = input(" >> ").lower()

            if c == "reset":
                l.restoreSnapshot()
            elif c == "unload":
                l = None
            elif c == "exit":
                os.system("rm lock")
                exit(0)
            else:
                print("Command not found !")

if __name__ == "__main__":
    run()