# Extending multiple Docker network using VXLAN tunneling 
In this experiment, we will create multiple docker network and extend over layer 3 isolation. We will achive this by creating VXLAN tunnel between docker host. In this lab three virtual machines will be used. We will configure multiple distributed network between two docker host VMs. Another VM will be used as a gateway router. 

# Requirements:
  **VM1: GW Router**\
  **VM2: Docker Host1 (172.16.10.100/24)**\
  **VM3: Docker Host2 (172.16.20.100/24)**
  
# Scenario:
Here, docker host1 is in **172.16.10.100/24** and docker host2 in **172.16.20.100/24** network. They are in completely different network as separated by layer 3. In this lab we won’t use any docker network driver but instead configure our own. We will need bridge interface on each host connects with associated container network. In that case Open vSwitch (**OVS**) will be used. We will built two internal network **( net1: 10.0.1.0/24  and net2: 10.0.2.0/24)** on each docker host and establish layer 2 connectivity between them. We will achieve this by creating **VXLAN** tunnel between these node. We will create two tunnels for **net1** and **net2**. Also, we will provide internet connectivity on these network and do some troubleshooting. So, our distributed docker network will be look like this.

![diag-1](https://user-images.githubusercontent.com/22352861/150917568-49c37c6a-6b05-4767-a42c-bb7eb9156f1f.jpg)
  
# Environment Setup:
We will create a custom docker image on both node for this lab. So, it will be easy for us to test and troubleshoot issue. We can create docker image from Dockerfile. I have added required files in this repository. We will build custom image named **con_img** by below command:

  docker build -t con_img .

# Container Network Specifications:
  **net1: 10.0.1.0/24**\
  **net2: 10.0.2.0/24**
  
# Overlay Network Configuration:

### Docker Host1 (172.16.10.100):

First we launch two docker containers **doc1** and **doc2** from host1 and after that we will define two separate networks for them. Spawn container by below command:

  docker run -di --net none --name doc1 con_img\
  docker run -di --net none --name doc2 con_img 
  
We didn't use any docker network driver above by adding **--net none** option. For creating and connnecting our own container network **(net1 & net2)** we need to have bridge in docker host machine. We will create two bridge interface for these networks.

#### Create first bridge **br1** for **net1**:

  sudo ovs-vsctl add-br br1

###### Create internal port **net1** under bridge **br1**:

  sudo ovs-vsctl add-port br1 net1 -- set interface net1 type=internal
  
###### Assign gateway IP to **net1** internal port:

  sudo ifconfig net1 10.0.1.1 netmask 255.255.255.0 up
  
###### Create VXLAN tunnel port **vxlan1** for **net1**:

  sudo ovs-vsctl add-port br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=172.16.20.100 options:key=5000
  
###### Now, attach **net1** into container **doc1** with IP configuration by below:

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
  
###### Now, attach **net2** into container **doc2** with IP configuration by below:

  sudo ovs-docker add-port br2 eth0 doc2 --ipaddress=10.0.2.10/24 --gateway=10.0.2.1
  
We can now investigate our bridge interface and port status by below command:

  sudo ovs-vsctl show
  
![1](https://user-images.githubusercontent.com/22352861/150959364-336f76ac-126c-49b6-afcd-fe2276cede4b.JPG)

Also, if we check from host machine then we will see that OVS internal ports will be shown as network interface along with their IP. We have confugured gateway IP **10.0.1.1** & **10.0.2.1** on these interfaces. These gateway interfaces will also used by another host's containers bacause we will have pure layer 2 connectivity between them. 

![2](https://user-images.githubusercontent.com/22352861/150960915-f5d0c5e6-76cf-406f-97da-7b0ead757eaa.JPG)

#### NAT for Internet connectivity:
If we want to enable internet connectivity for **net1** & **net2** network then first we need to enable IP forwarding on host machine.

  echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf\
  sudo sysctl -p /etc/sysctl.conf
  
For outside network access (Ex: internet) from **net1**, **net2** interfaces or network, we have to configure **SNAT** or **Masquerad**. We will do this configuration using **iptables**. We will configure masquerad interface wise. 

###### NAT configuration for **net1**:

  sudo iptables --append FORWARD --in-interface net1 --jump ACCEPT\
  sudo iptables --append FORWARD --out-interface net1 --jump ACCEPT\
  sudo iptables --table nat --append POSTROUTING --source 10.0.1.0/24 --jump MASQUERADE
  
###### NAT configuration for **net2**:

  sudo iptables --append FORWARD --in-interface net2 --jump ACCEPT\
  sudo iptables --append FORWARD --out-interface net2 --jump ACCEPT\
  sudo iptables --table nat --append POSTROUTING --source 10.0.2.0/24 --jump MASQUERADE
 
Now we will do similar configuration on docker host2.  
  
### Docker Host1 (172.16.20.100):

First launch two docker containers **doc3** and **doc4** from host2:

  docker run -di --net none --name doc3 con_img\
  docker run -di --net none --name doc4 con_img 
  
We will extend networks (**net1** & **net2**) from docker host1 which we build previously. After creating and configuring VXLAN interface on this host, distributed layer 2 network will be established. Then containets from both nodes will be available to each others. We will configure bridge, internal port and VXLAN interfaces in similar way. We don't need internal port on this node because gateway interfaces already exist on host1.

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
  
# Testing & Troubleshooting:
In this situation two distributed netork has been formed between docker hoat1 and host2. We can check:


