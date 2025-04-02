#!/bin/bash
clear
echo "=== Criando VM no Proxmox ==="

# Perguntar informações
while true; do
    read -p "Qual a ID da VM: " VMID

    # Verifica se a ID já está em uso no Proxmox
    if qm list | awk '{print $1}' | grep -q "^$VMID$" || pct list | awk '{print $1}' | grep -q "^$VMID$"; then
        echo "A ID $VMID já está em uso por uma VM, CT ou Template. Por favor, insira outra."
    else
        break
    fi
done

read -p "Digite o hostname da VM: " HOSTNAME
read -p "Iniciar no boot? (S/N): " BOOT_OPTION
BOOT="0"
if [[ "$BOOT_OPTION" =~ ^[Ss]im$ || "$BOOT_OPTION" =~ ^[Ss]$ ]]; then
  BOOT="1"
elif [[ "$BOOT_OPTION" =~ ^[Nn]ão$ || "$BOOT_OPTION" =~ ^[Nn]$ || -z "$BOOT_OPTION" ]]; then
  BOOT="0"
else
  echo "Opção inválida. Considerando como 'Não'."
fi

# Listar ISOs disponíveis
ISO_DIR="/var/lib/vz/template/iso" 
echo -e "\n\nArquivos ISO disponíveis:"
ISO_FILES=($(ls "$ISO_DIR"/*.iso))
for i in "${!ISO_FILES[@]}"; do
    echo "$((i+1)). $(basename "${ISO_FILES[$i]}")"
done
echo ""
read -p "Escolha a ISO para instalação. Opção: " OPTION
ISO="${ISO_FILES[$((OPTION-1))]}"

echo -e "\n\nLocais de armazenamento disponíveis para VMs:"
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
clear
read -p "Digite o tamanho do disco em GB: " DISK_SIZE
read -p "Quantidade de vCPU para a VM ? " CORES
read -p "Quantidade de memória (em GB): " MEMORY_GB
MEMORY=$((MEMORY_GB * 1024))

# Configurações de rede
read -p "Digite o IP/CIDR para a interface de rede (ex: 192.168.1.100/24): " IP_CIDR
read -p "Digite o gateway: " GATEWAY

# Criar a VM
clear
echo "Criando a VM..."

qm create $VMID -agent 1 -machine q35 -tablet 0 -localtime 1 -bios ovmf -cpu host -numa 1 -cores $CORES -memory $MEMORY \
  -name $HOSTNAME -net0 virtio,bridge=vmbr0,ip=$IP_CIDR,gw=$GATEWAY -onboot $BOOT -ostype l26 -scsihw virtio-scsi-pci -scsi0 $STORAGE:$DISK_SIZE \
  -boot c -bootdisk scsi0 -kvm 1 -efidisk0 $STORAGE:1

# Adiciona o TPM com armazenamento especificado
qm set $VMID -tpmstate0 $STORAGE:4,size=4M,version=v2.0

# Adicionar ISO
echo "Adicionando a ISO..."
qm set $VMID -cdrom $ISO

# Configurações avançadas
echo "Ativando configurações avançadas..."
qm set $VMID -scsi0 $STORAGE:$DISK_SIZE,ssd=1,iothread=1,cache=writeback
qm set $VMID -balloon 0

echo "VM criada com sucesso!"
