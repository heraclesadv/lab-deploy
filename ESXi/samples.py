# les types sont des roles particulier: ils définissent le type d'ordinateur

TYPES = {
    # [nom, fichier sample terraform, fichier sample ansible]
    "win10": ["terraform/win10Sample.tf", "../Vagrant/resources/guacamole/win10Sample.xml"],
    "dc": ["terraform/dcSample.tf", "../Vagrant/resources/guacamole/dcSample.xml"],
    "winser2016": ["terraform/winser2016Sample.tf", "../Vagrant/resources/guacamole/winser2016Sample.xml"],
    "ubuntu": ["terraform/linuxSample.tf", "../Vagrant/resources/guacamole/ubuntuSample.xml"],
    "ubuntuDsk": ["terraform/ubuntuDskSample.tf", "../Vagrant/resources/guacamole/ubuntuDskSample.xml"],
    "win7": ["terraform/win7Sample.tf", "../Vagrant/resources/guacamole/win7Sample.xml"],
    "kali": ["terraform/kaliSample.tf", "../Vagrant/resources/guacamole/kaliSample.xml"],
    "remnux": ["terraform/remnuxSample.tf", "../Vagrant/resources/guacamole/remnuxSample.xml"],
    "centos7": ["terraform/centos7.tf", "../Vagrant/resources/guacamole/centos7Sample.xml"],
}

ROLES = {# chaque role correspond à une fonctionnalité

    #On retrouve les types
    "ubuntu": ["ubuntuServerSample.yml"],
    "dc": ["dcSample.yml"],
    "winser2016": ["winser2016Sample.yml"],
    "win10": ["win10Sample.yml"],
    "win7": ["win7Sample.yml"],
    "ubuntuDsk": ["ubuntuDskSample.yml"],
    "kali": ["kaliSample.yml"],
    "remnux": ["remnuxSample.yml"],
    "centos7": ["centos7Sample.yml"],

    # Fonctionnalités liées à l'AD
    "joinDomain": ["joinDomainSample.yml"],
    "joinADUbuntu": ["joinADUbuntu.yml"],
    "createDomain": ["createDomainSample.yml"],
    "honeyaccount": [""],
    "badblood": [""],

    # Fonctionnalités
    "guacamole": [""],
    "cybereasonWin": [""],
    "sentinelOneWin": [""],
    "harfangWin": [""],
    "cybereasonUbuntu": [""],
    "sentinelOneUbuntu": [""],
    "harfangUbuntu": [""],
    "guacamoleActualise": [""],
    "vs2019Win": [""],
    "cyberChefWin": [""],
    "cyberChefLinux": [""],
    "vsCodeLinux": [""],
    "vsCodeWin": [""],
    "notepadWin": [""],
    "processExpWin": [""]
}