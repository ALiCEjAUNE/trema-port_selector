require 'pio'

class PortSelector < Trema::Controller

  HOSTPORT = 1
  HOSTPORT.freeze
  LMMPORT = 1
  LMMPORT.freeze
  VHOSTPORT = 2
  VHOSTPORT.freeze
  PORTLIST = [2,2,2]
  PORTLIST.freeze
  SWITCHLIST = [0xaaa,0x111,0x222]
  SWITCHLIST.freeze
  @@setport = PORTLIST[rand(0..2)]

  def start(_args)
    @@flow1_2 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[0]) 
    @@flow1_3 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[1])     
    @@flow1_4 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[2])
    logger.info 'PortSelector started.'
    logger.info "Selected port, #{PORTLIST}"
    logger.info "Switch List, #{SWITCHLIST}"
  end

  def switch_ready(datapath_id)
    aliveport = @@setport 
    port_select_flow_ready(datapath_id,HOSTPORT,aliveport)
#    arp_resolution_flow(SWITCHLIST[0],LMMPORT,VHOSTPORT)
    forlmmpc_flow(SWITCHLIST[0],LMMPORT,VHOSTPORT)
    ipv6_drop_flow(datapath_id)
    logger.info "Hello switch #{datapath_id.to_hex}!"
    logger.info "aliveport is #{aliveport}"

  end

  def packet_in(datapath_id, packet_in)
#   putlog(datapath_id,packet_in)
   unless packet_in.in_port == LMMPORT then
     logger.info "通常ポートからパケット到来!#{packet_in.data}"
   end    
   if packet_in.in_port == LMMPORT then
    case packet_in.ether_type
    when 34525
      puts "IPv6,dropped. #{packet_in.ether_type}"
    when 2054
      case packet_in.data
      when Arp::Request
        logger.info "ARP Request has arrived.#{packet_in.data}"
        arp_request = packet_in.data
        @@arp_rep ||= create_arp_reply(arp_request)
        send_packet_out(
          datapath_id,
          raw_data: @@arp_rep,
          actions: SendOutPort.new(packet_in.in_port)
        )
      else
        puts "Not Arp::Request"
      end
    else       
        rest = packet_in.rest[4..-3]
        rest_i = rest.to_i + 2
        puts rest_i
#        puts "ip packet has arrived. #{packet_in.data}"
        oldport = @@setport
        aliveport = PORTLIST[rand(0..2)]
        case packet_in.transport_destination_port
        when 50000
          aliveport = PORTLIST[0]
        when 50001
          aliveport = PORTLIST[1]
        when 50002
          aliveport = PORTLIST[2]
        else
          logger.info "Port number is incorrect. Set random port."
        end
        @@setport = aliveport
        unless aliveport == oldport then
          port_select_flow(SWITCHLIST.slice(1..2),packet_in, HOSTPORT,oldport,aliveport  )
        end
#        logger.info "aliveport is #{aliveport}"
    end
   end
  end
###############フローエントリ用メソッド########################33  


  def ipv6_drop_flow datapath_id
#    send_flow_mod_add( datapath_id, priority: 100, match: Match.new(ether_type: 0x86dd))
#     send_flow_mod_add( datapath_id, priority: 2, match: Match.new())
  end
  def forlmmpc_flow datapath_id,lmm_port,vhost_port
    send_flow_mod_delete(datapath_id, match: Match.new())
    ipv6_drop_flow(datapath_id)
    send_flow_mod_add( datapath_id,
                     priority: 5,
                     match: Match.new(in_port: lmm_port),
                     actions: SendOutPort.new(vhost_port))
    send_flow_mod_add( datapath_id,
                     priority: 5,
                     match: Match.new(in_port: vhost_port),
                     actions: SendOutPort.new(lmm_port))
#    send_flow_mod_add( datapath_id,  #vhostが繋がるポートからのIPv4パケットは落とす
#                     priority: 5,
#                     match: Match.new(in_port: vhost_port, ether_type: 0x0800))
    send_flow_mod_add( datapath_id, #UDPだけ意図的にpacket in
                     priority: 7,
                     match: Match.new(in_port: lmm_port, ether_type: 0x0800, ip_protocol: 17, transport_destination_port: 50000),
                     actions: SendOutPort.new(:controller))
    send_flow_mod_add( datapath_id,
                     priority: 7,
                     match: Match.new(in_port: lmm_port, ether_type: 0x0800, ip_protocol: 17, transport_destination_port: 50001),
                     actions: SendOutPort.new(:controller))
    send_flow_mod_add( datapath_id,
                     priority: 7,
                     match: Match.new(in_port: lmm_port, ether_type: 0x0800, ip_protocol: 17, transport_destination_port: 50002),
                     actions: SendOutPort.new(:controller))   
  end

  def port_select_flow_ready datapath_id,host_port,set_port
      i = 0
      PORTLIST.each do |port|
        send_flow_mod_add( datapath_id,
                         priority: 10+i,
                         match: Match.new(in_port: port),
                         actions: SendOutPort.new(host_port))
        send_flow_mod_add( datapath_id,
                         priority: 13+i,
                         match: Match.new(in_port: port, ether_type: 0x0800),
                         actions: SendOutPort.new(host_port))

#        i+=1
      end
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port),
                         actions: SendOutPort.new(set_port))
        send_flow_mod_add( datapath_id,
                         priority: 11,
                         match: Match.new(in_port: host_port, ether_type: 0x0800),
                         actions: SendOutPort.new(set_port))
  end

  def port_select_flow swid,packet_in,host_port,old_port,set_port 
    swid.each do |datapath_id|
      case set_port
      when PORTLIST[0]
        send_message datapath_id, @@flow1_2
      when PORTLIST[1]
        send_message datapath_id, @@flow1_3
      when PORTLIST[2]
        send_message datapath_id, @@flow1_4
      end
    end
  end
  
  private

  def create_flow_mod_binary2 pri,inport,outport
    options = {
      command: :add,
      priority: pri,
      transaction_id: 0,
      idle_timeout: 0,
      hard_timeout: 0,
      buffer_id: 0xffffffff,
      match: Match.new(in_port: inport),
      actions: SendOutPort.new(outport)
    }
    FlowMod.new(options).to_binary.tap do |flow_mod| 
      def flow_mod.to_binary
        self
      end
    end
  end

  def create_arp_reply arp_request
    Arp::Reply.new(
      destination_mac: arp_request.source_mac,
      source_mac: 'dd:6c:4c:a9:7d:04',
      sender_protocol_address: arp_request.target_protocol_address,
      target_protocol_address: arp_request.sender_protocol_address
      ).to_binary.tap do |arp_reply|
      def arp_reply.to_binary
        self
      end
    end
  end

  def putlog datapath_id,packet_in
    logger.info "スイッチ#{datapath_id.to_hex}にフローエントリに該当しないパケットが到来"
    logger.info "パケットが来たポートは#{packet_in.in_port}"    
    logger.info "パケットの中身は#{packet_in.data}"
    logger.info "パケットの送信元macは#{packet_in.source_mac}"
    logger.info "パケットの種類は#{packet_in.ip_protocol}"
    logger.info "パケットの宛先ポートは#{packet_in.transport_destination_port}"
    logger.info"#{datapath_id.to_hex},#{packet_in.in_port},#{packet_in.ether_type} ar"
  end
end

