# How To - guida per la gestione del progetto di automazione template 
Il seguente documento ha lo scopo di spiegare nel modo più semplice possibile come poter utilizzare la struttura di creazione template automatizzata. Il documento non si occuperà di andare nel dettaglio delle singole pipeline ma darà una visuale generale di come si è scelto di adottare i componenti e creare i flussi necessari.
Note
Nella guida troverai i link alla documentazione ufficiale dei componenti discussi nei vari punti
La guida sarà strutturata per punti come segue:
•	SPIEGAZIONE COMPONENTI
•	SPIEGAZIONE PIPELINE GITLAB CI
•	SPIEGAZIONE RUNNER e LINUX SCRIPT
•	SPIEGAZIONE PACKER
•	SPIEGAZIONE TERRAFORM
•	SPIEGAZIONE UTILIZZO SCRIPTING
Descrizione componenti utilizzati:
    • Gitlab CI - Il seguente tool è stato utilizzato per mantenere il codice di creazione dei template aggiornato e centralizzato ed inoltre offre la possibilità di creare le pipeline CI che sono poi responsabili del flusso di creazione dei template. Gitlab CI funzionerà attraverso l'uso dei Runner (ovvero vm sul quale sarà installato il servizio gitlab-runner le quali funzioneranno con un executor di tipo shell nel nostro caso. NB: gli executor possono essere svariati, ma per il nostro caso è stato usato shell per poter usare la shell della vm sul quale vengono lanciati gli script dei job)
    • Packer - Il seguente tool creato da Hashicorp permette attraverso l'uso di una sintassi semplice "HCL" di creare una vm template su diverse infrastrutture, nel nostro caso vSphere (vale anche per vCloud), Proxmox (template raw per Openstack) e Hyper-v. Anche se fuori scope è importante notare sottolineare che packer può essere usato per creare template anche su cloud pubblici come aws, google ecc.
    • Terraform - Il seguente tool è noto per la tecnica di IaC ovvero, infrastructure as Code. Con questo tool sarà possibile gestire/creare/distruggere intere infrastrutture ma, nel nostro caso lo useremo per poter eseguire la validazione dei template creati e quindi per la creazione di virtual machines partendo dai template generati da packer su vSphere (vale anche per vCloud), Proxmox (template raw per Openstack) e Hyper-v.
    • Ansible - Ansible è un tool di Automation che permette di interagire con OS di famiglia Linux e Windows. Nel nostro caso verrà usato per gestire l'installazione dei pacchetti/update/upgrade necessitati per la creazione dei template
    • Scripting - E' importante notare che durante il processo di pipeline sono stati utilizzati diversi linguaggi di scripting in base alla comodità/necessità riguardante il template creato. I linguaggi usati sono Bash, Python, Powershell

Spiegazione Pipeline CI Gitlab:
Gitlab offre la possibilità di creare una pipeline CI che ci permetterà di poter eseguire la creazione automatizzata dei template destinati alle varie infrastrutture cloud.
Le pipeline non sono altro che un file YAML chiamate come segue: ".gitlab-ci.yml" – DOCUMENTAZIONE
La struttura base delle pipeline si presenterà come segue:
Stage:
    - Deploy
    - Test
    
Job1:
    stage: Deploy
    Tags:
        - linux
    Script: 
        - Echo "test"
    
Job2:
    stage: Test
    Tags:
        - linux
    Script: 
        - Echo "test"
Da questa struttura possiamo osservare due cose fondamentali: 
    1 - La definizione degli stage che ci permettono di suddividere i flussi in modo da poter avere diversi compartimenti
    2 - La definizione di job i quali possono essere eseguiti all'interno degli stage
Nel nostro caso ad esempio una pipeline si può presentare nel seguente modo:
stages:
    - packer
    - versioning
    - terraform
    - upload_vmware
    - info-db
packer_create:
    stage: packer
    tags:
        - linux
    script:
        - packer init .
        - packer validate .
        - packer build -force .
