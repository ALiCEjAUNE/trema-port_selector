class PortSelector < Trema::Controller

  @@portlist = Array(1..3)

  def start(_args)
    logger.info 'PortSelector started.'
    puts "Select Port is #{@@portlist}"
  end

  def switch_ready(datapath_id)
    send_flow_mod_add(
    datapath_id,
      priority: 100,
      match: Match.new(destination_mac_address: '01:80:C2:00:00:00') #Drop STP Flame
    )
    logger.info "Hello switch #{datapath_id.to_hex}!"
    send_message datapath_id, Features::Request.new

    send_flow_mod_add(
       datapath_id,
       idle_timeout: 0,
       match: Match.new(ether_type: 0x0800, source_ip_address: '192.168.0.1/32' ),
       #actions: sendport
       actions: [SendOutPort.new(2),SendOutPort.new(3)] #複数action指定時などは配列
    )
    send_flow_mod_add(
       datapath_id,
       idle_timeout: 0,
       match: Match.new(
                ether_type: 0x0800,
                ip_protocol: 17, #1(ICMP),6(TCP),17(UDP)
                source_ip_address: '192.168.0.2/32',
                transport_destination_port: 5001
              ),
       #actions: sendport
       actions: [SendOutPort.new(1),SendOutPort.new(3)] #複数action指定時などは配列
    )
  end

  def packet_in(datapath_id, packet_in)
    logger.info "スイッチ#{datapath_id.to_hex}にフローエントリに該当しないパケットが到来"
    logger.info "パケットが来たポートは#{packet_in.in_port}"    
    logger.info "パケットの送信元ipは#{packet_in.source_ip_address}"
    logger.info "パケットの種類は#{packet_in.ip_protocol}"
    logger.info "パケットの宛先ポートは#{packet_in.transport_destination_port}"
    
    if packet_in.source_ip_address == '192.168.0.2' then
      puts "Flow Delete!"
      send_flow_mod_delete(
        datapath_id,
        match: Match.new()
      )
    elsif packet_in.source_ip_address == '192.168.0.3' then
      puts "Flow Add!"
      send_flow_mod_add(
        datapath_id,
        priority: 100,
        match: Match.new(destination_mac_address: '01:80:C2:00:00:00') #Drop STP Flame
      )
    end



#    send_packet_out( #Packet_outはflowを設定する最初だけパケットがコントローラに行ってしまうので、それをhostに送り返す用
#      datapath_id,
#      raw_data: packet_in.raw_data
#    )
  end

  def features_reply datapath_id, message
    message.ports.each do | each |
      puts "Port no: #{ each.number }, name: #{ each.name }"
    end
  end

end
