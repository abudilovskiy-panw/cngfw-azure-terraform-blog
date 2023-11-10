provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "terraform-rg"
  location = "West Europe"
}

resource "azurerm_public_ip" "cngfw-pip-westeurope" {
  name                = "cngfw-pip-westeurope"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region1
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_public_ip" "cngfw-pip-eastus" {
  name                = "cngfw-pip-eastus"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region2
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_virtual_wan" "vwan" {
  name                = "terraform-vwan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region1
}

resource "azurerm_virtual_hub" "vhub-westeurope" {
  name                = "terraform-vhub-westeurope"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region1
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = "10.0.0.0/23"
}

resource "azurerm_virtual_hub" "vhub-eastus" {
  name                = "terraform-vhub-eastyus"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region2
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = "10.1.0.0/23"
}

resource "azurerm_palo_alto_virtual_network_appliance" "nva-westeurope" {
  name           = "terraform-nva-westeurope"
  virtual_hub_id = azurerm_virtual_hub.vhub-westeurope.id
}

resource "azurerm_palo_alto_virtual_network_appliance" "nva-eastus" {
  name           = "terraform-nva-eastus"
  virtual_hub_id = azurerm_virtual_hub.vhub-eastus.id
}

resource "azurerm_palo_alto_local_rulestack" "lrs-westeurope" {
  name                  = "terraform-lrs-westeurope"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  anti_spyware_profile  = "BestPractice"
  anti_virus_profile    = "BestPractice"
  file_blocking_profile = "BestPractice"
  vulnerability_profile = "BestPractice"
  url_filtering_profile = "BestPractice"
}

resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack" "cngfw-westeurope" {
  name                = "terraform-cngfw-westeurope"
  resource_group_name = azurerm_resource_group.rg.name
  rulestack_id        = azurerm_palo_alto_local_rulestack.lrs-westeurope.id

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.cngfw-pip-westeurope.id]
    virtual_hub_id               = azurerm_virtual_hub.vhub-westeurope.id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.nva-westeurope.id
  }
}

resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama" "cngfw-eastus" {
  name                = "terraform-cngfw-eastus"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region2

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.cngfw-pip-eastus.id]
    virtual_hub_id               = azurerm_virtual_hub.vhub-eastus.id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.nva-eastus.id
  }

  panorama_base64_config = var.panorama-string
}

resource "azurerm_virtual_hub_routing_intent" "routing-intent-westeurope" {
  name           = "terraform-routing-intent-westeurope"
  virtual_hub_id = azurerm_virtual_hub.vhub-westeurope.id

  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_palo_alto_virtual_network_appliance.nva-westeurope.id
  }

  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_palo_alto_virtual_network_appliance.nva-westeurope.id
  }
  depends_on = [azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack.cngfw-westeurope]
}

resource "azurerm_virtual_hub_routing_intent" "routing-intent-eastus" {
  name           = "terraform-routing-intent-eastus"
  virtual_hub_id = azurerm_virtual_hub.vhub-eastus.id

  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_palo_alto_virtual_network_appliance.nva-eastus.id
  }

  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_palo_alto_virtual_network_appliance.nva-eastus.id
  }
  depends_on = [azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama.cngfw-eastus]
}
