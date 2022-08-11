
TYPES = {
    # [nom, fichier sample terraform, fichier sample ansible]
    "win": ["terraform/winSample.tf", "../Vagrant/resources/guacamole/winSample.xml"],
    "dc": ["terraform/dcSample.tf", "../Vagrant/resources/guacamole/dcSample.xml"],
    "logger": ["terraform/linuxSample.tf", "../Vagrant/resources/guacamole/loggerSample.xml"]
}

ROLES = {
    "logger": ["loggerSample.yml"],
    "dc": ["dcSample.yml"],
    "win": ["winSample.yml"],

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