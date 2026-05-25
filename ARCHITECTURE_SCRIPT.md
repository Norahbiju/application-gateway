# Azure Hub-Spoke Application Architecture Script

## Project Overview

This project is an Azure cloud infrastructure deployment for hosting two separate web applications: the Organic application and the Fitness application. The applications are exposed using two custom subdomains:

```text
organic.nexaflow.site
fitness.nexaflow.site
```

The entire infrastructure is provisioned using Terraform, and the design follows a hub-spoke architecture. The goal of this architecture is to separate shared networking and security services from application workloads, while still allowing secure communication between the applications, the database, and the internet.

The hub virtual network contains the shared services: Azure Application Gateway, Azure Firewall, and Azure Bastion. The Organic and Fitness applications each run in their own isolated spoke virtual networks. Each application is deployed on a Linux Virtual Machine Scale Set, and both applications connect privately to a shared Azure Cosmos DB account using the MongoDB API.

The main idea is that users access the applications through Application Gateway, administrators access the backend privately through Bastion, outbound internet traffic is controlled through Azure Firewall, and database traffic stays private through private endpoints.

## Why We Chose Hub-Spoke Architecture

We chose a hub-spoke architecture because it is a standard Azure network design for secure and scalable workloads.

The hub network acts as the central control point. It contains common shared services like ingress, firewall, and bastion access. The spoke networks contain the actual application workloads. This gives us separation between shared infrastructure and application infrastructure.

This architecture is better than placing everything in one VNet because each application gets its own network boundary. Organic and Fitness are isolated from each other, but both can still use shared services in the hub. It also avoids duplication, because we do not need one firewall, one bastion, and one application gateway per application.

The architecture also supports future growth. If a third application is added later, we can create a new spoke VNet and connect it to the hub without redesigning the entire network.

## Resource Group and Subscription

All resources are deployed inside the Azure subscription under the resource group:

```text
rg-frontend-alb-westus
```

In the Azure Portal UI, this would be created by going to **Resource groups -> Create**, selecting the subscription, choosing the region as `West US`, and naming the resource group `rg-frontend-alb-westus`.

We use a single resource group here because this is one project environment. In a larger production setup, we could split resources into separate resource groups, for example one for networking, one for compute, and one for data.

## Hub Virtual Network

The hub VNet is:

```text
vnet-frontend-alb-hub-westus
Address space: 10.20.0.0/16
```

In the Azure Portal, this would be created from **Virtual Networks -> Create**. The important UI configurations are:

```text
Region: West US
Address space: 10.20.0.0/16
```

Inside the hub VNet, we created three subnets:

```text
ApplicationGatewaySubnet: 10.20.1.0/24
AzureFirewallSubnet:     10.20.2.0/26
AzureBastionSubnet:      10.20.3.0/26
```

The subnet names are important. Azure requires the Application Gateway subnet to be dedicated to Application Gateway. Azure Firewall must be placed in a subnet named exactly `AzureFirewallSubnet`, and Azure Bastion must be placed in a subnet named exactly `AzureBastionSubnet`.

## Application Gateway

Azure Application Gateway is used as the public entry point for both applications.

It has a public IP address:

```text
20.237.141.231
```

Users access:

```text
http://organic.nexaflow.site
http://fitness.nexaflow.site
```

Both DNS records point to the Application Gateway public IP.

In the Azure Portal UI, the equivalent configuration would be:

```text
Application Gateway tier: WAF_v2
Frontend IP: Public
Public IP SKU: Standard
Frontend port: HTTP 80
Backend pools:
  - Organic VMSS backend pool
  - Fitness VMSS backend pool
Listeners:
  - organic.nexaflow.site on port 80
  - fitness.nexaflow.site on port 80
Routing type: Host-based routing
```

We chose Application Gateway instead of a basic Load Balancer because Application Gateway works at Layer 7. It understands HTTP hostnames, paths, headers, and can route based on the domain name. That is how both applications can share one public IP while still routing to different backend pools.

For example:

```text
organic.nexaflow.site -> Organic VMSS
fitness.nexaflow.site -> Fitness VMSS
```

