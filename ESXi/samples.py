
TYPES = {
    # [nom, fichier sample terraform, fichier sample ansible]
    "win": ["terraform/winSample.tf", "ansible/roles/samples/winSample.yml", "../Vagrant/resources/guacamole/winSample.xml"],
    "dc": ["terraform/dcSample.tf", "ansible/roles/samples/dcSample.yml", "../Vagrant/resources/guacamole/dcSample.xml"],
    "logger": ["terraform/linuxSample.tf", "ansible/roles/samples/loggerSample.yml", "../Vagrant/resources/guacamole/loggerSample.xml"]
}