provider "azurerm" {}

resource "azurerm_resource_group" "tcsgrp" {
  name     = "testTCSGroup"
  location = "North Europe"
}

resource "azurerm_virtual_network" "tcsvirtnet" {
  name                = "testTCSVirtualNetwork"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.tcsgrp.location}"
  resource_group_name = "${azurerm_resource_group.tcsgrp.name}"
}

resource "azurerm_subnet" "tcssubnet" {
  name                 = "testTCSSubNet"
  resource_group_name  = "${azurerm_resource_group.tcsgrp.name}"
  virtual_network_name = "${azurerm_virtual_network.tcsvirtnet.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "tcspubip" {
  name                         = "testTCSPIP"
  location                     = "${azurerm_resource_group.tcsgrp.location}"
  resource_group_name          = "${azurerm_resource_group.tcsgrp.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "tcsgrouptwo"

  tags {
    environment = "staging"
  }
}

resource "azurerm_lb" "tcslb" {
  name                = "testTCSLoadBalancer"
  location            = "${azurerm_resource_group.tcsgrp.location}"
  resource_group_name = "${azurerm_resource_group.tcsgrp.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.tcspubip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "tcslbbckadrpool" {
  resource_group_name = "${azurerm_resource_group.tcsgrp.name}"
  loadbalancer_id     = "${azurerm_lb.tcslb.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "tcslbnatpool" {
  count                          = 2
  resource_group_name            = "${azurerm_resource_group.tcsgrp.name}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.tcslb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "tcslbprobe" {
  resource_group_name = "${azurerm_resource_group.tcsgrp.name}"
  loadbalancer_id     = "${azurerm_lb.tcslb.id}"
  name                = "http-running-probe"
  protocol            = "HTTP"
  port                = 80
  request_path        = "/"
}

resource "azurerm_lb_rule" "tcslbrule" {
  resource_group_name            = "${azurerm_resource_group.tcsgrp.name}"
  loadbalancer_id                = "${azurerm_lb.tcslb.id}"
  name                           = "HTTPrule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.tcslbbckadrpool.id}"
  probe_id                       = "${azurerm_lb_probe.tcslbprobe.id}"
}

#################################### Network security group and rules

resource "azurerm_network_security_group" "tcsnetsecgrp" {
  name                = "testTCSSecurityGroup"
  location            = "${azurerm_resource_group.tcsgrp.location}"
  resource_group_name = "${azurerm_resource_group.tcsgrp.name}"
}

resource "azurerm_network_security_rule" "allowSSH" {
  name                        = "allowSSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.tcsgrp.name}"
  network_security_group_name = "${azurerm_network_security_group.tcsnetsecgrp.name}"
}

resource "azurerm_network_security_rule" "allowHTTP" {
  name                        = "allowHTTP"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.tcsgrp.name}"
  network_security_group_name = "${azurerm_network_security_group.tcsnetsecgrp.name}"
}

resource "azurerm_virtual_machine_scale_set" "tcsvmss" {
  name                = "testTCSScaleSet"
  location            = "${azurerm_resource_group.tcsgrp.location}"
  resource_group_name = "${azurerm_resource_group.tcsgrp.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_A0"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "azuretestvm"
    admin_username       = "${var.admin_user}"
    admin_password       = "${var.admin_password}"
    custom_data          = "${file("web.conf")}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/myadmin/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      subnet_id                              = "${azurerm_subnet.tcssubnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.tcslbbckadrpool.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.tcslbnatpool.*.id, count.index)}"]
    }
  }

  extension {
    name                 = "customScript"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
        {
          "commandToExecute": "mkdir -p /var/www/html/ && echo \"Hello world from $(hostname)\" > /var/www/html/index.html"
        }
      SETTINGS
  }
}
