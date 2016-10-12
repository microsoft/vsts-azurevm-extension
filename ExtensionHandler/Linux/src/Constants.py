agent_setting = '.agent'
#agent_setting = 'agent.json'

download_api_version = '3.0-preview.2'
agent_target_name = 'agent.tar.gz'
agent_listener = 'bin/Agent.Listener'
agent_service = 'svc.sh'
config_common_args = '--machinegroup --runasservice --unattended ---auth PAT'
remove_agent_args = ' remove --unattended --auth PAT'


agent_removal_required_var_name = 'remove_existing_agent'
agent_download_required_var_name = 'download_agent_targz'

return_success = 0
platform_format = '{0}.{1}.{2}-{3}'

remove_agent_command = '{0} remove --unattended --auth PAT --token {1}'
#configure_agent_command = '{0} configure --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --projectname {5} --machinegroup {6} --pool {7}'
#configure_agent_command = '{0} configure --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --projectname {5} --machinegroup --machinegroupname {6}'
configure_agent_command = '{0} configure --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --projectname {5} --machinegroupname {6} --pool {7}'
#configure_agent_command = '{0} configure --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --projectname {5} --machinegroup {6}'

service_install_command = '{0} install root'
service_start_command = '{0} start'
service_stop_command = '{0} stop'
service_uninstall_command = '{0} uninstall'
#configure_agent_command = '{0} configure --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --pool default'
package_data_address_format = "/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}"

red_hat_distr_name = 'Red Hat Enterprise Linux Server'
ubuntu_distr_name = 'Ubuntu'

default_agent_work_dir = '_work'