clone_VM:
    stage: versioning
    tags:
        - linux
    before_script:
        - chmod +x Upload_VMware/versioning_VM.sh
        - export GOVC_PASSWORD=$(echo $GOVC_PASSWORD_BASE64 | base64 --decode)
        - govc session.login -k=true -u $GOVC_USERNAME:$GOVC_PASSWORD@$GOVC_URL
    script:
        - Upload_VMware/versioning_VM.sh
    after_script:
        - govc session.logout
    artifacts:
        paths:
            - variables.txt
        expire_in: 1 day
versioning_template_5:
    stage: versioning
    tags:
        - linux
    script:
        - pwsh -ExecutionPolicy Bypass -File Versioning/versioning_5.ps1
terraform_create:
    stage: terraform
    tags:
        - linux
    script:
        - terraform -chdir=Terraform init
        - terraform -chdir=Terraform plan 
        - terraform -chdir=Terraform apply -auto-approve
    artifacts:
        untracked: yes
        expose_as: "terraform"
        paths:
            - Terraform
        expire_in: 1 day
change_conf_nics:
    stage: terraform
    tags:
        - linux
    needs:
        - terraform_create
    before_script:
        - export GOVC_PASSWORD=$(echo $GOVC_PASSWORD_BASE64 | base64 --decode)
        - govc session.login -u $GOVC_USERNAME:$GOVC_PASSWORD@$GOVC_URL -k=true
    script:
        - govc vm.network.add -vm "ubuntu_2004_test_tf" -net "Parcheggio" -net.adapter "vmxnet3"
        - govc vm.network.add -vm "ubuntu_2004_test_tf" -net "Parcheggio" -net.adapter "vmxnet3"
        - govc vm.network.change -vm="ubuntu_2004_test_tf" -net "Parcheggio" ethernet-1
        - govc vm.network.change -vm="ubuntu_2004_test_tf" -net "Parcheggio" ethernet-2
        - govc device.disconnect -vm="ubuntu_2004_test_tf" ethernet-1
        - govc device.disconnect -vm="ubuntu_2004_test_tf" ethernet-2
    after_script:
        - govc session.logout
terraform_destroy_valid:
    stage: terraform
    tags:
        - linux
    when: manual
    needs: 
        - terraform_create
    script:
        - terraform -chdir=Terraform destroy -auto-approve
    dependencies:
        - terraform_create
terraform_destroy_invalid:
    stage: terraform
    tags:
        - linux
    when: manual
    needs: 
        - terraform_create
    script:
        - terraform -chdir=Terraform destroy -auto-approve
        - echo "Template non valido"; exit 78
    dependencies:
        - terraform_create
    allow_failure: false
upload_content-library:
    stage: upload_vmware
    tags:
        - linux
    needs:
        - terraform_destroy_valid
        - job: clone_VM
          artifacts: true
    before_script:
        - source variables.txt
        - chmod +x Upload_VMware/upload_vcenter.sh
        - export GOVC_PASSWORD=$(echo $GOVC_PASSWORD_BASE64 | base64 --decode)
        - govc session.login
    script:
        - govc library.rm $CL_DEPLOY_TEMPLATE"/"$VC_TEMPLATE_NAME
        - govc vm.clone -on=False -vm $VM_VERSIONED -folder="$VC_VM_TEMPLATE_MOVE_FOLDER" -ds=$DATASTORE_TARGET $VC_VM_EPHEMERAL
        - govc library.clone -vm $VC_VM_EPHEMERAL -ds $DATASTORE_TARGET -cluster=$VC_CLUSTER_NAME $CL_DEPLOY_TEMPLATE $VC_TEMPLATE_NAME
        - govc vm.destroy $VC_VM_EPHEMERAL        
    after_script:
        - govc session.logout
    dependencies:
        - terraform_destroy_valid
        - clone_VM
update-info-db:
    stage: info-db
    tags:
        - linux
    needs:
        - clone_VM
        - upload_content-library
    script:
        - source variables.txt
        - python3 Script/update-info.py

In questa pipeline, possiamo subito notare che abbiamo definito gli stages:
stages:
    - packer
    - versioning
    - terraform
    - upload_vmware
    - info-db
