cd "$(dirname "$0")"
terraform destroy -auto-approve
terraform apply -auto-approve
cd ansible
sudo bash build_ansible.sh