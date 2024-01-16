from os import environ as env
import json
import requests

variable_key = "project_info"
tmpl_name = env['VC_VM_NAME']
ci_pj_id = env['CI_PROJECT_ID']
family_os = "linux"
vm_path = env['VC_VM_TEMPLATE_MOVE_FOLDER']
tmpl_library_name = env['VC_TEMPLATE_NAME']
access_token = "glpat-Gn15SxKLkPzXwMdnm9e6"

data = {
    "pj_id": ci_pj_id,
    "tmpl_name": tmpl_name,
    "family_os": family_os,
    "vm_path": vm_path,
    "tmpl_library_name": tmpl_library_name
}

# Converti in json
json_string = json.dumps(data)

# Funzione di update var gitlab
def update_variable(project_id, access_token, variable_key, value):
    api_url = "http://gitlab.arubaeng.lab/api/v4/"
    headers = {
        "PRIVATE-TOKEN": access_token
    }
    endpoint = f"{api_url}/projects/{ci_pj_id}/variables/{variable_key}"
    data = {
        "value": value
    }

    response = requests.put(endpoint, headers=headers, data=data)

    if response.status_code == 200:
        print(f"Variable {variable_key} updated successfully.")
    else:
        print(f"Error updating variable {variable_key}. Status code: {response.status_code}, Response: {response.text}")

# Update Variable
update_variable(ci_pj_id, access_token, variable_key, json_string)
