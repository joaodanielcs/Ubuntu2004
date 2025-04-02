#!/bin/bash

echo "=== Criando VM no Proxmox ==="

# Perguntar informações
read -p "Digite o ID da VM: " VMID
read -p "Digite o hostname da VM: " HOSTNAME
read -p "Iniciar no boot? (Sim/Não): " BOOT_OPTION
BOOT="0"
if [[ "$BOOT_OPTION" =~ ^[Ss]im$ ]]; then
  BOOT="1"
fi

# Listar ISOs disponíveis
ISO_DIR="/var/lib/vz/template/iso" 
echo "Arquivos ISO disponíveis:"
ISO_FILES=($(ls "$ISO_DIR"/*.iso))
for i in "${!ISO_FILES[@]}"; do
    echo "$((i+1)). $(basename "${ISO_FILES[$i]}")"
done

read -p "Escolha a ISO para instalação. Opção: " OPTION
ISO="${ISO_FILES[$((OPTION-1))]}"

echo "Locais de armazenamento disponíveis para VMs:"
echo "--------------------------------------------"

# Lista os armazenamentos compatíveis e ativos para VMs
STORAGE_OPTIONS=($(pvesm status | awk '$3 == "active" && ($2 == "dir" || $2 == "lvmthin" || $2 == "rbd") {print $1}'))

# Filtra apenas os armazenamentos com suporte a "images"
FILTERED_OPTIONS=()
for STORAGE in "${STORAGE_OPTIONS[@]}"; do
    if pvesm list "$STORAGE" | grep -q "images"; then
        FILTERED_OPTIONS+=("$STORAGE")
    fi
done

# Exibe as opções numeradas
for i in "${!FILTERED_OPTIONS[@]}"; do
    echo "$((i+1)). ${FILTERED_OPTIONS[$i]}"
done

# Lê a opção selecionada
read -p "Escolha o local do armazenamento. Opção: " OPTION

# Coloca o nome do armazenamento escolhido na variável STORAGE
STORAGE="${FILTERED_OPTIONS[$((OPTION-1))]}"

read -p "Digite o tamanho do disco em GB: " DISK_SIZE
read -p "Quantos cores a VM deve usar? " CORES
read -p "Quantidade de memória em GB: " MEMORY_GB
MEMORY=$((MEMORY_GB * 1024))

# Configurações de rede
read -p "Digite o IP/CIDR para a interface de rede (ex: 192.168.1.100/24): " IP_CIDR
read -p "Digite o gateway: " GATEWAY

# Criar a VM
echo "Criando a VM..."
qm create $VMID --name $HOSTNAME --memory $MEMORY --cores $CORES --net0 virtio,bridge=vmbr0,ip=$IP_CIDR,gw=$GATEWAY \
  --boot c --bootdisk scsi0 --onboot $BOOT --ostype l26 --agent 1 \
  --machine q35 --cpu host --numa 1 \
  --scsihw virtio-scsi-pci --scsi0 $STORAGE:$DISK_SIZE \
  --kvm 1 --bios ovmf --efidisk0 $STORAGE:1

# Adiciona o TPM com armazenamento especificado
qm set $VMID --tpmstate0 $STORAGE:4,size=4M,version=v2.0

# Adicionar ISO
echo "Adicionando a ISO..."
qm set $VMID --cdrom $ISO

# Configurações avançadas
echo "Ativando configurações avançadas..."
qm set $VMID --scsi0 $STORAGE:$DISK_SIZE,ssd=1,iothread=1,cache=writeback
qm set $VMID --balloon 0 --description "VM criada via script Bash"

echo "VM criada com sucesso!"
