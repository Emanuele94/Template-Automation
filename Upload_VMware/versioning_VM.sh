#!/bin/sh

#Update variabili di ambiente
export VC_TEMPLATE_PACKER=ubuntu2004_template_packer
export VC_TEMPLATE_NAME=ubuntu2004_template
export VC_VM_TEMPLATE_PATH=/IT2-DC/vm/Templates/ubuntu2004_template
export VC_VM_TEMPLATE_PACKER_PATH=/IT2-DC/vm/Templates/ubuntu2004_template_packer
export VC_VM_TEMPLATE_MOVE_FOLDER=/IT2-DC/vm/Templates/Versioning_Template
export DATASTORE_TARGET=/IT2-DC/datastore/CELL02_DATASTORE01
export VC_VM_NAME="${VC_TEMPLATE_NAME}_$(date +%d%m%Y_%H%M)"
export VC_VM_EPHEMERAL=EPHEMERAL_TEMPLATE_VM_Ubnt2004
export VC_CLUSTER_NAME=CELL02
export VM_VERSIONED="$VC_VM_TEMPLATE_MOVE_FOLDER"/"$VC_VM_NAME"
export CL_DEPLOY_TEMPLATE=Gitlab_Template

#Creazione clone template per versioning
govc vm.clone -on=False -vm $VC_VM_TEMPLATE_PACKER_PATH -folder="$VC_VM_TEMPLATE_MOVE_FOLDER" -ds=$DATASTORE_TARGET $VC_VM_NAME

#Aggiunta schede di rete
govc vm.network.add -vm $VC_VM_NAME -net "Parcheggio" -net.adapter "vmxnet3"
govc vm.network.add -vm $VC_VM_NAME -net "Parcheggio" -net.adapter "vmxnet3"
#Cambio portgroup ETH0
govc vm.network.change -vm $VC_VM_NAME -net "Parcheggio" ethernet-0

#Disconnessione NIC
govc device.disconnect -vm $VC_VM_NAME ethernet-0
govc device.disconnect -vm $VC_VM_NAME ethernet-1
govc device.disconnect -vm $VC_VM_NAME ethernet-2

#Converti in template
govc vm.markastemplate $VC_VM_NAME

#Esportazione variabile per artefatto
echo "export VC_TEMPLATE_NAME="$VC_TEMPLATE_NAME >> variables.txt
echo "export VC_VM_TEMPLATE_PATH="$VC_VM_TEMPLATE_PATH >> variables.txt
echo "export VC_VM_TEMPLATE_MOVE_FOLDER="$VC_VM_TEMPLATE_MOVE_FOLDER >> variables.txt
echo "export DATASTORE_TARGET="$DATASTORE_TARGET >> variables.txt
echo "export VC_VM_NAME="$VC_VM_NAME >> variables.txt
echo "export VC_VM_EPHEMERAL="$VC_VM_EPHEMERAL >> variables.txt
echo "export VC_CLUSTER_NAME="$VC_CLUSTER_NAME >> variables.txt
echo "export VM_VERSIONED="$VM_VERSIONED >> variables.txt
echo "export CL_DEPLOY_TEMPLATE="$CL_DEPLOY_TEMPLATE >> variables.txt
