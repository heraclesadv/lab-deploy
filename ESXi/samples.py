
TYPES = {
    # [nom, fichier sample terraform, fichier sample ansible]
    "win10": ["terraform/win10Sample.tf", "../Vagrant/resources/guacamole/win10Sample.xml"],
    "dc": ["terraform/dcSample.tf", "../Vagrant/resources/guacamole/dcSample.xml"],
    "ubuntu": ["terraform/linuxSample.tf", "../Vagrant/resources/guacamole/ubuntuSample.xml"],
    "ubuntuDsk": ["terraform/ubuntuDskSample.tf", "../Vagrant/resources/guacamole/ubuntuDskSample.xml"],
    "win7": ["terraform/win7Sample.tf", "../Vagrant/resources/guacamole/win7Sample.xml"]
}

ROLES = {
    "ubuntu": ["ubuntuServerSample.yml"],
    "dc": ["dcSample.yml"],
    "win10": ["win10Sample.yml"],
    "win7": ["win7Sample.yml"],
    "ubuntuDsk": ["ubuntuDskSample.yml"],

    "joinDomain": ["joinDomainSample.yml"],
    "joinADUbuntu": ["joinADUbuntu.yml"],
    "createDomain": ["createDomainSample.yml"],

    "guacamole": [""],
    "cybereasonWin": [""],
    "sentinelOneWin": [""],
    "harfangWin": [""],
    "cybereasonUbuntu": [""],
    "sentinelOneUbuntu": [""],
    "harfangUbuntu": [""]
}