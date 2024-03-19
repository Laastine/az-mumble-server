
resource "azurerm_subnet" "bastion-subnet" {
  name                 = "bastion-subnet"
  resource_group_name  = azurerm_resource_group.mumble-rg.name
  virtual_network_name = azurerm_virtual_network.mumble-vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "bastion-nsg"
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

resource "azurerm_public_ip" "bastion-public-ip" {
  name                = "bastion-public-ip"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "bastion-nic" {
  name                = "bastion-nic"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location

  ip_configuration {
    name                          = "bastion-nic"
    subnet_id                     = azurerm_subnet.bastion-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion-public-ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "bastion-nic-nsg" {
  network_interface_id      = azurerm_network_interface.bastion-nic.id
  network_security_group_id = azurerm_network_security_group.bastion-nsg.id
}

resource "azurerm_linux_virtual_machine" "bastion-virtual-machine" {
  name                = "bastion-vm"
  resource_group_name = azurerm_resource_group.mumble-rg.name
  location            = azurerm_resource_group.mumble-rg.location
  network_interface_ids = [azurerm_network_interface.bastion-nic.id]
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

  computer_name  = "bastion-server"
  admin_username      = "bastion-admin"

  admin_ssh_key {
    username   = "bastion-admin"
    public_key = file("~/.ssh/azure.pub")
  }
}