Application Gateway also uses a WAF policy. The WAF is configured in prevention mode with OWASP managed rules. This gives the applications protection against common web attacks such as SQL injection, cross-site scripting, and malicious request patterns.

Currently the applications are exposed over HTTP. SSL termination can be added later by uploading or referencing a certificate and creating HTTPS listeners on port 443.

We also enabled cookie-based affinity. This matters because the Organic application uses in-memory sessions. Without affinity, login might happen on one VMSS instance and the dashboard request might go to another instance, where the session does not exist. Cookie affinity keeps a user pinned to the same backend instance during a session.

## Azure Firewall

Azure Firewall is deployed in the hub subnet:

```text
AzureFirewallSubnet: 10.20.2.0/26
```

It has its own public IP:

```text
20.237.253.199
```

In the Azure Portal UI, the equivalent choices are:

```text
Firewall SKU: Standard
Firewall type: VNet firewall
Subnet: AzureFirewallSubnet
Public IP: Standard static public IP
```

We use Azure Firewall for centralized outbound egress. This means the VMSS instances do not need public IP addresses, and they do not use NAT Gateway. Instead, their default route points to the private IP of Azure Firewall.

The route table configuration is:

```text
0.0.0.0/0 -> Azure Firewall private IP
```

This is applied to both spoke application subnets.

Outbound traffic such as package downloads, GitHub clone, npm install, apt updates, and other internet traffic flows like this:

```text
VMSS -> Route Table -> Azure Firewall -> Firewall Public IP -> Internet
```

This gives us centralized control and logging for outbound traffic.

We also added firewall network rules for Cosmos DB private endpoint communication on TCP port `10255`, because Cosmos DB Mongo API uses port `10255`.

## Azure Bastion

Azure Bastion is deployed in:

```text
AzureBastionSubnet: 10.20.3.0/26
```

It has its own public IP:

```text
52.160.148.44
```

In the Azure Portal UI, the equivalent settings are:

```text
Bastion SKU: Basic
Subnet: AzureBastionSubnet
Public IP: Standard static public IP
```

We use Bastion so administrators can connect to VMSS instances privately without exposing SSH to the internet.

The admin traffic flow is:

```text
Admin -> Azure Bastion public IP -> Bastion -> private VMSS instance
```

This is better than assigning public IPs to the VMs because it reduces attack surface. There is no direct SSH exposure from the internet to the application instances.

## Organic Spoke VNet

The Organic application is deployed in its own spoke VNet:

```text
vnet-frontend-alb-organic-westus
Address space: 10.21.0.0/16
Subnet: snet-organic-app 10.21.1.0/24
```

The Organic spoke contains:

```text
Organic Linux VMSS
Network interfaces
Network security group
Route table
Cosmos DB private endpoint
```

The Organic VMSS has no public IP. It receives traffic only from Application Gateway.

The application stack is:

```text
Nginx listens on port 80
Node.js app runs on localhost:5656
Nginx reverse proxies requests to Node.js
```

The application source is cloned during VM bootstrap from:

```text
https://github.com/Msocial123/organic-ghee.git
```

The Organic app uses the Cosmos database:

```text
restorent
```

## Fitness Spoke VNet

The Fitness application is deployed in a separate spoke VNet:

```text
vnet-frontend-alb-fitness-westus
Address space: 10.22.0.0/16
Subnet: snet-fitness-app 10.22.1.0/24
```

The Fitness spoke contains:

```text
Fitness Linux VMSS
Network interfaces
Network security group
Route table
Cosmos DB private endpoint
```

The Fitness VMSS also has no public IP.

The application stack is:

```text
Nginx listens on port 80
Node.js app runs on localhost:5000
Nginx reverse proxies requests to Node.js
```

The application source is cloned during VM bootstrap from:

```text
https://github.com/Msocial123/Fitness_Tracker.git
```

The Fitness app uses the Cosmos database:

```text
fitness-tracker
```

## VNet Peering

The hub is peered with each spoke:

```text
Hub <-> Organic Spoke
Hub <-> Fitness Spoke
```

The peering options are:

```text
Allow virtual network access: Enabled
Allow forwarded traffic: Enabled
```

