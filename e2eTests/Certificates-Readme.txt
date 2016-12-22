e2e tests use self-signed certificate for SSL communication between client VM(on which extension gets installed) and Tfat VM. These certificates are currently upaloaded to azure key-vault https://ms.portal.azure.com/?microsoft_azure_marketplace_itemhidekey=microsoft_custom-script-windows#resource/subscriptions/393a91ee-f98d-43ff-b964-009bda0fdf2e/resourceGroups/vm-ext-cdp/providers/Microsoft.KeyVault/vaults/vm-ext-cdp-kv/overview

This key-vault is used by azure ARM template to install certificate on VM when VM is provisioned.

In a worst case scenario, where this key-vault gets deleted, someone will need to manually upload the cert to key-vault again. For this purpose a new cert can generated first. Command to generate it is:
.\CreateCARoot.cmd <private-ip-of-tfat-vm>

Currently private IP is 10.1.0.4 and remain so untill RG gets re-created. Once cert is generated, go to above azure key-vault link and upload this cert again.

Troubleshooting:
In case this cert does not work for SSL communication, follow these steps:
1. Remote to tfat VM where this cert has already been installed
2. Open cert store usinf certmgr.msc and search for this cert
3. Export the cert. keep "export private key also" option enabled
4. Upload this new pfx to key-vault
5. provision the client VM again and try to install extension