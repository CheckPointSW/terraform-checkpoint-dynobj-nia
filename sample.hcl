log_level = "info"

consul {
    address = "192.168.0.1:8500"
}

buffer_period {
    min = "5s"
    max = "20s"
}

task {
    name = "sample"
    description = "This task dynamically updates service addresses"
    source = "../../"
    providers = ["checkpoint"]
    services = ["web_services", "api_services", "db_services"]
}

driver "terraform" {
  log = true
  required_providers {
    checkpoint = {
      source = "CheckPointSW/checkpoint"
    }
  }
}

provider "checkpoint" {
  server = "192.168.0.5"
  username = "consul_user"
  password = "test123"
  context = "web_api"
  timeout = 60
}