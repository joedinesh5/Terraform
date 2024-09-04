# terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.0.1"
    }
  } 
}

# Creating Provider Block & getting ID values from variables Block
provider "azurerm" {
  features {}
    subscription_id = var.subscriptionID
    tenant_id       = var.TenantID
    client_id       = var.ClientId
    client_secret   = var.ClientSec
    
}

# Creating a Resource Group & getting values from Variables block
resource "azurerm_resource_group" "jd" {
  name     = var.resgrp
  location = var.location
}

# Creating a Virtual network 
resource "azurerm_virtual_network" "vnet" {
  name                = "Joe-vnet"
  location            = azurerm_resource_group.jd.location
  resource_group_name = azurerm_resource_group.jd.name
  address_space       = ["10.0.0.0/16"]
}

# Creating a subnet 
resource "azurerm_subnet" "snet" {
  name                 = "jd-subnet"
  resource_group_name  = azurerm_resource_group.jd.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}  

# Creating a Public IP
 resource "azurerm_public_ip" "pubIP" {
   name                         = "Joe-publicIPForLB"
   location                     = azurerm_resource_group.jd.location
   resource_group_name          = azurerm_resource_group.jd.name
   allocation_method            = "Static"
 }

# Creating a Load Balancer
 resource "azurerm_lb" "J_LB" {
   name                = "Joe_loadBalancer"
   location            = azurerm_resource_group.jd.location
   resource_group_name = azurerm_resource_group.jd.name

   frontend_ip_configuration {
     name                 = "publicIPAddress"
     public_ip_address_id = azurerm_public_ip.pubIP.id
   }
 }

# Creating a Backend Address Pool

 resource "azurerm_lb_backend_address_pool" "test" {
   loadbalancer_id     = azurerm_lb.J_LB.id
   name                = "BackEndAddressPool"
 }


# Creating a NIC with count bcoz multiple VM need multiple NIC

resource "azurerm_network_interface" "j_nic" {
  count = 2
  name                = "jd-nic-${count.index}"
  location            = azurerm_resource_group.jd.location
  resource_group_name = azurerm_resource_group.jd.name

  ip_configuration {
    name                          = "joe-ipconfig"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Creating a Managed Disk with count bcoz multiple VM need Multiple Disks

 resource "azurerm_managed_disk" "J_MD" {
   count                = 2
   name                 = "Joe_datadisk-${count.index}"
   location             = azurerm_resource_group.jd.location
   resource_group_name  = azurerm_resource_group.jd.name
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "10"
 }

# Creating a Availability Set

 resource "azurerm_availability_set" "J_avset" {
   name                         = "Joe_avset"
   location                     = azurerm_resource_group.jd.location
   resource_group_name          = azurerm_resource_group.jd.name
   platform_fault_domain_count  = 2
   platform_update_domain_count = 2
   managed                      = true
 }
# Creating Multiple VM using count function 
 resource "azurerm_virtual_machine" "J_VM" {
   count                 = 2
   name                  = "Joe_VM-${count.index}"
   location              = azurerm_resource_group.jd.location
   availability_set_id   = azurerm_availability_set.J_avset.id
   resource_group_name   = azurerm_resource_group.jd.name
   network_interface_ids = [element(azurerm_network_interface.j_nic.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"

   # Uncomment this line to delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true

   # Uncomment this line to delete the data disks automatically when deleting the VM
   delete_data_disks_on_termination = true

   storage_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "16.04-LTS"
     version   = "latest"
   }

   storage_os_disk {
     name              = "myosdisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }


   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"
     admin_password = "Password1234!"
   }

   os_profile_linux_config {
     disable_password_authentication = false
   }

   tags = {
     environment = "staging"
   }
 }
