terraform {
  required_version = ">= 1.4.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.48.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
  }
}
