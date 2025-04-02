#!/bin/bash

echo "=== Criando VM no Proxmox ==="

# Perguntar informações
read -p "Digite o ID da VM: " VMID
read -p "Digite o nome do node onde a VM será criada: " NODE
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

read -p "Escolha a ISO para instalação: " OPTION
ISO="${ISO_FILES[$((OPTION-1))]}"

# Configurações do disco
read -p "Escolha o storage para 'TPM Storage' (e disco): " STORAGE
read -p "Digite o tamanho do disco em GB: " DISK_SIZE
read -p "Quantos cores a VM deve usar? " CORES
read -p "Quantidade de memória em GB (será convertida para MB): " MEMORY_GB
MEMORY=$((MEMORY_GB * 1024))

# Configurações de rede
read -p "Digite o IP/CIDR para a interface de rede (ex: 192.168.1.100/24): " IP_CIDR
read -p "Digite o gateway: " GATEWAY

# Criar a VM
echo "Criando a VM..."
qm create $VMID --name $HOSTNAME --node $NODE --memory $MEMORY --cores $CORES --net0 virtio,bridge=vmbr0,ip=$IP_CIDR,gw=$GATEWAY \
  --boot c --bootdisk scsi0 --onboot $BOOT --ostype l26 --agent 1 \
  --machine q35 --cpu host --numa 1 \
  --scsihw virtio-scsi-pci --scsi0 $STORAGE:$DISK_SIZE \
  --kvm 1 --bios ovmf --tpmstate 1 --tpmstorage $STORAGE

# Adicionar ISO
echo "Adicionando a ISO..."
qm set $VMID --cdrom $ISO

# Configurações avançadas
echo "Ativando configurações avançadas..."
qm set $VMID --scsi0 $STORAGE:$DISK_SIZE,ssd=1,iothread=1,cache=writeback
qm set $VMID --balloon 0 --description "VM criada via script Bash"

echo "VM criada com sucesso!"
