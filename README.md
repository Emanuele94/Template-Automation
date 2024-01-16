## Description of Used Components:

1. **Gitlab CI:**
   - Tool used to keep template code centralized and updated.
   - Enables the creation of CI pipelines.
   - Utilizes Gitlab Runners with a shell executor.

2. **Packer:**
   - Created by Hashicorp, allows creating VM templates on various infrastructures using HCL syntax.
   - Used for vSphere, vCloud, Proxmox, Hyper-V, and public clouds like AWS and Google.

3. **Terraform:**
   - Infrastructure as Code (IaC) tool.
   - Used to manage, create, and destroy infrastructures.
   - Validates templates created by Packer.

4. **Ansible:**
   - Automation tool for interacting with Linux and Windows operating systems.
   - Used to manage package installation, updates, and upgrades needed for template creation.

5. **Scripting:**
   - Languages used during the pipeline process: Bash, Python, Powershell.

## Explanation of Gitlab CI Pipeline:

The Gitlab pipeline is structured into various stages and jobs:

- **Stages:**
   - packer
   - versioning
   - terraform
   - upload_vmware
   - info-db

- **Jobs:**
   - **packer_create:** Creation of the template with Packer.
   - **clone_VM:** Versioning and cloning of the VM.
   - **versioning_template_5:** Versioning through PowerShell script.
   - **terraform_create:** Utilization of Terraform for VM creation.
   - **change_conf_nics:** Modification of NIC configuration with govc.
   - **terraform_destroy_valid:** Destroy the infrastructure (manual).
   - **terraform_destroy_invalid:** Destroy the infrastructure in case of an invalid template (manual).
   - **upload_content-library:** Upload the template to the VMware Content Library.
   - **update-info-db:** Update the information database.

The pipeline follows a logical structure and employs concepts such as "needs" to define dependencies between jobs, "before_script" to execute scripts before the job starts, "when" to manually execute some jobs, "dependencies" to specify job dependencies, and "artifacts" to export files created during job execution.

## Infrastructure Components:

![image](https://github.com/Emanuele94/Template-Automation/assets/34857243/d8c30f89-4b37-4f61-8985-c864fc66df51)

## High-Level Pipeline Explanation:

![image](https://github.com/Emanuele94/Template-Automation/assets/34857243/d032331d-2d61-4cc6-88db-f74c53ea32cc)

The pipeline is divided into three main phases:
1. **Template Creation (+ Package Installation):**
   - Utilizes Packer with HCL configuration files.
   - Allows running commands, scripts, or even Ansible during the build.

2. **Template Validation:**
   - Uses Terraform to create a VM from the Packer template.
   - Allows human validation of the infrastructure.

3. **Upload to Content Library (Varies Based on Hypervisor):**
   - Uploads the template to the specific Content Library (e.g., vCenter).

## Examples of Configuration Files:

1. **Packer Configuration File (ubuntu2004.pkr.hcl):**
   - Defines the Hyper-V plugin and the build.
   - Configures variables, boot commands, and provisioners (shell or Ansible).

2. **Terraform Configuration File:**
   - Hyper-V provider, definition of VM resources, network settings, and integration with the Packer template.

3. **VMware Upload Pipeline (upload_content-library):**
   - Uses govc commands to remove, clone, and destroy VMs, and uploads to the Content Library.

The document provides a detailed overview, explaining the logic and structure of each pipeline phase and providing examples of configuration files.
