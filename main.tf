resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create Availablity Set

resource "azurerm_availability_set" "avsetendava" {
  name                = "avsetendava"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 1
  platform_update_domain_count = 1
  managed                      = true
}

# Create virtual network
resource "azurerm_virtual_network" "endava_terraform_network" {
  name                = "endavaVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "endava_terraform_subnet" {
  name                 = "endavaSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.endava_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "endava_terraform_public_ip" {
  name                = "endavaPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "endava_terraform_nsg" {
  name                = "endavaNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

    security_rule {
      name                       = "HTTP"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
  }

}

# Create network interface
resource "azurerm_network_interface" "endava_terraform_nic" {
  name                = "endavaNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "endava_nic_configuration"
    subnet_id                     = azurerm_subnet.endava_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.endava_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.endava_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.endava_terraform_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "endava_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "endava_terraform_vm" {
  name                  = "endavaVM"
  location              = azurerm_resource_group.rg.location
  availability_set_id   = azurerm_availability_set.avsetendava.id
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.endava_terraform_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "endavaOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

    computer_name                   = "endavavm"
    admin_username                  = "" #define this
    admin_password                  = "" #define this
    disable_password_authentication = false

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.endava_storage_account.primary_blob_endpoint
  }

  connection {
    host = self.public_ip_address
    type = "ssh"
    user = "" #define this
    password = "${var.admin_password}"
    timeout = "2m"
    agent = false
  }

  provisioner "remote-exec" {
      inline = [
        "sudo apt update -y",
        "sudo apt install docker.io -y",
        "sudo git clone https://github.com/pablomuelainco/cicdworkshop.git",
        "cd /home/endavauser/cicdworkshop",
        "sudo docker build . -t cicdworkshop:latest",  
        "sudo docker run -dp 80:80 cicdworkshop:latest",
    ]
  }
}