Che poi sono stati richiamati nei vari job tramite "stage:"come ad esempio "packer_create", "upload_content-library" ecc.
Osservando un job della pipeline sopra riportata, per esempio: 
packer_create:
    stage: packer
    tags:
        - linux
    script:
        - packer init .
        - packer validate .
        - packer build -force .
Possiamo vedere che il JOB si chiama "packer_create", tags andrà a definire il tag per richiamare il runner sul quale andremo ad eseguire il contenuto di "script" ed infine in "script" come vien facile intuire andremo a usare i comandi di che vorremmo eseguire nel job. 
NB: che in questo caso i comandi che vediamo utilizzati in script sono comandi eseguiti fisicamente sulla vm ospitante il runner con executor Bash.
Per approfondire l'infrastruttura adottata vedi l'LLD a questo LINK
 
Abbiamo inoltre utilizzato altre funzioni all'interno della nostra pipeline come:
"needs"
update-info-db:
    stage: info-db
    tags:
        - linux
    needs:
        - clone_VM
        - upload_content-library
    script:
        - source variables.txt
        - python3 Script/update-info.py
Needs servirà a dire al job di partire solo quando i job "clone_VM" e "upload_content-library" sono terminati. Questo ci permette di definire regole di flusso nell'automatismo.
Nella seguente immagine possiamo osservare come la pipeline presenterà le dipendenze.
 
"Before Script":
change_conf_nics:
    stage: terraform
    tags:
        - linux
    needs:
        - terraform_create
    before_script:
        - export GOVC_PASSWORD=$(echo $GOVC_PASSWORD_BASE64 | base64 --decode)
        - govc session.login -u $GOVC_USERNAME:$GOVC_PASSWORD@$GOVC_URL -k=true
    script:
        - govc vm.network.add -vm "ubuntu_2004_test_tf" -net "Parcheggio" -net.adapter "vmxnet3"
        - govc vm.network.add -vm "ubuntu_2004_test_tf" -net "Parcheggio" -net.adapter "vmxnet3"
        - govc vm.network.change -vm="ubuntu_2004_test_tf" -net "Parcheggio" ethernet-1
        - govc vm.network.change -vm="ubuntu_2004_test_tf" -net "Parcheggio" ethernet-2
        - govc device.disconnect -vm="ubuntu_2004_test_tf" ethernet-1
        - govc device.disconnect -vm="ubuntu_2004_test_tf" ethernet-2
Before Script si tratta di una funzione che permette, come dice la parola, di lanciare un script in testa al job, nel nostro caso viene usato per esportare delle variabili e per eseguire il login alla command-line di vCenter.
When:
terraform_destroy_invalid:
    stage: terraform
    tags:
        - linux
    when: manual
    needs: 
        - terraform_create
    script:
        - terraform -chdir=Terraform destroy -auto-approve
        - echo "Template non valido"; exit 78
    dependencies:
        - terraform_create
    allow_failure: false

Il "when" nel nostro caso viene usato con lo switch "manual" per poter lanciare il job manualmente (se non utilizzato partirà in automatico di default)
Dependencies:
Sempre facendo riferimento al blocco sopra riportato, useremo il dependencies per far sì che il job "terraform_destroy_invalid" si dipendente da terraform_create, e che vengano importate gli artefatti creati nel job precedente. Per artefatto si intende qualunque file che viene creato durante l'esecuzione del job.
"Artifacts":
clone_VM:
    stage: versioning
    tags:
        - linux
    before_script:
        - chmod +x Upload_VMware/versioning_VM.sh
        - export GOVC_PASSWORD=$(echo $GOVC_PASSWORD_BASE64 | base64 --decode)
        - govc session.login -k=true -u $GOVC_USERNAME:$GOVC_PASSWORD@$GOVC_URL
    script:
        - Upload_VMware/versioning_VM.sh
    after_script:
        - govc session.logout
    artifacts:
        paths:
            - variables.txt
        expire_in: 1 day

Artifacts permette di esportare dei file specifici creati durante l'esecuzione del job andando ad indicare un path ed un nome specifico per l'artefatto
Mentre, "after_script" all'opposto di before_script permette di lanciare uno script che venga eseguito in coda al job. Nel caso sopra riportato l'abbiamo usato per eseguire la disconnessione dal vCenter. Inoltre, usando "after_script" non verranno portate le variabili create durante la fase di "script".

