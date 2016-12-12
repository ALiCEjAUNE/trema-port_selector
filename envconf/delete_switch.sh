
sudo ovs-vsctl del-br br0xaaa
sudo ovs-vsctl del-br br0x111
sudo ovs-vsctl del-br br0x222
sudo rm /tmp/*.pid
#ip netns | xargs -I {} sudo ip netns delete {}
sudo ip -all netns delete
