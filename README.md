# Extending multiple container networks using VXLAN tunnel
In this experiment, we will create multiple docker network and extend over layer 3 isolation. We will achieve this goal by creating VXLAN tunnel between docker host. In this lab three virtual machines will be used. We will configure multiple distributed network between two docker host VMs. Another VM will be used as a gateway router. 

# Requirements:
  **VM1: GW Router**\
  **VM2: Docker Host1 (172.16.10.100/24)**\
  **VM3: Docker Host2 (172.16.20.100/24)**
  
# Scenario:
Here, docker host1 is in **172.16.10.0/24** and docker host2 in **172.16.20.0/24** network. They are in completely different network as separated by layer 3. In this lab we won’t use any docker network driver but instead configure our own. We will need bridge interface on each host connects with associated container network. In that case Open vSwitch (**OVS**) will be used. **OVS** is a very powerful multilayer virtual switch. Although, we can build this configuration using **Linux native bridges**. We will build two internal network **( net1: 10.0.1.0/24  and net2: 10.0.2.0/24 )** on each docker host and establish layer 2 connectivity between them. We will achieve this by creating **VXLAN** tunnel between these nodes. We will create two tunnels for **net1** and **net2**. Also, we will provide internet connectivity on these networks and do some troubleshooting. So, our distributed container network will look like this.