We allow virtual network access so resources in the hub and spokes can communicate privately. We allow forwarded traffic because traffic may pass through Azure Firewall in the hub.

We do not directly peer Organic and Fitness spokes. That keeps the design aligned with hub-spoke principles. If traffic needs to move between spokes, it should route through the hub, not directly from spoke to spoke.

## Network Security Groups

Each application subnet has an NSG. The NSG allows HTTP traffic from the Application Gateway subnet to the VMSS instances.

The main rule is:

```text
Source: ApplicationGatewaySubnet 10.20.1.0/24
Destination: VMSS subnet
Port: 80
Protocol: TCP
Action: Allow
```

This means only Application Gateway should send application traffic to the backend instances.

We also allow internal virtual network traffic needed for private endpoint and platform communication. The VMSS instances themselves do not have public IPs.

## Cosmos DB Mongo API

The database layer is Azure Cosmos DB using the MongoDB API.

The Cosmos account is:

```text
cosmos-frontend-alb-westus
```

It contains databases:

```text
restorent
fitness-tracker
```

In Azure Portal UI, this would be created with:

```text
API: Azure Cosmos DB for MongoDB
Account type: MongoDB API
Public network access: Disabled
Region: West US
Consistency: Session
Mongo server version: 7.0
```

Public network access is disabled because the database should not be reachable from the public internet.

Instead, the applications connect using private endpoints.

## Private Endpoints and Private DNS

Each spoke has a private endpoint to Cosmos DB Mongo API.

The private DNS zone is:

```text
privatelink.mongo.cosmos.azure.com
```

This zone is linked to both spoke VNets.

When an app resolves:

```text
cosmos-frontend-alb-westus.mongo.cosmos.azure.com
```

it resolves to a private IP instead of a public IP.

The database traffic flow is:

```text
Organic VMSS -> Private DNS -> Cosmos private endpoint -> Cosmos DB Mongo API
Fitness VMSS -> Private DNS -> Cosmos private endpoint -> Cosmos DB Mongo API
```

Cosmos Mongo API uses:

```text
TCP 10255 over TLS
```

This keeps database traffic private and prevents direct public access to Cosmos DB.

## Inbound User Traffic Flow

For Organic:

```text
User browser
-> DNS lookup for organic.nexaflow.site
-> Application Gateway public IP
-> WAF inspection
-> Host listener for organic.nexaflow.site
-> Organic backend pool
-> Organic VMSS NIC
-> Nginx port 80
-> Node.js localhost:5656
-> Cosmos DB Mongo API through private endpoint
```

For Fitness:

```text
User browser
-> DNS lookup for fitness.nexaflow.site
-> Application Gateway public IP
-> WAF inspection
-> Host listener for fitness.nexaflow.site
-> Fitness backend pool
-> Fitness VMSS NIC
-> Nginx port 80
-> Node.js localhost:5000
-> Cosmos DB Mongo API through private endpoint
```

## Outbound Traffic Flow

The VMSS instances need outbound internet access for things like:

```text
apt updates
NodeSource setup
GitHub clone
npm install
package downloads
```

But we do not use NAT Gateway.

Instead, both spoke subnets have a route table:

```text
0.0.0.0/0 -> Azure Firewall private IP
```

So outbound traffic flows as:

```text
VMSS -> Route Table -> Azure Firewall -> Firewall Public IP -> Internet
```

This gives centralized egress control.

## Why No NAT Gateway

NAT Gateway is a good service for simple outbound internet access, but this design intentionally uses Azure Firewall because we want centralized security control. Azure Firewall can inspect, allow, deny, and log outbound flows. NAT Gateway only provides outbound SNAT and does not give the same policy control.

Since the requirement was to avoid NAT Gateway and send outbound through the firewall, Azure Firewall is the correct choice.

## Why VM Scale Sets

Both applications are deployed on VM Scale Sets instead of single VMs.

VMSS gives us:

```text
Scalability
Instance replacement
Consistent configuration
Better availability
Support for backend pool integration
```

Application Gateway backend pools connect directly to the VMSS network interfaces. We intentionally removed internal load balancers from each spoke, because Application Gateway can send traffic directly to the VMSS backend pool.