Spiegazione Pipeline ad alto livello:
Ora per capire meglio come la pipeline è stata strutturata dovremo andare ad osservare gli stages che sono stati scelti (Gli stage possono chiaramente variare a seconda dell'hypervisor di destinazione, tuttavia la struttura alla base rimane uguale per tutte le casistiche).
 

Come possiamo vedere dall'immagine sopra riportata la pipeline è strutturata con 3 passaggi principali:
1 - Creazione Template (+ eventuale installazione pacchetti)
2 - Validazione Template
3 - Upload alla Content Library (varia in base all'hypervisor di destinazione)
Andiamo a vedere punto per punto:
1: Con Packer andremo a creare il template usando i seguenti file:
 
Questi file, di sintassi hcl (proprietaria di Hashicorp e facilmente intuibile), ci permetteranno di collegarci all'hypervisor in questione e di creare un template.
Andando più a fondo su packer i file sono suddivisi  e interpretati da packer nel seguente modo: 
 - .pkr.hcl → Per la build del template e per variabili
 - .auto.pkr.vars.hc –> definizione variabili
NB: le variabili sono anche inseribili nello stesso file della build
ubuntu2004.pkr.hcl 
packer {
  required_plugins {
    hyperv = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

source "hyperv-iso" "vm"  {
  boot_command = [
    "<esc><wait><esc><wait><f6><wait><esc><wait>",
    "<bs><bs><bs><bs><bs>",
    "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<enter>"
  ]

  boot_wait             = "3s"
  communicator          = "ssh"
  cpus                  = "${var.cpus}"
  disk_block_size       = "1"
  disk_size             = "${var.disk_size}"
  enable_dynamic_memory = "true"
  enable_secure_boot    = false
  generation            = 1
  http_directory        = "http"
  http_bind_address     = "${var.http_bind_address}"
  iso_url               = "${var.iso_url}"
  iso_checksum          = "${var.iso_checksum}"
  memory                = "${var.memory}"
  output_directory      = "${var.output_directory}"
  shutdown_command      = "echo 'password' | sudo -S shutdown -P now"
  shutdown_timeout      = "30m"
  ssh_password          = "${var.ssh_password}"
  ssh_timeout           = "4h"
  ssh_username          = "${var.ssh_username}"
  ssh_host              = "${var.ssh_host}"
  switch_name           = "${var.switch_name}"
  temp_path             = "."
  vlan_id               = "${var.vlan_id}"
  vm_name               = "${var.template_name}"
}

build {
   sources = ["source.hyperv-iso.vm"]
  
  provisioner "shell" {
   inline = ["sudo apt update -y && sudo apt upgrade -y"]
 }
 
}
Come notiamo dal file "ubuntu2004.pkr.hcl" abbiamo definito:
	il plugin di hyper-v (in quanto si tratta di un plugin non nativo di Packer)
	la source "hyperv-iso" dove all'interno sono presenti tutti i parametri per creare il template. (i parametri sono facilmente trovabili nella DOCUMENTAZIONE. NB: Per ogni source c'è un documento a se sul sito di Packer)
	la build, che non fa altro che andare a richiamare la source "build { sources = ["source.hyperv-iso.vm"]". All'interno della build è possibile usare svariati "provisioner"; come nell'esempio riportato che è stato usato "Shell" che permette di lanciare comandi nella vm template una volta installato l'os. Sempre nella build è possibile lanciare Ansible come provisioner (anche per questi è presente una documentazione).
Di seguito un esempio di utilizzo provisioner Ansible:
Provisioner Ansible 
 provisioner "ansible" {
    playbook_file = "Ansible/SQL2019/install-sql.yml"
    user = "administrator"
    skip_version_check  = false
    use_proxy           = false
    ansible_env_vars = [
      "-e",
      "ansible_winrm_server_cert_validation=ignore",
      "-e",
      "ansible_winrm_transport=ntlm",
    ]
  }
posizionato all'interno del blocco di build il provisioner Ansible avrà bisogno di alcuni settings base quali:
	il "playbook_file";
	lo user con il quale runnare ansible
	ed eventuali variabili che fanno riferimento ad Ansible come nel caso sopra riportato dove era necessario ignorare il certificato e usare il protocollo NTLM per la connessione winRM
Il prossimo file che andremo a vedere è quello delle variabili, come anticipato le variabili possono essere anche definite direttamente nel file della build e source, tuttavia per comodità abbiamo scelto di separarlo:
Variables 
variable "ansible_override" {
  type    = string
  default = ""
}

variable "disk_size" {
  type    = string
  default = "70000"
}

variable "disk_additional_size" {
  type    = list(number)
  default = ["1024"]
}

variable "memory" {
  type    = string
  default = "1024"
}

variable "cpus" {
  type    = string
  default = "1"
}

variable "iso_checksum" {
  type    = string
  default = ""
}

variable "iso_checksum_type" {
  type    = string
  default = "none"
}

variable "iso_url" {
  type    = string
  default = ""
}

variable "output_directory" {
  type    = string
  default = ""
}

variable "provision_script_options" {
  type    = string
  default = ""
}

variable "output_vagrant" {
  type    = string
  default = ""
}

variable "ssh_password" {
  type    = string
  default = ""
  sensitive = true
}

variable "switch_name" {
  type    = string
  default = "Packer"
}

variable "vagrantfile_template" {
  type    = string
  default = ""
}

variable "vlan_id" {
  type    = string
  default = "60"
}

variable "template_name" {
  type    = string
  default = ""
}

variable "http_directory" {
  type    = string
  default = ""
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_host" {
  type    = string
  default = ""
}

variable "http_bind_address" {
  type    = string
  default = ""
}
Come possiamo vedere le variabili verranno definite con una sintassi chiara, dove sarà necessario andare a settare il tipo e un default che può anche essere lasciato vuoto. Questa modalità ci permetterà di riportare i valori in un terzo file ".auto.pkr.vars.hc"
iso_url="https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso"
iso_checksum="sha256:b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
vm_guest_os_type="ubuntu64Guest"
ssh_password="password"
output_directory="e:\\Packer_output\\"
switch_name="VirtualSwitch"
http_bind_address="10.154.9.78"
Per quanto riguarda la validazione dei template abbiamo usato Terraform, lo useremo in modo da poter creare una vm partendo dal template creato da Packer così che poi possa essere validato da una persona fisica.
Di seguito i file necessari:
 
Come per Packer avremo un file per la build e uno per le variabili, anche qua vale la stessa regola che permette di tenere le variabili nelo stesso file della build ma abbiamo comunque deciso di separarli
Osserviamo i file da vicino:
Build TF 
terraform {
required_version = ">= 0.14.0"
  required_providers {
    hyperv = {
      version = "1.0.3"
      source  = "registry.terraform.io/taliesins/hyperv"
    }
  }
}

provider "hyperv" {
  user = "Administrator"
  password  = "Cliente2023!"
  host            = "127.0.0.1"
  port            = 5985
  https           = false
  insecure        = true
  tls_server_name = ""
  cacert_path     = ""
  cert_path       = ""
  key_path        = ""
  script_path     = "e:/terraform_%RAND%.cmd"
  timeout         = "30s"
}


resource "hyperv_vhd" "ubuntuhd" {
  path = var.vhd_path #Needs to be absolute path
}


data "hyperv_vhd" "ubuntuhd" {
  path = hyperv_vhd.ubuntuhd.path
}

output "hyperv_vhd" {
  value = data.hyperv_vhd.ubuntuhd
}

resource "hyperv_machine_instance" "default" {
  name                                    = "ubuntu22.04"
  generation                              = 2
  memory_minimum_bytes                    = 1073741824
  memory_startup_bytes                    = 1073741824
  notes                                   = ""
  processor_count                         = 1
  static_memory			          = true
  
  vm_firmware {
    enable_secure_boot              = "ON"
    secure_boot_template            = "MicrosoftUEFICertificateAuthority"
    }

hard_disk_drives {
    controller_type                 = "Scsi"
    controller_number               = "0"
    controller_location             = "0"
    path                            = hyperv_vhd.ubuntuhd.path
    disk_number                     = 4294967295
    #resource_pool_name              = "Primordial"
    support_persistent_reservations = false
    maximum_iops                    = 0
    minimum_iops                    = 0
    qos_policy_id                   = "00000000-0000-0000-0000-000000000000"
    override_cache_attributes       = "Default"
  }

network_adaptors {
  name                        = "terraform"
  vlan_id                     = 63
  switch_name 				        = var.switch_name
  vlan_access                 = true
  }

network_adaptors {
  name                        = "terraform"
  switch_name 				        = var.switch_name
  vlan_access                 = true
  }

network_adaptors {
  name                        = "terraform"
  switch_name 				        = var.switch_name
  vlan_access                 = true
  }

  # Configure integration services
  integration_services = {
    "Guest Service Interface" = false
    "Heartbeat"               = true
    "Key-Value Pair Exchange" = true
    "Shutdown"                = true
    "Time Synchronization"    = true
    "VSS"                     = true
  }
}
Come per il packer nel primo blocco abbiamo definito il provider (a differenza di packer che li chiama provisioner)"hyperv", anche qua è possibile consultare la DOCUMENTAZIONE dei provider e di tutto ciò che è necessario per costruire la build di Terraform.
Nella prima parte, il blocco "provider "hyperv"", servirà ad indicare i parametri di connessione al server hyper-v.
Per poter poi proseguire e inserire i parametri necessari facciamo riferimento alla documentazione:
 
Possiamo subito vedere che sono presenti "Resources" e "Data Sources," dove:
Resources servirà  a gestire le istanze virtual machine
Data Sources invece servirà per raccogliere informazioni da componenti e VM già esistenti nell'infrastruttura. Un esempio può essere:
resource "hyperv_vhd" "ubuntuhd" { path = var.vhd_path #Needs to be absolute path } → dove la risorsa ubuntuhd va a prendere il vhdx del template creato da Packer e viene specificato attraverso una variabile "var.vhd_path" contenente il path.
questo dato raccolto poi lo andremo ad utilizzare dentro il seguente blocco:
hard_disk_drives { controller_type = "Scsi" controller_number = "0" controller_location = "0" path = hyperv_vhd.ubuntuhd.path disk_number = 4294967295 #resource_pool_name = "Primordial" support_persistent_reservations = false maximum_iops = 0 minimum_iops = 0 qos_policy_id = "00000000-0000-0000-0000-000000000000" override_cache_attributes = "Default" }
In ultima battuta ogni pipeline creata andrà ad eseguire un upload verso la content library interesata (Glance, VMware CL, SCVMM, vCloud Library), questo sarà fatto tramite l'uso di comandi e script a seconda dell'ambiente in questione.
Nel caso della pipeline in esempio ad inzio guida, per vcenter:
Upload SCVMM 
upload_content-library:
    stage: upload_vmware
    tags:
        - linux
    needs:
        - terraform_destroy_valid
        - job: clone_VM
          artifacts: true
    before_script:
        - source variables.txt
        - chmod +x Upload_VMware/upload_vcenter.sh
        - export GOVC_PASSWORD=$(echo $GOVC_PASSWORD_BASE64 | base64 --decode)
        - govc session.login
    script:
        - govc library.rm $CL_DEPLOY_TEMPLATE"/"$VC_TEMPLATE_NAME
        - govc vm.clone -on=False -vm $VM_VERSIONED -folder="$VC_VM_TEMPLATE_MOVE_FOLDER" -ds=$DATASTORE_TARGET $VC_VM_EPHEMERAL
        - govc library.clone -vm $VC_VM_EPHEMERAL -ds $DATASTORE_TARGET -cluster=$VC_CLUSTER_NAME $CL_DEPLOY_TEMPLATE $VC_TEMPLATE_NAME
        - govc vm.destroy $VC_VM_EPHEMERAL        
    after_script:
        - govc session.logout
    dependencies:
        - terraform_destroy_valid
        - clone_VM
Andiamo a vedere che utilizzando la sintassi della Pipeline CI di Gitlab siamo andati a richiamare i comandi di govc (commandline GoLang per esecuzione remota di task su vCenter) necessari per eseguire l'upload.
