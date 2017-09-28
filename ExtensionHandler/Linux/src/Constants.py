agent_setting = '.agent'
markup_file_format = '{0}/EXTENSIONDISABLED'
last_seq_num_file = 'LASTSEQNUM'
download_api_version = '3.0-preview.2'

tags_api_version = '3.2-preview.1'
agent_target_name = 'agent.tar.gz'
agent_listener = 'bin/Agent.Listener'
agent_service = 'svc.sh'
remove_agent_args = ' remove --unattended --auth PAT'


agent_removal_required_var_name = 'remove_existing_agent'
agent_download_required_var_name = 'download_agent_targz'

return_success = 0
platform_format = '{0}.{1}.{2}-{3}'

remove_agent_command = '{0} remove --unattended'

configure_agent_command = '{0} configure --unattended --acceptteeeula --deploymentgroup'

agent_command_arguments = {
                            'url' : '--url',
                            'auth' : '--auth',
                            'token' : '--token',
                            'agent' : '--agent',
                            'work' : '--work',
                            'projectname' : '--projectname',
                            'deploymentgroupname' : '--deploymentgroupname'
                          }

service_install_command = '{0} install root'
service_start_command = '{0} start'
service_stop_command = '{0} stop'
service_uninstall_command = '{0} uninstall'
package_data_address_format = '/_apis/distributedtask/packages/agent/{0}?top=1&api-version={1}'
deployment_group_address_format = '/{0}/_apis/distributedtask/deploymentgroups/{1}'
machines_address_format = '/{0}/_apis/distributedtask/deploymentgroups/{1}/Machines?api-version={2}'

deployment_groups_address_format = '/{0}/_apis/distributedtask/deploymentgroups'

red_hat_distr_name = 'Red Hat Enterprise Linux Server'
ubuntu_distr_name = 'Ubuntu'

default_agent_work_dir = '_work'
