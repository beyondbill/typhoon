# DNS record for the apiserver load balancer
resource "azurerm_dns_a_record" "apiserver" {
  resource_group_name = "${var.dns_zone_group}"

  # DNS Zone name where record should be created
  zone_name = "${var.dns_zone}"

  # DNS record
  name = "${var.cluster_name}"
  ttl  = 300

  # IPv4 address of apiserver load balancer
  records = ["${azurerm_public_ip.lb-ipv4.ip_address}"]
}

# Static IPv4 address for the cluster load balancer
resource "azurerm_public_ip" "lb-ipv4" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name                         = "${var.cluster_name}-lb-ipv4"
  location                     = "${var.region}"
  sku                          = "Standard"
  public_ip_address_allocation = "static"
}

# Network Load Balancer for apiservers and ingress
resource "azurerm_lb" "cluster" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name     = "${var.cluster_name}"
  location = "${var.region}"
  sku      = "Standard"

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = "${azurerm_public_ip.lb-ipv4.id}"
  }
}

resource "azurerm_lb_rule" "apiserver" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name                           = "apiserver"
  loadbalancer_id                = "${azurerm_lb.cluster.id}"
  frontend_ip_configuration_name = "public"

  protocol                = "Tcp"
  frontend_port           = 6443
  backend_port            = 6443
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.controller.id}"
  probe_id                = "${azurerm_lb_probe.apiserver.id}"
}

resource "azurerm_lb_rule" "ingress-http" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name                           = "ingress-http"
  loadbalancer_id                = "${azurerm_lb.cluster.id}"
  frontend_ip_configuration_name = "public"

  protocol                = "Tcp"
  frontend_port           = 80
  backend_port            = 80
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.worker.id}"
  probe_id                = "${azurerm_lb_probe.ingress.id}"
}

resource "azurerm_lb_rule" "ingress-https" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name                           = "ingress-https"
  loadbalancer_id                = "${azurerm_lb.cluster.id}"
  frontend_ip_configuration_name = "public"

  protocol                = "Tcp"
  frontend_port           = 443
  backend_port            = 443
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.worker.id}"
  probe_id                = "${azurerm_lb_probe.ingress.id}"
}

# Address pool of controllers
resource "azurerm_lb_backend_address_pool" "controller" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name            = "controller"
  loadbalancer_id = "${azurerm_lb.cluster.id}"
}

# Address pool of workers
resource "azurerm_lb_backend_address_pool" "worker" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name            = "worker"
  loadbalancer_id = "${azurerm_lb.cluster.id}"
}

# Health checks / probes

# TCP health check for apiserver
resource "azurerm_lb_probe" "apiserver" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name            = "apiserver"
  loadbalancer_id = "${azurerm_lb.cluster.id}"
  protocol        = "Tcp"
  port            = 6443

  # unhealthy threshold
  number_of_probes = 3

  interval_in_seconds = 5
}

# HTTP health check for ingress
resource "azurerm_lb_probe" "ingress" {
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  name            = "ingress"
  loadbalancer_id = "${azurerm_lb.cluster.id}"
  protocol        = "Http"
  port            = 10254
  request_path    = "/healthz"

  # unhealthy threshold
  number_of_probes = 3

  interval_in_seconds = 5
}
