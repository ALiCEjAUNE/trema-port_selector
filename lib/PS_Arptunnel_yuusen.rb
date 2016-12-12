require 'pio'

class PortSelector < Trema::Controller

  HOSTPORT = 1
  HOSTPORT.freeze
  LMMPORT = 1
  LMMPORT.freeze
  VHOSTPORT = 2
  VHOSTPORT.freeze
  ARPPORT = 2
  ARPPORT.freeze
  PORTLIST = [3,4,5]
  PORTLIST.freeze
  SWITCHLIST = [0xaaa,0x111,0x222]
  SWITCHLIST.freeze
  MACLIST = ['00:90:fe:f2:e3:d1','00:90:fe:f2:e3:85','00:90:fe:f2:df:d1','00:90:fe:f2:e3:cd','00:90:fe:f2:df:cd']
  @@setport = PORTLIST[rand(0..2)]
  def start(_args)
    @@flow1_2 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[0]) 
    @@flow1_3 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[1])     
    @@flow1_4 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[2])
    @@flow1_2_0x111 ||= create_flow_mod_binary(10,HOSTPORT,PORTLIST[0],MACLIST[0]) 
#    @@flow1_3_0x111 ||= create_flow_mod_binary(10,HOSTPORT,PORTLIST[1],MACLIST[1])     
    @@flow1_3_0x111 ||= create_flow_mod_binary2(10,HOSTPORT,PORTLIST[1]) 
    @@flow1_4_0x111 ||= create_flow_mod_binary(10,HOSTPORT,PORTLIST[2],MACLIST[2])

    logger.info 'PortSelector started.'
    logger.info "Selected port, #{PORTLIST}"
    logger.info "Switch List, #{SWITCHLIST}"
  end

  def switch_ready(datapath_id)
    aliveport = @@setport
    case datapath_id
    when SWITCHLIST[0]
      forlmmpc_flow(datapath_id,LMMPORT,VHOSTPORT)
      ipv6_drop_flow(datapath_id)
    when SWITCHLIST[2]
      port_select_flow_ready(datapath_id,HOSTPORT,aliveport,ARPPORT)
      ipv6_drop_flow(datapath_id)
    end
#    arp_resolution_flow(SWITCHLIST[0],LMMPORT,VHOSTPORT)
    logger.info "Hello switch #{datapath_id.to_hex}!"
    logger.info "aliveport is #{aliveport}"

  end

  def packet_in(datapath_id, packet_in)
#   putlog(datapath_id,packet_in)
#   unless packet_in.in_port == LMMPORT then
     logger.info "パケット到来! #{datapath_id.to_hex} #{packet_in.in_port}"
#   end

   if datapath_id == SWITCHLIST[1] && packet_in.in_port != HOSTPORT && packet_in.source_mac != MACLIST[0] && packet_in.source_mac != MACLIST[1] && packet_in.source_mac != MACLIST[2] && packet_in.source_mac != MACLIST[3] && packet_in.source_mac != MACLIST[4] && packet_in.source_mac != MACLIST[2]
     port_select_flow_ready2(datapath_id,HOSTPORT,@@setport,ARPPORT,packet_in.source_mac)
     puts "HOST2のmacアドレスを学習しました。 #{packet_in.source_mac} "
   else
     puts "HOST1からのパケットです。"
   end

   if packet_in.in_port == LMMPORT then
    case packet_in.ether_type
    when 34525
      puts "IPv6,dropped. #{packet_in.ether_type}"
    when 2054
      case packet_in.data
      when Arp::Request
        logger.info "ARP Request has arrived.#{packet_in.in_port}"
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
     send_flow_mod_add( datapath_id, priority: 2, match: Match.new())
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


      
  def port_select_flow_ready datapath_id,host_port,set_port,arp_port
      PORTLIST.each do |port|
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: port),
                         actions: SendOutPort.new(host_port))
      end
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port),
                         actions: SendOutPort.new(set_port))
        send_flow_mod_add( datapath_id,
                         priority: 11,
                         match: Match.new(in_port: host_port, ether_type: 0x0806),
                         actions: SendOutPort.new(arp_port))      
        send_flow_mod_add( datapath_id,
                         priority: 11,
                         match: Match.new(in_port: arp_port, ether_type: 0x0806),
                         actions: SendOutPort.new(host_port))   

  end

  def port_select_flow_ready2 datapath_id,host_port,set_port,arp_port,mac_add
      PORTLIST.each do |port|
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: port),
                         actions: [SetSourceMacAddress.new(mac_add),SendOutPort.new(host_port)])
      end
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: 4),
                         actions: SendOutPort.new(host_port))
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port),
                         actions: SendOutPort.new(set_port))
        send_flow_mod_add( datapath_id,
                         priority: 11,
                         match: Match.new(in_port: host_port, ether_type: 0x0806),
                         actions: SendOutPort.new(arp_port))      
        send_flow_mod_add( datapath_id,
                         priority: 11,
                         match: Match.new(in_port: arp_port, ether_type: 0x0806),
                         actions: SendOutPort.new(host_port))   

  end


  def port_select_flow swid,packet_in,host_port,old_port,set_port
     datapath_id = swid[1]
     datapath_id2 = swid[0]
      case set_port
      when PORTLIST[0]
        send_message datapath_id, @@flow1_2
        send_message datapath_id2, @@flow1_2_0x111
      when PORTLIST[1]
        send_message datapath_id, @@flow1_3
        send_message datapath_id2, @@flow1_3_0x111
      when PORTLIST[2]
        send_message datapath_id, @@flow1_4
        send_message datapath_id2, @@flow1_4_0x111
      end
    end
#  end
  
  private

  def create_flow_mod_binary pri,inport,outport,mac_add
    options = {
      command: :add,
      priority: pri,
      transaction_id: 0,
      idle_timeout: 0,
      hard_timeout: 0,
      buffer_id: 0xffffffff,
      match: Match.new(in_port: inport),
      actions: [SetDestinationMacAddress.new(mac_add),SendOutPort.new(outport)] 
    }
    FlowMod.new(options).to_binary.tap do |flow_mod| 
      def flow_mod.to_binary
        self
      end
    end
  end


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

