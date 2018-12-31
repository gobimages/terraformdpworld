provider "azurerm" {
    subscription_id = "${var.Subscription_ID}"
    client_id       = "${var.Client_ID}"
    client_secret   = "${var.Client_Secret}"
    tenant_id       = "${var.Tenant_ID}"
}
resource "azurerm_resource_group" "UAT" {
    name = "${var.Resource_Group}"
    location = "${var.Location}"
}
###########################################################################################
################################VIRTUAL NETWORK CREATION###################################
###########################################################################################
data "azurerm_subnet" "DP" {
  name                 = "dpwhouatsubnet"
  resource_group_name  = "dpwhorgnw"
  virtual_network_name = "dpwhonetwork"
}
resource "azurerm_network_interface" "DP" {
  name                = "${var.nic_name}"
  location            = "${azurerm_resource_group.UAT.location}"
  resource_group_name = "${azurerm_resource_group.UAT.name}"
  #dns_servers = ["10.0.1.12","10.0.1.10"]

  ip_configuration {
    name                          = "${var.IP_confname}"
    subnet_id                     = "${data.azurerm_subnet.DP.id}"
    private_ip_address_allocation = "dynamic"
  }
}
###########################################################################################
################################STORAGE ACCOUNT CREATION###################################
###########################################################################################
resource "azurerm_storage_account" "storage" {
  name                     = "${var.Storage_AccountName}"
  resource_group_name      = "${azurerm_resource_group.UAT.name}"
  location                 = "${azurerm_resource_group.UAT.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "disks" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.UAT.name}"
  storage_account_name  = "${azurerm_storage_account.storage.name}"
  container_access_type = "private"
}
locals {
  storage_account_base_uri = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.disks.name}"
}
###########################################################################################
################################VIRTUALMACHINECREATION#####################################
###########################################################################################
resource "azurerm_virtual_machine" "DP" {
  name                  = "${var.VirtualMachine_Name}"
  location              = "${azurerm_resource_group.UAT.location}"
  resource_group_name   = "${azurerm_resource_group.UAT.name}"
  network_interface_ids = ["${azurerm_network_interface.DP.id}"]
  vm_size               = "${var.VM_Size}"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "dpwhostrgsaluat_os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    vhd_uri       = "${local.storage_account_base_uri}/dpwhostrgsaluatos.vhd"
    #managed_disk_type = "Standard_LRS"
  }
    storage_data_disk {
    name          = "dpwhoispecuat-1"
    vhd_uri       = "${local.storage_account_base_uri}/dpwhoispecuat-1.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "0"
  }
  storage_data_disk {
    name          = "dpwhoispecuat-2"
    vhd_uri       = "${local.storage_account_base_uri}/dpwhoispecuat-2.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "1"
  }
  storage_data_disk {
    name          = "dpwhoispecuat-3"
    vhd_uri       = "${local.storage_account_base_uri}/dpwhoispecuat-3.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "2"
  }
  storage_data_disk {
    name          = "dpwhoispecuat-4"
    vhd_uri       = "${local.storage_account_base_uri}/dpwhoispecuat-4.vhd"
    disk_size_gb  = "500"
    create_option = "Empty"
    lun           = "3"
  }
  os_profile {
    computer_name  = "dpwhosaluat1"
    admin_username = "gobinath"
    admin_password = "Mageswaran225"
  }
 os_profile_windows_config {
    provision_vm_agent = true
  }
  license_type = "Windows_Server"
}
resource "azurerm_virtual_machine_extension" "DP" {
  name                 = "custom"
  location             = "${azurerm_resource_group.UAT.location}"
  resource_group_name  = "${azurerm_resource_group.UAT.name}"
  virtual_machine_name = "${azurerm_virtual_machine.DP.name}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  protected_settings = <<PROTECTED_SETTINGS
  {
  "storageAccountName": "dpwhostrgbak",
  "storageAccountKey": "4EPVsMhekjxcoaWs9nNrgBWBf7sdO3CKloodwry+uC4mhlZ8PfEEZsBpjY3Sq00abN0X8JVOVlrIHKwpWm8awA=="
  }
  PROTECTED_SETTINGS
    settings = <<SETTINGS
    {
        "fileUris": [
                "https://dpwhostrgbak.blob.core.windows.net/vhds/joindomain.ps1"
            ],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File joindomain.ps1"
    }
SETTINGS
}
