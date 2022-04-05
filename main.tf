terraform{
    required_version = ">= 0.13"

    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
    } 
}

provider "azurerm" {
    features {
      
    }
}

resource "azurerm_resource_group" "rg_atividadeinfra"{
    name = "atividadeinfra"
    location = "brazilsouth"
}



resource "azurerm_virtual_network" "vnet_aulainfra" {
  name                = "vnet"
  location            = azurerm_resource_group.rg_atividadeinfra.location
  resource_group_name = azurerm_resource_group.rg_atividadeinfra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
  }
}


resource "azurerm_subnet" "sub_aulainfra" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg_atividadeinfra.name
  virtual_network_name = azurerm_virtual_network.vnet_aulainfra.name
  address_prefixes     = ["10.0.1.0/24"]

}



resource "azurerm_public_ip" "id_aulainfra" {
  name                    = "publicip"
  location                = azurerm_resource_group.rg_atividadeinfra.location
  resource_group_name     = azurerm_resource_group.rg_atividadeinfra.name
  allocation_method       = "Static"

  tags = {
    environment = "test"
  }
}



resource "azurerm_network_security_group" "nsg_aulainfra" {
  name                = "nsg"
  location            = azurerm_resource_group.rg_atividadeinfra.location
  resource_group_name = azurerm_resource_group.rg_atividadeinfra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
    security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}



resource "azurerm_network_interface" "nic_aulainfra" {
  name                = "nic"
  location            = azurerm_resource_group.rg_atividadeinfra.location
  resource_group_name = azurerm_resource_group.rg_atividadeinfra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.sub_aulainfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.id_aulainfra.id
  }
}


resource "azurerm_network_interface_security_group_association" "nic-nsg-aulainfra"{
    network_interface_id = azurerm_network_interface.nic_aulainfra.id
    network_security_group_id = azurerm_network_security_group.nsg_aulainfra.id
}


resource "azurerm_storage_account" "saaulainfra" {
  name                     = "saaulainfra"
  resource_group_name      = azurerm_resource_group.rg_atividadeinfra.name
  location                 = azurerm_resource_group.rg_atividadeinfra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}


resource "azurerm_linux_virtual_machine" "vm-aulainfra" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.rg_atividadeinfra.name
  location            = azurerm_resource_group.rg_atividadeinfra.location
  size                = "Standard_E2bs_v5"
  network_interface_ids = [azurerm_network_interface.nic_aulainfra.id]

  admin_username = "adminuser"
  admin_password = "Password1234!"
disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name = "mydisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"

  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.saaulainfra.primary_blob_endpoint

  }

}

data azurerm_public_ip "ip_atividadeinfra_data"{
    name = azurerm_public_ip.id_aulainfra.name
    resource_group_name = azurerm_resource_group.rg_atividadeinfra.name
}

resource "null_resource" "install-webserver" {
 
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip_atividadeinfra_data.ip_address
    user = "adminuser"
    password = "Password1234!"
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the clutser
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }
   depends_on = [
     azurerm_linux_virtual_machine.vm-aulainfra
   ]


}

