class PortSelector < Trema::Controller

  @@portlist = Array(1..3)

  def start(_args)
    logger.info 'PortSelector started.'
    puts "Select Port is #{@@portlist}"
  end

  def switch_ready(datapath_id)
    logger.info "Hello switch #{datapath_id.to_hex}!"
    aliveport = rand(1..3)
    puts "aliveport is #{aliveport}"

    send_message datapath_id, Features::Request.new
    
    send_flow_mod_add( datapath_id, match: Match.new(in_port: 1), actions: SendOutPort.new(aliveport) )
    send_flow_mod_add( datapath_id, match: Match.new(in_port: aliveport), actions: SendOutPort.new(1) )
  end

  def packet_in(datapath_id, packet_in)
    logger.info "スイッチ#{datapath_id.to_hex}にフローエントリに該当しないパケットが到来"
    logger.info "パケットが来たポートは#{packet_in.in_port}"    
    logger.info "パケットの送信元ipは#{packet_in.source_ip_address}"
    logger.info "パケットの種類は#{packet_in.ip_protocol}"
    logger.info "パケットの宛先ポートは#{packet_in.transport_destination_port}"
    
    if packet_in.source_ip_address == '192.168.0.4' then
      send_flow_mod_delete( datapath_id, match: Match.new() ) #すべてのフローを削除
      aliveport = rand(1..3)
      puts "aliveport is #{aliveport}"
      if packet_in.transport_destination_port == 5001 then
        aliveport = 1
      elsif packet_in.transport_destination_port == 5002 then
        aliveport = 2
      elsif packet_in.transport_destination_port == 5003 then
        aliveport = 3
      end
      send_flow_mod_add( datapath_id, match: Match.new(in_port: 1), actions: SendOutPort.new(aliveport) )
      send_flow_mod_add( datapath_id, match: Match.new(in_port: aliveport), actions: SendOutPort.new(1) )
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
