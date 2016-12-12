sudo ip netns add host6
sudo ip link add name nichost6 type veth peer name nhost6
sudo ip link set dev nhost6 netns host6
sudo ip netns exec host6 ifconfig lo 127.0.0.1
sudo ip netns exec host6 ifconfig nhost6 192.168.11.241
sudo ifconfig nichost6 up
