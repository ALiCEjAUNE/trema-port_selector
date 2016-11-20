require 'pio'

class PortSelector < Trema::Controller

  HOSTPORT = 1
  HOSTPORT.freeze
  LMMPORT = 5
  LMMPORT.freeze
  PORTLIST = [2,3,4]
  PORTLIST.freeze
  SWITCHLIST = [0xabd,0x111]
  SWITCHLIST.freeze
  @@setport = PORTLIST[rand(0..2)]

  def start(_args)
    logger.info 'PortSelector started.'
    logger.info "Selected port, #{PORTLIST}"
    logger.info "Switch List, #{SWITCHLIST}" 
  end

  def switch_ready(datapath_id)
    aliveport = @@setport
    logger.info "Hello switch #{datapath_id.to_hex}!"
    logger.info "aliveport is #{aliveport}"   
    ipv6_drop_flow(datapath_id)
    port_select_flow_ready(datapath_id,HOSTPORT,aliveport)
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
#        logger.info "ARP Request has arrived.#{packet_in.data}"
        arp_request = packet_in.data
        replydata = Arp::Reply.new(
                      destination_mac: arp_request.source_mac,
                      source_mac: 'dd:6c:4c:a9:7d:04',
                      sender_protocol_address: arp_request.target_protocol_address,
                      target_protocol_address: arp_request.sender_protocol_address
                    )
#       puts "replay is #{replydata}"
        send_packet_out(
          datapath_id,
          raw_data: replydata.to_binary,
          actions: SendOutPort.new(packet_in.in_port)
        )
      else
        puts "Not Arp::Request"
      end
    else       
#      rest = packet_in.rest[4..-1]
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
          port_select_flow(SWITCHLIST,packet_in, HOSTPORT,oldport,aliveport  )
        end
#        logger.info "aliveport is #{aliveport}"
    end
   end
  end
###############フローエントリ用メソッド########################33  
  def ipv6_drop_flow datapath_id
    send_flow_mod_add( datapath_id, priority: 100, match: Match.new(ether_type: 0x86dd))
  end
      
  def port_select_flow_ready datapath_id,host_port,set_port
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
      
  end

  def port_select_flow swid,packet_in,host_port,old_port,set_port
#    @@flow1_2_0800 ||= create_flow_mod_binary(1000,host_port,0x0800,PORTLIST[0]) 
#    @@flow1_3_0800 ||= create_flow_mod_binary(1000,host_port,0x0800,PORTLIST[1])     
#    @@flow1_4_0800 ||= create_flow_mod_binary(1000,host_port,0x0800,PORTLIST[2])
#    @@flow1_2_2054 ||= create_flow_mod_binary(1000,host_port,2054,PORTLIST[0]) 
#    @@flow1_3_2054 ||= create_flow_mod_binary(1000,host_port,2054,PORTLIST[1])     
#    @@flow1_4_2054 ||= create_flow_mod_binary(1000,host_port,2054,PORTLIST[2])
    @@flow1_2 ||= create_flow_mod_binary2(10,host_port,PORTLIST[0]) 
    @@flow1_3 ||= create_flow_mod_binary2(10,host_port,PORTLIST[1])     
    @@flow1_4 ||= create_flow_mod_binary2(10,host_port,PORTLIST[2])
#    @@dflow1_2_0800 ||= delete_flow_mod_binary(host_port,0x0800,PORTLIST[0]) 
#    @@dflow1_3_0800 ||= delete_flow_mod_binary(host_port,0x0800,PORTLIST[1])     
#    @@dflow1_4_0800 ||= delete_flow_mod_binary(host_port,0x0800,PORTLIST[2])
#    @@dflow1_2_2054 ||= delete_flow_mod_binary(host_port,2054,PORTLIST[0]) 
#    @@dflow1_3_2054 ||= delete_flow_mod_binary(host_port,2054,PORTLIST[1])     
#    @@dflow1_4_2054 ||= delete_flow_mod_binary(host_port,2054,PORTLIST[2])

#    swid.each do |datapath_id|
#      case old_port
#      when PORTLIST[0]
#        send_message datapath_id, @@flow1_2_0800
#        send_message datapath_id, @@flow1_2_2054
#      when PORTLIST[1]
#        send_message datapath_id, @@flow1_3_0800
#        send_message datapath_id, @@flow1_3_2054
#      when PORTLIST[2]
#        send_message datapath_id, @@flow1_4_0800
#        send_message datapath_id, @@flow1_4_2054
#      end
#    end
    
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
#    swid.each do |datapath_id|
#      send_message datapath_id, @flow_d_0800
#      send_message datapath_id, @flow_d_2054
#      case old_port
#      when PORTLIST[0]
#        send_message datapath_id, @@dflow1_2_0800
#        send_message datapath_id, @@dflow1_2_2054
#      when PORTLIST[1]
#        send_message datapath_id, @@dflow1_3_0800
#        send_message datapath_id, @@dflow1_3_2054
#      when PORTLIST[2]
#        send_message datapath_id, @@dflow1_4_0800
#        send_message datapath_id, @@dflow1_4_2054
#      end

  end
  
  private

  def create_flow_mod_binary pri,inport,ethtype,outport
    options = {
      command: :add,
      priority: pri,
      transaction_id: 0,
      idle_timeout: 0,
      hard_timeout: 0,
      buffer_id: 0xffffffff, 
      match: Match.new(in_port: inport,ether_type: ethtype),
      actions: SendOutPort.new(outport)
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

  def delete_flow_mod_binary inport,ethtype,outport
    options = {
               command: :delete,
               transaction_id: rand(0xffffffff),
               buffer_id: 0xffffffff,
               match: Match.new(in_port: inport,ether_type: ethtype),
               out_port: 0xffffffff
    }
    FlowMod.new(options).to_binary.tap do |flow_mod| 
      def flow_mod.to_binary
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

