terraform {
  required_version = ">=0.12"
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = false
  features {}
}

resource "azurerm_resource_group" "mumble-rg" {
  name     = "mumble-resources"
  location = "North Europe"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "mumble-vnet" {
  name                = "mumble-vnet"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "mumble-subnet" {
  name                 = "mumble-subnet"
  resource_group_name  = azurerm_resource_group.mumble-rg.name
  virtual_network_name = azurerm_virtual_network.mumble-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "mumble-public-ip" {
  name                = "mumble-public-ip"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "mumble-nsg" {
  name                = "mumble-nsg"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


resource "azurerm_network_interface" "mumble-nic" {
  name                = "mumble-nic"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location

  ip_configuration {
    name                          = "mumble-nic"
    subnet_id                     = azurerm_subnet.mumble-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mumble-public-ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic-nsg" {
  network_interface_id      = azurerm_network_interface.mumble-nic.id
  network_security_group_id = azurerm_network_security_group.mumble-nsg.id
}

resource "azurerm_linux_virtual_machine" "mumble-virtual-machine" {
  name                = "mumble-vm"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location
  network_interface_ids = [azurerm_network_interface.mumble-nic.id]
  size                = "Standard_B2s"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "mumble-server"
  admin_username      = "mumble-admin"

  admin_ssh_key {
    username   = "mumble-admin"
    public_key = file("~/.ssh/azure.pub")
  }
}