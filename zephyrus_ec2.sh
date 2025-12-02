#!/bin/bash

#Variáveis

aws_access_key="ASIAY4PB22DEBDD2WNAX"
aws_secret_access_key="9B5ihYayBCD3UOlmox8M6NxuX07uF6riHluEmDwl"
aws_session_token="IQoJb3JpZ2luX2VjED4aCXVzLXdlc3QtMiJGMEQCIC+Y4TF4cX9uuSErbuxAqBRfyqt8J59IVpXEGEP4WAPZAiAO1h3TPB8+fBLjzNSlw1QuyQBsLs1k+RfNJNxUthFlXCq9AggHEAAaDDYxMDg5NTg0MzUyOCIMquaVPv9VPC2MSWVpKpoC6T3GOzorvF4iXWD185EvUWvsZ1vfwcC2ehswBoBqwKOi9cYqWzz5ViLjOvnDhHGmBZBiyn1o+AzP3eoHdRiywFofjZo5rMQlocfpPf3Yp8Ys/r0e2jHlI82iRAQOkLv4/Vy4V8yyhF6mFXMQFgZxpDxVqXvpLGuVbqDUHUS3H5JdXggD/Cq7q/atH7bSJIRI5AdzHXQ77O9qVNdV/+cP1DvmS1R7JWwEEi4UQruFJu8MuD3K3dLV/8x910MPdb7jGFFu7+WGg/uojQkxMH+nQo+5LDPqP7BOYGRl5wCVdwwTo1Eb1N30/MdTkwu1hCT4mzyuspG2UPSBHITO/2vA7zQo3PgCrDFmGvpKakfI5hcO8CmiVGX91gRlMO6iuMkGOp4BqUn61p8e0gQJ1fASA7p/cUZyJ5LzvJ0SSmdFXr9VamasTA27l+gcpQzklPMGoBAJVpq4+cVd9onerS3fojEZVE/z2+tcG5n1AFODEI99UxVw7Gh97gmPKSwDZRbt0D/MjBkEJECAKXX/ejTU/wtJwtqQgPIi3Zz0SHjONqSknK97j46IqP6q1iCC4hL/p83F5lqb6Stjkj91WBZE0nE="
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
		volumes:
		        - zephyrus_data:/var/lib/mysql
		        - ./ScriptZephyrusDB3.0.sql:/docker-entrypoint-initdb.d/ScriptZephyrusDB3.0.sql

volumes:
  zephyrus_data:
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
 --security-group-ids sg-0707eaabcc4f9ec3e \
 --instance-type t3.small \
 --subnet-id subnet-0029268067779be17 \
 --key-name $chavePem \
 --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20, "VolumeType":"gp3","DeleteOnTermination":true}}]' \
 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$nomeDaInstnacia}]"\
 --no-cli-pager \
 --user-data "$user_data" \



echo -e "\n+---------+Instância criada! A Zephyrus agradece sua preferencia!+---------+"

echo -e "\n+---------+Aguarde a instância iniciar caso queira ssh+---------+"

for i in $(seq 1 40); do printf "[%-40s]\r" "$(printf '#%.0s' $(seq 1 $i))"; sleep 6; done

Instancia_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$nomeDaInstnacia" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo -e "\n+---------+Entrando na instância, agora é com você!+---------+"

ssh -i $chavePem.pem -o StrictHostKeyChecking=no ubuntu@$Instancia_IP
