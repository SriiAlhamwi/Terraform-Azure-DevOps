# Define provider
provider "azurerm" {
    version = "~>2.0"
    features {}
}

# Create Resource Group
resource "azurerm_resource_group" "CloudGovRG" {
    name     = "CloudGovRG"
    location = "West Europe"
    tags = {
        environment = "Terraform"
        
    }
}

resource "null_resource" "previous" {}

resource "time_sleep" "wait_15_seconds" {
  depends_on = [null_resource.previous]

  create_duration = "15s"
}

# This resource will create (at least) 15 seconds after null_resource.previous
resource "null_resource" "next" {
  depends_on = [time_sleep.wait_15_seconds]
}

# Create virtual network
resource "azurerm_virtual_network" "CloudGovVnet" {
    name                = "CloudGovVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "West Europe"
    resource_group_name = "CloudGovRG"

    tags = {
        environment = "Terraform"
    }
}

# Create subnet
resource "azurerm_subnet" "CloudGovPubSub" {
    name                 = "CloudGovPubSub"
    resource_group_name = "CloudGovRG"
    virtual_network_name = azurerm_virtual_network.CloudGovVnet.name
    address_prefix       = "10.0.1.0/24"
}
resource "azurerm_subnet" "CloudGovPrivSub" {
    name                 = "CloudGovPrivSub"
    resource_group_name = "CloudGovRG"
    virtual_network_name = azurerm_virtual_network.CloudGovVnet.name
    address_prefix       = "10.0.2.0/24"
}

#Create Network Security Group

resource "azurerm_network_security_group" "CloudGovNSG" {
  name                = "CloudGovNSG"
  location            = "West Europe"
  resource_group_name = "CloudGovRG"
}

#  Allow port 80
resource "azurerm_network_security_rule" "Web80" {
  name                        = "Web80"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "CloudGovRG"
  network_security_group_name = azurerm_network_security_group.CloudGovNSG.name
}

#  Allow ICMP 
resource "azurerm_network_security_rule" "Ping" {
  name                        = "Ping"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "ICMP"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "CloudGovRG"
  network_security_group_name = azurerm_network_security_group.CloudGovNSG.name
}

#  Allow port SSH
  resource "azurerm_network_security_rule" "SSH" {
  name                        = "SSH"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "CloudGovRG"
  network_security_group_name = azurerm_network_security_group.CloudGovNSG.name
}

#Deploy Public IP
resource "azurerm_public_ip" "pubip" {
  name                = "pubip"
  location            = "West Europe"
  resource_group_name = "CloudGovRG"
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

#Create NIC
resource "azurerm_network_interface" "NIC1" {
  name                = "NIC1"  
  location            = "West Europe"
  resource_group_name = "CloudGovRG"

    ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.CloudGovPubSub.id 
    private_ip_address_allocation  = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubip.id
  }
}

#Create Boot Diagnostic Account
resource "azurerm_storage_account" "sa" {
  name                     = "diagaccreinsrii1337" 
  resource_group_name      = "CloudGovRG"
  location                 = "West Europe"
   account_tier            = "Standard"
   account_replication_type = "LRS"

   tags = {
    environment = "Boot Diagnostic Storage"
    CreatedBy = "Admin"
   }
  }

#Create Virtual Machine
resource "azurerm_virtual_machine" "CloudGovVM" {
  name                  = "CloudGovVM"  
  location              = "West Europe"
  resource_group_name   = "CloudGovRG"
  network_interface_ids = [azurerm_network_interface.NIC1.id]
  vm_size               = "Standard_B1s"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk1"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "RienkVM"
    admin_username = "vmadmin"
    admin_password = "Password12345!"
  }


  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/vmadmin/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDi2yCOtc89IHcqVQ9kMkqLXUE2lnR3pTBb60jzAqB3WNzK1sREb1oeFTp81Kf2CrBU7OCJ7gl6wxRlMsBh+UlQly1LtOuYiGnO6fkZa0ytVRVogPeb1DOCIPc9Nu9xe2TvNN2SnaTDxOqnndjUVlsq9edFdXdpsSKN66saCjUAxgj+tSaRjWvUlZaClaRmRu7uoOAoMyZD158pIXZ87anH2Dh7Va4TmRkd24VMCkKpxmCVghHmjA0r+qL4KJbJe3LitxxRIXcMiy3avKMlsKecKm33WytIvBfcITLgnclrxzwBhrJS8E1qwWz95RqqN06zqjbYPCWdtOs3OMUqE/5GtPhJlguFxAK0D/ej6U79E9U+vD+6/JKgiSmQ1O6EEOxaVZPQjL4CTYLQCJ2WMFzORsG6Xrn3Q/P94jwKw+V6tVu8Lj9P0EXq1+fJAI2kiqsUkyAjQel4Tt5yhSD7M8fVlBOfbN5PuI1ek9Q+WzrLbhkxM8A81pn6S4eG2welBwP/uWQax93+AGmOgrKA8kSUuKsJlk1nfo4N0NKOVHF1AqbtShPMrx+0J3GL2IR0hcOXQ1WXohRzMfi27g+2hsZ9e4qoeH1hlHXM7StazaqGJ47xrz/Qc5qrrNRqrPM7t0uq86Qq2JRkVkblUxU3bkGPd8p1B/OJKUqS1xlV11s6/Q== srii@cc-31bbff04-65b89cbcb4-gqr6l"
    }
  
  }

boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.sa.primary_blob_endpoint
    }
}

# Create Appplan
resource "azurerm_app_service_plan" "svcplan" {
  name                = "CloudGovSvcPlan"
  location            = "West Europe"
  resource_group_name = "CloudGovRG"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

#Create Webapp
resource "azurerm_app_service" "appsvc" {
  name                = "CloudGovWebApp"
  location            = "West Europe"
  resource_group_name = "CloudGovRG"
  app_service_plan_id = azurerm_app_service_plan.svcplan.id


  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }
}