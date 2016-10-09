agent_setting = '.agent'
download_api_version = '3.0-preview.2'
agent_target_name = 'agent.tar.gz'
agent_listener = 'bin/Agent.Listener'
config_common_args = '--machinegroup --runasservice --unattended ---auth PAT'
remove_agent_args = ' remove --unattended --auth PAT'


agent_removal_required_var_name = 'remove_existing_agent'
agent_download_required_var_name = 'download_agent_targz'

return_success = 0
platform_format = '{0}.{1}.{2}-{3}'

remove_agent_command = '{0} remove --unattended --auth PAT --token {1}'
#configure_agent_command = '{0} --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --projectname {5} --machinegroupname {6} --pool default'

configure_agent_command = '{0} configure --unattended --acceptteeeula --url {1} --auth PAT --token {2} --agent {3} --work {4} --pool default'
package_data_address_format = "/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}"

red_hat_distr_name = 'Red Hat Enterprise Linux Server'
ubuntu_distr_name = 'Ubuntu'


