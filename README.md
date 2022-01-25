# Extending multiple Docker layer 2 network using VXLAN tunneling 
In this experiment, we will create multiple docker network and extend over layer 3 isolation. We will achive this by creating VXLAN tunnel between docker host. In this lab three virtual machines will be used. We will configure multiple distributed network between two docker host VM. Another VM will be used as a gateway router. 

# Requirements:
  **VM1: GW Router**\
  **VM2: Docker Host1 (172.16.10.100/24)**\
  **VM3: Docker Host2 (172.16.20.100/24)**
  
# Scenario:
Here, docker host1 is in **172.16.10.100/24** and docker host2 in **172.16.20.100/24** network. They are in completely different network as separated by layer 3. In this lab we won’t use any docker network driver but instead configure our own. We will need bridge interface on each host connects with associated container network. In that case Open vSwitch (**OVS**) will be used. We will built two internal network **( net1: 10.0.1.0/24  and net2: 10.0.2.0/24)** on each docker host and establish layer 2 connectivity between them. We will achieve this by creating **VXLAN** tunnel between these node. We will create two tunnels for **net1** and **net2**. Also, we will provide internet connectivity on these network and do some troubleshooting. So, our distributed docker network will be look like this.

![diag-1](https://user-images.githubusercontent.com/22352861/150917568-49c37c6a-6b05-4767-a42c-bb7eb9156f1f.jpg)
  
  
  
