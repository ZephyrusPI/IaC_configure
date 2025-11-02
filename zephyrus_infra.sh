#!/bin/bash

#Variáveis

aws_access_key="ASIA4UGQCLHB7X7SY4EP"
aws_secret_access_key="vaFnXkRZyvUWjvaS6n1okEAq31tGfSzRPkgIC2i2"
aws_session_token="IQoJb3JpZ2luX2VjEHYaCXVzLXdlc3QtMiJIMEYCIQCYYsVK60ABp9rNwQLc7pfxgaUEPSzLSfDqeigAlsidawIhAK4cDQ3qVvmfWUjV31obwYKDJ7lWJ3jFCmUBDw3g9iZoKrkCCD8QARoMODY4MDE5NzU1NDU5IgzBAGlWmaBr8V0VniUqlgKX7ra3YCLO8AzKJnjENidQ28Ls7PbbtbbMrvNzM5/1WKkhQ4w38OO7bXcEafZt0V4B1GdDMPoyNhAwpgb+KcNv4IbNxG3p5ePbem1F7soCnAYAkitV3+tsCMysLZ0tGgUN4B7bGRHk2fwM49qJxxtgKw0MPi2dagsaKzLuefyZgUbG7utfWV3VoBbRgscj9RCL+dPQp1iAM40w7LSrN2T2Q76SxT01v01LUlEa/jNDuVtwfyKc7ezrjkbkNzANMZPaa1X+164Q3cnG8E+lQIZexndNzUuz3tvdbAZffa2LUG1zVZqVa3Swj900VAv9NirhrMuVE/oA1Ocfh0uKKyKspH8ZpkzznFr7lBQDPoJR5U4b8+Rv/DCV3ZvIBjqcAUtYYJAXO0j7oeKSOyACAbt/dYJ2KfCkzNLuip+VUxv4sKeIPYZ1okFDCj2i9sPkbMG3+2bizD5nxwkBdoR7WGDXJhD8U3Q3RaQASBqJ8AMd6t1BmrDdfXWFays55wJuU6b0AC/dcducXIzvMWxbhCmnKdTc70gXCjZBjdy7eciOUcz5jID2/1k2u6Kwo9tVUDzS02eYtVMlK2zosA=="
regiao=us-east-1
output=json
SO=ami-0360c520857e3138f


echo -e "\n+---------+Configurando aws...+---------+"

aws configure set aws_access_key_id $aws_access_key
aws configure set aws_secret_access_key $aws_secret_access_key
aws configure set aws_session_token $aws_session_token
aws configure set region $regiao
aws configure set output $output

echo -e "\n+---------+Aws configurado!+---------+"

subNet_ID=$(aws ec2 describe-subnets \
 --query "Subnets[0].[SubnetId]" \
 --output text)

echo -e "\n+---------+Criando instância+---------+"
user_data=$(cat <<COMANDOS
    #!/bin/bash
	apt update -y && apt upgrade -y
COMANDOS
)

aws ec2 run-instances \
 --image-id $SO \
 --count 1 \
 --security-group-ids sg-02dc45f81a6b3d912 \
 --instance-type t3.small \
 --subnet-id $subNet_ID\
 --key-name zephyrus-instancia \
 --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20, "VolumeType":"gp3","DeleteOnTermination":true}}]' \
 --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Zephyrus-Web-Server}]'\
 --no-cli-pager \
 --user-data "$user_data" \
 
 

echo -e "\n+---------+Instância criada!+---------+"

echo -e "\n+---------+Aguarde a instância iniciar caso queira ssh+---------+"

for i in $(seq 1 40); do printf "[%-40s]\r" "$(printf '#%.0s' $(seq 1 $i))"; sleep 6; done

Instancia_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-server-01" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo -e "\n+---------+Entrando na instância!+---------+"

ssh -i zephyrus-instancia.pem -o StrictHostKeyChecking=no ubuntu@$Instancia_IP
