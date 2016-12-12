#sudo ifconfig eth0 up
sudo ifconfig eth1 up
sudo ifconfig eth2 up
sudo ifconfig eth3 up
#sudo ovs-vsctl add-port br0x111 eth0
sudo ovs-vsctl add-port br0x111 eth1
sudo ovs-vsctl add-port br0x111 eth2
sudo ovs-vsctl add-port br0x111 eth3
#sudo ovs-vsctl add-port  br0xaaa nichost6 -- set interface nichost6 ofport=2
sudo ovs-ofctl show br0x111
