resource "azurerm_resource_group" "this" {
  name     = "${var.service_name}-${var.env}"
  location = "eastus"
}

# 本番環境用ToDo: サブスクリプション、サービスプリンシパルの払い出し、GitHub Actions側の対応を実施する必要あり

resource "azurerm_cognitive_account" "this" {
  name                  = "${var.service_name}-${var.env}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "domain-${var.env}"

  # IPアドレス制限をする場合、こちらを利用する
  # network_acls {
  #   default_action = "Deny"
  #   ip_rules       = ["xx.xx.xx.xx", "xx.xx.xx.xx"] # 許可するIPの一覧
  # }
}

resource "azurerm_cognitive_deployment" "this" {
  name                 = "gpt-4o-${var.env}"
  cognitive_account_id = azurerm_cognitive_account.this.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-08-06"
  }
  sku {
    name = "GlobalStandard"
  }
}
