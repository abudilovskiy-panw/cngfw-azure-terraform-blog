provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "cngfw-terraform-blog" {
  name     = "terraform-blog"
  location = "West US"
}
