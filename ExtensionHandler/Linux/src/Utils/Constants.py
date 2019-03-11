agent_setting = '.agent'
last_seq_num_file = 'LASTSEQNUM'
download_api_version = '3.0-preview.2'
agent_working_folder = '/VSTSAgent'
update_file_name = 'EXTENSIONUPDATE'
disable_markup_file_name = 'EXTENSIONDISABLED'

targets_api_version = '4.1-preview.1'
projectAPIVersion = '5.0-preview.1'
agent_target_name = 'agent.tar.gz'
agent_listener = 'bin/Agent.Listener'
agent_service = 'svc.sh'
install_dependencies_script = "bin/installdependencies.sh"
remove_agent_args = ' remove --unattended --auth PAT'
platform_key = 'linux-x64'

agent_removal_required_var_name = 'remove_existing_agent'
agent_download_required_var_name = 'download_agent_targz'

return_success = 0

red_hat_distr_name = 'Red Hat Enterprise Linux Server'
ubuntu_distr_name = 'Ubuntu'

default_agent_work_dir = '_work'
is_on_prem = False

input_arguments_dict = {
    '-enable': 'Enable',
    '-disable': 'Disable',
    '-uninstall': 'Uninstall',
    '-update': 'Update',
    '-install': 'Install'
}

ERROR_MESSAGE_LENGTH = 300

# Http Respose Codes
HTTP_OK = 200
HTTP_FOUND = 302
HTTP_UNAUTHORIZED = 401
HTTP_FORBIDDEN = 403
HTTP_NOTFOUND = 404


# Error Codes
ERROR_UNSUPPORTED_OS = 51
ERROR_MISSING_DEPENDENCY = 52
ERROR_CONFIGURATION = 53