This simplifies the architecture:

```text
Application Gateway -> VMSS
```

instead of:

```text
Application Gateway -> Internal Load Balancer -> VMSS
```

## Cloud-Init Bootstrap

The VMSS instances are configured using cloud-init.

Cloud-init installs:

```text
ca-certificates
curl
git
gnupg
nginx
Node.js 20
```

Then it clones the application repositories, runs `npm install`, creates a systemd service, and creates an Nginx reverse proxy configuration.

For Organic:

```text
Repo: https://github.com/Msocial123/organic-ghee.git
App port: 5656
Start command: node src/app.js
Database: restorent
```

For Fitness:

```text
Repo: https://github.com/Msocial123/Fitness_Tracker.git
App port: 5000
Start command: npm start
Database: fitness-tracker
```

Cloud-init also injects the Cosmos MongoDB connection string into the service environment:

```text
MONGODB_URI
MONGO_URI
DATABASE_NAME
```

This allows the applications to connect to Cosmos DB instead of using a local MongoDB server.

## Terraform Structure

The Terraform code is modular.

The root configuration calls these modules:

```text
modules/network
modules/application_gateway
modules/compute
modules/cosmosdb
```

The `network` module creates:

```text
Hub VNet
Organic spoke VNet
Fitness spoke VNet
Subnets
VNet peerings
Azure Firewall
Azure Bastion
Route tables
NSGs
Public IPs for Firewall and Bastion
```

The `application_gateway` module creates:

```text
Application Gateway WAF_v2
Application Gateway public IP
WAF policy
HTTP listeners
Backend pools
Routing rules
Health probes
Backend HTTP settings
```

The `compute` module creates:

```text
Organic VMSS
Fitness VMSS
VMSS NIC backend pool attachment
Cloud-init custom data
Systemd service configuration
Nginx reverse proxy setup
```

The `cosmosdb` module creates:

```text
Cosmos DB Mongo API account
Mongo databases
Private endpoints
Private DNS zone
Private DNS VNet links
```

The root `outputs.tf` exposes useful values such as:

```text
Application Gateway public IP
Firewall public IP
Bastion public IP
Cosmos DB account name
Cosmos Mongo connection string
VMSS IDs
DNS A record values
```

The sensitive Cosmos DB connection string is marked as sensitive so Terraform does not print it automatically.

## Why Terraform

Terraform was chosen because it makes the infrastructure repeatable and version-controlled. Instead of manually creating resources in the Azure Portal, the entire architecture is described as code.

This gives us:

```text
Consistency
Repeatability
Easy updates
Modular design
Git-based tracking
Reduced manual mistakes
```

If the environment needs to be recreated, Terraform can deploy the same architecture again.

## Current Limitations and Future Improvements

The current setup uses HTTP only. A future improvement is SSL termination at Application Gateway. That would require:

```text
Certificate for *.nexaflow.site or both subdomains
HTTPS listener on port 443
SSL certificate attached to Application Gateway
HTTP to HTTPS redirect
```

Another improvement is session storage. Organic currently uses in-memory sessions, which is not ideal for VMSS. Application Gateway cookie affinity helps, but the better solution is to store sessions in Redis or MongoDB.

Secrets should also be improved. The Cosmos connection string is currently passed through VMSS custom data and Terraform state. A production-grade setup should use Azure Key Vault and Managed Identity.

Finally, monitoring can be added using:

```text
Application Gateway access logs
Azure Firewall logs
VMSS diagnostics
Log Analytics
Application Insights
Cosmos DB metrics
```

## Conclusion

This architecture provides a secure and modular Azure deployment for two separate applications. Users access the applications through Application Gateway and custom DNS. The applications run privately inside VM Scale Sets in isolated spoke VNets. Outbound traffic is centralized through Azure Firewall. Administrative access is handled through Bastion. Database access is private through Cosmos DB private endpoints and private DNS.

The result is a cloud architecture that is more secure, scalable, and maintainable than a simple public VM deployment, while still being flexible enough to support future enhancements like HTTPS, centralized monitoring, autoscaling, and improved secret management.
