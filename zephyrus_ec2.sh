#!/bin/bash

#Variáveis

aws_access_key="ASIA4UGQCLHBXERFWXCW"
aws_secret_access_key="6JIkN6rlagX4+CY/mJrbEjaNhiD6yr+xH0PHLVp/"
aws_session_token="IQoJb3JpZ2luX2VjENL//////////wEaCXVzLXdlc3QtMiJHMEUCIE8hr70kqr6D/HhmyoO8Hzi5dZMDNFdkhjG88Yn8a+XKAiEAuLkfkxllim+yRNiGyBLaCoThiv0O4HtvIL/B5iVoE34qwgIIm///////////ARABGgw4NjgwMTk3NTU0NTkiDOKEG2Wr958n07KjLiqWApbGSz7ESWNh8s+PVm1+QBZLLum3Dflbepacj+ij/fcHpYz8E34IKcEfYmEODYZtxJ+ibMcYyjm4DgNfUcwQs3jWCOvfOS58Tv60bURjh3UweNr93xo3X2CjNHp8/Gw0XOHloqWMZN4nVJFrKg5k/PSMQnFTYYKT8/OmXOKbY+lOgbB3I9XT3hk+rtrX/9elsrhb4qY/hibmwJy5NZbKx6EhT5MEVHPtVwzWWz1rX9ySQ1pOyKcZMHOUoDISEk8o4JB/sFfrsxivyZ4c4I16E3bWwfUGAzwIKVdP02qmucXYvS/nR9P23TU64gv0VIc81CoSFO9l2Z5toe/YRjEoNUuvfwFVTK9oA9zo4vFtZhfupfr74WL6MJaHsMgGOp0BLfiC9D2zpONLh6qWoSgmdp5HzkJVP8o89aoDC4OzjVKeVoLABlTmv5h4/21SKKv2g6hdkXcpnWeyKFVAIDigRgVAdH1Z7RHBTF3tNOZQXTpnHWTv5UYIKx1J7FitYcLZitg5fCRqX6kwo99cHx09GL+3p7bzRAGHKEiBWTmiBHnkxPZWkIN3ewUmcXqtkBW2zON4bhIRGKcG7pkdaA=="
regiao=us-east-1
output=json
nomeDaInstnacia=Homologacao
chavePem=zephyrus-instancia
quantidadeInstancia=1
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

echo -e "\n+---------+Finalmente criando instância!+---------+"

user_data=$(cat <<'COMANDOS'
#!/bin/bash
apt update -y && apt upgrade -y
apt remove -y docker docker-engine docker.io containerd runc
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io
groupadd docker || true
usermod -aG docker ubuntu
cat << 'EOF' > /home/ubuntu/compose.yml
services: 
        site:
                image: gustavoalvesdeoliveira/site-zephyrus:latest
                ports:
                        - "3333:3333"
                networks:
                        - rede-zephyrus
                depends_on:
                        - db-zephyrus
        db-zephyrus:
                image: gustavoalvesdeoliveira/db-zephyrus:latest
                ports:
                        - "3306:3306"
                networks:
                        - rede-zephyrus
networks:
        rede-zephyrus:
                driver: bridge
EOF
newgrp docker
COMANDOS
)

aws ec2 run-instances \
 --image-id $SO \
 --count $quantidadeInstancia \
 --security-group-ids sg-0947aba14e6c8a6c7 \
 --instance-type t3.small \
 --subnet-id subnet-0ee2c3ba1900fcc9a \
 --key-name $chavePem \
 --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20, "VolumeType":"gp3","DeleteOnTermination":true}}]' \
 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$nomeDaInstnacia}]"\
 --no-cli-pager \
 --user-data "$user_data" \

 

echo -e "\n+---------+Instância criada! Gustavo agradece sua preferencia!+---------+"

echo -e "\n+---------+Aguarde a instância iniciar caso queira ssh+---------+"

for i in $(seq 1 40); do printf "[%-40s]\r" "$(printf '#%.0s' $(seq 1 $i))"; sleep 6; done

Instancia_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$nomeDaInstnacia" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo -e "\n+---------+Entrando na instância, agora é com você!+---------+"

ssh -i $chavePem.pem -o StrictHostKeyChecking=no ubuntu@$Instancia_IP