![Untitled Diagram](https://user-images.githubusercontent.com/22352861/151148393-ebb3f93c-ea09-474a-8daa-16ce2de64cee.jpg)
  
# Environment Setup:
We will create a custom docker image on both nodes for this lab. So, it will be easy for us to test and troubleshoot issue. We can create docker image from Dockerfile. I have added required files in this repository. We will build custom image named **con_img** with below command:

  docker build -t con_img .

# Container Network Specifications:
  **net1: 10.0.1.0/24**\
  **net2: 10.0.2.0/24**
  
# Overlay Network Configurations:

### Docker Host1 (172.16.10.100):

First we launch two docker containers **doc1** and **doc2** from host1 and after that we will define two separate networks for them. Spawn containers using below commands:

  docker run -di --net none --name doc1 con_img\
  docker run -di --net none --name doc2 con_img 
  
We didn't use any docker network driver above by adding **--net none** option. For creating and connecting our own container network **(net1 & net2)** we need to have bridge interface in docker host machine. We will create two bridge interface for these networks.

#### Create first bridge **br1** for **net1**:

  sudo ovs-vsctl add-br br1

###### Create internal port **net1** under bridge **br1**:

  sudo ovs-vsctl add-port br1 net1 -- set interface net1 type=internal
  
###### Assign gateway IP to **net1** internal port:

  sudo ifconfig net1 10.0.1.1 netmask 255.255.255.0 up
  
###### Create VXLAN tunnel port **vxlan1** for **net1**:

  sudo ovs-vsctl add-port br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=172.16.20.100 options:key=5000
  
###### "**ovs-docker**" is a powerful command. With this we can easily create virtual interface in container network namespace and connect with bridge interface.

###### Now, attach **net1** into container **doc1** with IP configuration by below command:

  sudo ovs-docker add-port br1 eth0 doc1 --ipaddress=10.0.1.10/24 --gateway=10.0.1.1

###### Same way we will create another bridge and internal port for **net2**.

#### Create second bridge **br2** for **net2**:

  sudo ovs-vsctl add-br br2

###### Create internal port **net2** under bridge **br2**:

  sudo ovs-vsctl add-port br2 net2 -- set interface net2 type=internal
  
###### Assign gateway IP to **net2** internal port:

  sudo ifconfig net2 10.0.2.1 netmask 255.255.255.0 up
  
###### Create VXLAN tunnel port **vxlan2** for **net2**:

  sudo ovs-vsctl add-port br2 vxlan2 -- set interface vxlan2 type=vxlan options:remote_ip=172.16.20.100 options:key=6000
  
###### Now, attach **net2** into container **doc2** with IP configuration by below command:

  sudo ovs-docker add-port br2 eth0 doc2 --ipaddress=10.0.2.10/24 --gateway=10.0.2.1
  
We can now investigate our bridge interface and port status by below command:

  sudo ovs-vsctl show
  
![1](https://user-images.githubusercontent.com/22352861/150959364-336f76ac-126c-49b6-afcd-fe2276cede4b.JPG)

Also, if we check from host machine then we will see that OVS internal ports will be shown as network interface along with their IP. We have configured gateway IP **10.0.1.1** & **10.0.2.1** on these interfaces. These gateway interfaces will also be used by another host's containers because we will have pure layer 2 connectivity between them. 

![2](https://user-images.githubusercontent.com/22352861/150960915-f5d0c5e6-76cf-406f-97da-7b0ead757eaa.JPG)

#### NAT for Internet connectivity:
If we want to enable internet connectivity for **net1** & **net2**, then first we need to enable IP forwarding on host machine.

  echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf\
  sudo sysctl -p /etc/sysctl.conf
  
For outside network access (Ex: internet) from **net1**, **net2** interfaces or network, we have to configure **SNAT** or **MASQUERADE**. We will do this configuration using **iptables**. We will configure masquerad interface wise. 

###### NAT configuration for **net1**:

  sudo iptables --append FORWARD --in-interface net1 --jump ACCEPT\
  sudo iptables --append FORWARD --out-interface net1 --jump ACCEPT\
  sudo iptables --table nat --append POSTROUTING --source 10.0.1.0/24 --jump MASQUERADE
  
###### NAT configuration for **net2**:

  sudo iptables --append FORWARD --in-interface net2 --jump ACCEPT\
  sudo iptables --append FORWARD --out-interface net2 --jump ACCEPT\
  sudo iptables --table nat --append POSTROUTING --source 10.0.2.0/24 --jump MASQUERADE
 
Now we will do similar configuration on docker host2.  
  
### Docker Host2 (172.16.20.100):

First launch two docker containers **doc3** and **doc4** from host2:

  docker run -di --net none --name doc3 con_img\
  docker run -di --net none --name doc4 con_img 
  
We will extend networks (**net1** & **net2**) from docker host1 which we built previously. After creating and configuring VXLAN interface on this host, distributed layer 2 network will be established. Then containers from both nodes will be available to each other. We will configure bridge and VXLAN interfaces in similar way. We don't need internal port on this node because gateway interfaces already exist on host1.

#### Create first bridge **br1** for **net1**:

  sudo ovs-vsctl add-br br1
  
###### Create VXLAN tunnel port **vxlan1** for **net1**:

  sudo ovs-vsctl add-port br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=172.16.10.100 options:key=5000
  
  ###### Now, attach **net1** into container **doc3** with IP configuration by below:

  sudo ovs-docker add-port br1 eth0 doc3 --ipaddress=10.0.1.20/24 --gateway=10.0.1.1

#### Create second bridge **br2** for **net2**:

  sudo ovs-vsctl add-br br2
  
###### Create VXLAN tunnel port **vxlan2** for **net2**:

  sudo ovs-vsctl add-port br2 vxlan2 -- set interface vxlan2 type=vxlan options:remote_ip=172.16.10.100 options:key=6000
  
###### Now, attach **net2** into container **doc4** with IP configuration by below:

  sudo ovs-docker add-port br2 eth0 doc4 --ipaddress=10.0.2.20/24 --gateway=10.0.2.1
  
Now check bridge interface status by below command:

sudo ovs-vsctl show

![3](https://user-images.githubusercontent.com/22352861/150972911-cc5533d2-221d-4233-9eb8-156c50d397ac.JPG)
  
# Testing & Troubleshootings:
In this situation two distributed networks have been created between docker host1 and host2. We can check from containers:

![4](https://user-images.githubusercontent.com/22352861/150973927-e20b55bc-612a-43fa-9162-00763ce8c673.JPG)

![5](https://user-images.githubusercontent.com/22352861/150974005-2f430883-68a6-42a1-9940-79e4a265b9e1.JPG)

From above we see container under **net1** can communicate with each other. We will get similar result for **net2** also. 

Also, we are able to ping external network due to NAT configuration. But still there is one problem. We will face problem in network communication. We can check this by **iperf** tools:

![6](https://user-images.githubusercontent.com/22352861/150998396-467841dd-98c0-4365-9697-30e8fcf4812e.JPG)

As we use encapsulation, we get the common MTU (Maximum Transmission Unit) problem which occurs in such cases. MTU defines the maximum size of Ethernet frame which can be transmitted over the line. When MTU size is exceeded, IP packet is fragmented to the multiple packets or even gets dropped. In this case we run into the common problem of MTU size. The frame on the underlying network is bigger that standard MTU of 1500. VXLAN requires 1554 MTU size for IPv4 traffic. But typically the default value is set as 1500.

![8](https://user-images.githubusercontent.com/22352861/151002071-97b8fc37-ba61-44a1-b4bd-36bf6892849e.JPG)

In order to overcome this problem, we have to adjust MTU on the underlying network. All interfaces associated with underlying network needs to change. We can change interface MTU by below command:

  sudo ifconfig eth0 mtu 1554
  
  Now check again with **iperf** tools:

![7](https://user-images.githubusercontent.com/22352861/151004088-8531fda7-7d8d-48f0-86c2-2f77d57d4345.JPG)

We can clearly see the problem has been fixed.

# Outcomes:
In this lab, we have successfully created docker distributed network. One big advantage of using **OVS** bridge is that it can be directly accessed from physical or host network if route is available. No port forwarding is needed. This is more efficient. We can check from one of host machines:

![10](https://user-images.githubusercontent.com/22352861/151030132-ddad3f7e-ce2e-4900-847f-f62a1b627a4e.JPG)

Last but not the least, we can configure our container network in several ways as per our requirements just like we can launch container without specifying gateway then we only have layer 2 connectivity. Beside that if we want to use host network with container. We can also do that by adding physical interface into **OVS** bridge. SDN controller can also be integrated with **OVS** for switch flow control. So, possibilities are endless.

# References

[Open vSwitch (OVS)](https://docs.openvswitch.org/en/latest/howto/)

[OVS Internal Port](https://arthurchiao.art/blog/ovs-deep-dive-6-internal-port/)

[Docker Network](https://iximiuz.com/en/posts/container-networking-is-simple/)

[VXLAN](https://medium.com/@NTTICT/vxlan-explained-930cc825a51)

[VXLAN in OVS](https://docs.openvswitch.org/en/latest/howto/userspace-tunneling/)

[VXLAN MTU Considerations](https://oswalt.dev/2014/03/mtu-considerations-for-vxlan/)

[iptables](https://dustinspecker.com/posts/iptables-how-docker-publishes-ports/)
