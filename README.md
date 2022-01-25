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

First we will launch two docker containers **doc1** and **doc2** from host1 and define two networks for them respectively. Spawn container by below command:

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
  
###### Now, attach **net1** into container "doc1" with IP configuration by below:

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
  
###### Now, attach **net2** into container "doc2" with IP configuration by below:

  sudo ovs-docker add-port br2 eth0 doc2 --ipaddress=10.0.2.10/24 --gateway=10.0.2.1
  
We can now investigate our bridge interface and port status by below command:

  sudo ovs-vsctl show
  
![1](https://user-images.githubusercontent.com/22352861/150959364-336f76ac-126c-49b6-afcd-fe2276cede4b.JPG)

Also, if we check from host machine then we will see that OVS internal ports will be shown as network interface along with their IP. We have confugured gateway IP **10.0.1.1** & **10.0.2.1** on these interfaces. These gateway interfaces will also used by another host's containers bacause we will have pure layer 2 connectivity between them. 

![2](https://user-images.githubusercontent.com/22352861/150960915-f5d0c5e6-76cf-406f-97da-7b0ead757eaa.JPG)
  
  
