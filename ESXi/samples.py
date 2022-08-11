
TYPES = {
    # [nom, fichier sample terraform, fichier sample ansible]
    "win": ["terraform/winSample.tf", "../Vagrant/resources/guacamole/winSample.xml"],
    "dc": ["terraform/dcSample.tf", "../Vagrant/resources/guacamole/dcSample.xml"],
    "ubuntu": ["terraform/linuxSample.tf", "../Vagrant/resources/guacamole/ubuntuSample.xml"],
    "ubuntuDsk": ["terraform/ubuntuDskSample.tf", "../Vagrant/resources/guacamole/ubuntuDskSample.xml"]
}

ROLES = {
    "ubuntu": ["ubuntuServerSample.yml"],
    "dc": ["dcSample.yml"],
    "win": ["winSample.yml"],
    "ubuntuDsk": ["ubuntuDskSample.yml"],

    "joinDomain": ["joinDomainSample.yml"],
    "createDomain": ["createDomainSample.yml"],

    "guacamole": [""],
    "cybereasonWin": [""],
    "sentinelOneWin": [""],
    "harfangWin": [""],
    "cybereasonUbuntu": [""],
    "sentinelOneUbuntu": [""],
    "harfangUbuntu": [""]
}