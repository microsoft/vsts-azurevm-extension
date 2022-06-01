- MS docs on Deployment Groups:
  - https://docs.microsoft.com/en-us/azure/devops/pipelines/release/deployment-groups/?view=azure-devops
  - https://docs.microsoft.com/en-us/azure/devops/pipelines/process/deployment-group-phases?view=azure-devops&tabs=yaml
  - https://docs.microsoft.com/en-us/azure/devops/pipelines/apps/cd/howto-webdeploy-iis-deploygroups?view=azure-devops
- TeamServicesExtension is documented [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/release/deployment-groups/howto-provision-deployment-group-agents?view=azure-devops) for DG scenario and the BYOS scenario is documented [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops). If there is a need to add public documentation for a feature, or any troubleshooting information, it can be added here, and the reference can be provided to customers
- repo url: https://github.com/microsoft/vsts-azurevm-extension access required from Bishal
- Ways of installation/uninstallation: Azure Portal, Azure CLI, Azure Powershell, ARG V2 task, Rest API. Which way is exactly used, and who is the one doing installation can be found out in kusto in Armprod.HttpIncomingRequests table. `clientApplicationId` gives which method is being used(for example, Azure Portal has its own application, so if the installation is done througn Portal, then you will see that application id. Same for CLI etc), the `userAgent` field will also help determine which method is being used for action. `principalOid` and `principalPuid` give the object id of the actor who is performing this action. I could not find any good way to corelate RDOS.GuestAgentExtensionEvents with Armprod since there is no correlation id in GuestAgentExtensionEvents. The correlation can be narrowed down by matching tenant id, subscription id, resourcegroup name and narrowing the timestamps.
- marketplace repo for extensions: https://github.com/Azure/azure-marketplace/ . For access, need to join Azure org. I have cloned it in my account [here](https://github.com/tejasd1990/azure-marketplace)
- [build pipeline](https://dev.azure.com/mseng/AzureDevOps/_build?definitionId=4108) : Becasue self hosted agent support was removed from Azure Devops, we recently moved the pipeline to Hosted Windows 2017 agent(that will get deprecated too soon). Since on hosted agents, tools are kept uptp date, we might need to update the tools which the pipeline uses(gulp, powershell, node etc). Recently, we updated the node version in the pipeline, and also the gulp version. The gulp change was a breaking one, so had to modify unit tests in the repo as well. Also, the pipeline fetches code from the repo, so a SSO enabled Github PAT is required for service connection.
- [release pipeline](https://dev.azure.com/mseng/AzureDevOps/_release?_a=releases&view=mine&definitionId=668): There are 3 important parts to it - windows rollout, linux rollout, and secrets rotation stage, which rotates the secrets which constitute the service connections(both ARM and Classic) used in the windows and linux rollout. Both Windows and Linux have 1 test stage each, and the remaining ones are Prod ones, the secrets rotation however works on Prod only. Currently the test secrets need to be rotated manually, or changed when they expire(and also update the service connections). All this is done by the secrets rotation stage in Prod so we don't need to manually do any work or rotating the secrets and updating the service connections. There are also stages for extension version deletion, which ideally is to be used for deleting the old extension versions. But we do see usage(although very small) of even very old versions, and the docs say not to delete versions which are in use. So, we increased the 15 versions/subscription limit to 50. It can be even further increased. Need to raise ICM on the corect team to do this. See [ref](https://portal.microsofticm.com/imp/v3/incidents/details/116640743/home)
- byos
- update scenario: The update scenario is a very important one, and the flow is explained in detail in the authoring guide. Basically, it defines the functionality of the extension when it is already installed on a vm, and we release a new version. In short, the 4 steps which constitute an upgrade are:
    1. invoke disable command on the old extension version
    2. invoke update command on the new extension version
    3. invoke uninstall command on the old extension version
    4. invoke enable command on the new extension version
  Since uninstall in step 3 would remove the agent(and the next enable in step 4 would again configure the agent), this used to cause problems for those extensions which were installed for a long time(and hence the PAT got expired). Note that the enable in step 4 will be invoked with the same settings with which it was already installed. So a new version release would cause a spike in update failures. To avoid this we need to distinguish the update scenario from a normal uninstall, and in the update scenario, we should do nothing. For this, we make use of marker files which will distinguish the update scenario and will not remoe/enable the agent again.
- check extension publish status manually: The classic certificate is present [here](https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/asset/Microsoft_Azure_KeyVault/Secret/https://tedeshpa-vmext.vault.azure.net/secrets/rmdevclassiccert/48db96457381489881a96c32acfce7fc). This is useful to check the replication status for classic(classic replication happens before arm), and also to test secrets rotation on devfabric. Make sure the certificate is rotated manually before expiry
  ```
    # LOAD THE CERTIFICATE
    $certString = "CERT_IN_PEM_FORMAT"
    $bytes = [System.Convert]::FromBase64String($certString)
    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.Import($bytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet)

    # Check the repolication status regionwise
    (Invoke-RestMethod -Method GET -Uri https://management.core.windows.net/<SUBSCRIPTION_ID>/services/extensions/Test.Microsoft.VisualStudio.Services/<extension-name>/<version-all-4>/replicationstatus -Certificate $Certificate -Headers @{'x-ms-version'='2014-08-01'}).ReplicationStatusList.ReplicationStatus
    ```
- limitations:
  - cannot configure for normal agent pool on a VM through portal. The BYOS scenario does it for a VMSS, but it generates a token in DT service(instead of PAT) which cannot be done by a user through apis. So, a user cannot replicate(it is possible but quite difficult) the settings and install a normal pool agent themselves.
  - The extension is not compatible with VMSS when the agent name input is provided. This will cause multiple agents(if there are multiple instances in the vmss) to try to configure with the same agent name, leading to conflict, and errors(This actually happened with a customer). So, when using vmss, agent name should not be specified. This has not yet been documented publicly afaik, it should be added in the troubleshooting section.
  - older versions cannot be deleted, since being used. If required, security patches need to be applied
  - If the DG is not already created, the extension can create it(given that we do validations initially which includes checking the required PAT scope). But it does not create the DG, instead the extension fails. It is certainly possible and seems reasonable. If many customers ask for it, can be implemented.
  - 5 mins time limit for enable. Although install command has a 10 limit timeout, we cannot do any work there since protected settings are not available in install command and both scenarios require protected settings. Have tried reaching out to Azure teams, for a solution fo this but no amswer. Can be pursued if more percentage of timeout failures
  - Not all logs appear in Kusto for Linux extension, sometimes logs are incomplete while other times there are no logs. This can be asked to azure folks.
  - Currently, the extension checks for x64 on linux and fails if it is not the case. This unnecessary and can be removed
  - repo is private, so customers unable to reach for issues, often create issues on [agent](https://github.com/microsoft/azure-pipelines-agent) repo, so it is nuiscance for agent team, as well as customers each us late. In future, the repo can be made public.

- threat model:
  - Storing long duration PAT on the VM is a risk. If the VM is compromised, or if someone other than the PAT owner is allowed to access the VM, the PAT is compromised. 
  - Threat:
    - For configuring an agent against a deployment group, a PAT needs the 'Deployment group' scope.
    - Also, the 'Deployment group' scope inherits scopes for managing agent pools, among others.
    - So, if an attacker gets hold of a PAT from a VM, he gains complete access to all the deployment groups in all the projects in the account, along with other things such as agent pools. 
    - This is if the customer has selected only the required scopes while creating PAT. The default option is ‘All scopes’, and if the PAT is created using this option, then everything in the account gets compromised.
  - mitigation:
    - After installing the extension(successfully or unsuccessfully), we will remove the 'protectedSettings' field from the agent settings file, keeping the rest of the contents of the settings file intact. This is because the public settings are required during machine reboot and  agent reconfiguration.
    - After the extension is installed, the PAT is not used again by the handler except while uninstalling the extension(During reconfiguration, the new PAT will be used, so all scenarios remain the same). With this, every uninstall scenario will be similar to the current uninstall scenario with an expired PAT. In this case, we inform the user to remove the PAT manually from vsts.
    - A drawback of this solution is that with every uninstall step, comes a manual step of removing the red agent from VSTS. Customers who want to automate installing/uninstalling the extension to be done frequently cannot do so.