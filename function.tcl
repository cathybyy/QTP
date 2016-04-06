# Copyright (c) Ixia technologies 2015-2016, Inc.
# Author: Tim
# Release Version 1.7
#===============================================================================
# Change made
# Version 1.0 
#       1. Create    Jan. 28 2016
#       2. modify add multi chas

set mac 00:d0:b0:11:01:00
set currDir [file dirname [info script]]
set tDir [file dirname $currDir]
# set timeVal  [ clock format [ clock seconds ] -format %Y%m%d%H%M%S]
# set resPath "$tDir/Tcl/Results/$timeVal"
# puts "result path:$resPath"
# file mkdir $resPath
# set resfilepath "$resPath/QTP.log"
# set resfile [open $resfilepath a+]
# close $resfile


# IsIPv4Address --
#   Error codes : TRUE(1)     success
#                 FALSE (0)    no match
#   Error condition :
#               1.Doesnot match A.B.C.D
#               2.{ A B C D }'s element is not an Integer between 0 and 255
proc IsIPv4Address { value } {
    puts "Judgement: ipv4 address format"
    if { [ regexp -nocase {(\d+)\.(\d+)\.(\d+)\.(\d+)} $value ip a b c d ] } {
        puts "Is Ipv4 address..."
        if { ( $a > 255 ) || ( $b > 255 ) || ( $c > 255 ) || ( $d > 255 ) } {
            return 0
        }
        return 1
    } else {
        puts "Invalid ipv4 format"
        return 0
    }
}

# IsIPv6Address --
#   Error codes : TRUE(1)     success
#                 FALSE (0)    no match
#   Error condition :
#               1.Doesnot match A:B:C:D:E:F:G:H
#               2.{ A B C D }'s element is not an sign which in the set [0-9a-f]   
proc IsIPv6Address { value } {
    set flag 1
    set hexList [ split $value ":" ]
    if { [ llength $hexList ] == 8 } {
        foreach hex $hexList {
            if { [ IsHex $hex ] == 0 } {
                set flag 0
                break
            }
        }
    } else {
        set index [ string first "::" $value ]
        if { $index < 0 } {
            return 0
        }
      
        set hexList [ split $value ":" ]
        foreach hex $hexList {
			if { $hex == "" } {
				continue
			}
			if { [ IsHex $hex ] == 0 } {
				set flag 0
				break
			}
        }

    }
    return $flag

}

#=========================================================================================
#process name:		GetRealPort
#function:			Check whether the chassis & card % ports exist or not, if exist, then check
#					whether the ports can be reserved or not, if not, do cleanowner with the ports.
#args description:	port_list: the port list used in the test.
#return value:		if chassis and card exist, return the new port list in format 
#					$chassis/card:$card/port:$port, else return "ixNet getNull".
#author:			Tim
#modification record:
#=========================================================================================
proc GetRealPort { port_list } {
	set result ""
set initProgress 10
set portProgressVolume [ expr round(20 / [llength $port_list]) ]
	foreach value $port_list {
puts "$initProgress"	
set initProgress [expr $initProgress + $portProgressVolume ]
# puts "value:$value"	
		regexp {(.*):(.*):(.*)} $value np chassis card port
		puts "chassis : $chassis; card : $card; port : $port"
				
		set root [ixNet getRoot]
		if {[llength [ixNet getList $root/availableHardware chassis]  ] == 0} {
			set chas [ixNet add $root/availableHardware chassis]
			ixNet setA $chas -hostname $chassis
			ixNet commit
			set chas [ixNet remapIds $chas]
		} else {
		    set findChas 0
			set chasList [ixNet getList $root/availableHardware chassis]
            foreach chas $chasList {
			    set hostname [ixNet getA $chas -hostname]
                if {$hostname == $chassis} {
                    set findChas 1    
					break
                }
            }
			if { $findChas == 0 } {
			    set chas [ixNet add $root/availableHardware chassis]
				ixNet setA $chas -hostname $chassis
				ixNet commit
				set chas [ixNet remapIds $chas]
			}                           
           
		}
	
		set chassis $chas
# puts "chas:$chas"		
		set realCard $chassis/card:$card
		set cardList [ixNet getL $chassis card]
		set findCard 0
# puts "card list :$cardList"		
		foreach ca $cardList {
			eval set ca $ca
			eval set realCard $realCard
# puts "ca:$ca realCard:$realCard"			
			if {$ca == $realCard} {
				set findCard 1
				break
			}
		}
		if {$findCard == 0} {
			return [ixNet getNull]
		}
		set realPort $chassis/card:$card/port:$port
		set portList [ixNet getL $chassis/card:$card port]
		set findPort 0
		foreach po $portList {
			eval set po $po
			eval set realPort $realPort
			if {$po == $realPort} {
				set findPort 1
				break
			}
		}

		if {$findPort} {
			ixNet exec clearOwnership $chassis/card:$card/port:$port
			lappend result $chassis/card:$card/port:$port
		} else {
			return [ixNet getNull]
		}
	}
	return $result
}

#=========================================================================================
#process name:		IncrMacAddr
#function:			increase mac1 with step mac2.
#args description:	mac1: the mac address need to increase, format: XX:XX:XX:XX:XX:XX
#					mac2: step mac, default value: 00:00:00:00:01:00
#return value:		mac address after increasing. 
#author:			Tim
#modification record:
#=========================================================================================
proc IncrMacAddr { mac1 { mac2 00:00:00:00:01:00 } } {

	set mac1List [ split $mac1 ":" ]
	set mac2List [ split $mac2 ":" ]
	set macLen [ llength $mac1List ]
	
	set macResult 	""
	set flagAdd		0
	for { set index $macLen } { $index > 0 } { incr index -1 } {
		set eleIndex  	[ expr $index -1 ]
		set mac1Ele 	[ lindex $mac1List $eleIndex ]
		set mac2Ele		[ lindex $mac2List $eleIndex ]
		set macAdd 		[ format %x [ expr 0x$mac1Ele + 0x$mac2Ele ] ]
		if { $flagAdd } {
			scan $macAdd %x macAddD
			incr macAddD $flagAdd
			set macAdd [ format %x $macAddD ]
		}
		if { [ string length $macAdd ] > 2 } {
			set flagAdd	1
			set macAdd [ string range $macAdd [ expr [ string length $macAdd ] - 2 ] end ]
		} else {
			set flagAdd 0
		}
		# set macTrans [ expr round(fmod($macAdd,16)) ]
# Deputs "macTrans:$macTrans"
		# set macTrans [ format %x $macTrans ]
# Deputs "macTrans hex:$macTrans"
		if { [ string length $macAdd ] == 1 } {
			set macAdd "0$macAdd"
		}
		set macResult ":$macAdd$macResult"
		}
	return [ string range $macResult 1 end ]
}

#=========================================================================================
#process name:		AddProtocol
#function:			add protocol for each port base on the type, if protocol is mac, then add
#					lan for each port, if prototol if IPv4 or IPv6, add interface for each port.
#args description:	protocol: type of protocol, "MAC" "IPv4" or "IPv6"
#return value:		return the handle list of the protocol 
#author:			Tim
#modification record:
#=========================================================================================
proc AddProtocol {protocol} {

	global mac
	set root [ixNet getRoot]
	set port_handle [ixNet getL $root vport]
	if {$protocol == "MAC"} {
		foreach p_handle $port_handle {
			set lan_handle [ixNet add $p_handle/protocols/static lan]
			ixNet commit
			set lan_handle [ixNet remapIds $lan_handle]
			ixNet setMultiAttribute $lan_handle -enableIncrementMac false \
												-enabled true \
												-mac $mac
			set mac [IncrMacAddr $mac "00:00:00:00:01:00"]
			ixNet commit
			lappend lan $lan_handle
			
		}
		return $lan
	} elseif {$protocol == "IPv4"} {
		foreach p_handle $port_handle {
			set interf [ixNet add $p_handle interface]
			ixNet commit
			set interf [ixNet remapIds $interf]
#puts $interf
			ixNet setA $interf -enabled true
			ixNet add $interf ipv4
			ixNet commit
			lappend interface $interf
			
		}
		return $interface
	} else {
		foreach p_handle $port_handle {
			set interf [ixNet add $p_handle interface]
			ixNet commit
			set interf [ixNet remapIds $interf]
			ixNet setA $interf -enabled true
			ixNet add $interf ipv6
			ixNet commit
			lappend interface $interf
			
		}
		return $interface
	}
}

#=========================================================================================
#process name:		AddTrafficItem
#function:			add trafficItem, set name and type of them.
#args description:	
#					element: handle list of every QT
#					protocol: type of protocol, "ethernetVlan" "ipv4" or "ipv6"
#					lan: handle list of protocol(with protocol type "mac")
#					interface: handle list of protocol(with protocol type "ipv4" or "ipv6")
#
#return value:		return handld of the trafficItem.
#author:			Tim
#modification record:
#=========================================================================================
proc AddTrafficItem {element protocol lan interface} {
	set root [ixNet getRoot]
	
	set test_cfg [ixNet getL $element testConfig]
	
	if {$protocol == "ethernetVlan"} {
		ixNet setA $test_cfg -protocolItem $lan
	} else {
		ixNet setA $test_cfg -protocolItem $interface
	}
	
	ixNet commit
	# ixNet setA $element/frameData -trafficType $protocol
	# ixNet commit
	set tra [ixNet add $root/traffic trafficItem]
	ixNet setA $tra -name "QT-$element"
	ixNet commit
	set traffic [ixNet remapIds $tra]
	ixNet setA $traffic -trafficType $protocol
	ixNet commit
	return $traffic
}

#=========================================================================================
#process name:		QTP_ChasInfo
#function:			get the chassis information.
#args description:	chassis: the ip address of the chassis.
#return value:		if can't connect to the chassis, puts error message:
#						"<error>|msg=fail to connect to chassis"
#					if success, return the information of the chassis.
#author:			Tim
#modification record:
#=========================================================================================
proc QTP_ChasInfo { chassis } {
    if { [ catch {

		
		set success 1	
		puts "chassis:$chassis"


		ixConnectToTclServer $chassis
		set result [ixConnectToChassis $chassis]
		puts "connect to chassis:$result"
		if { $result } {
			puts "<error>|msg=fail to connect to chassis"
			set success 0
		}
		
		if { $success } {
			chassis get $chassis
			set chasId [ chassis cget -id ]
			set osVersion [ chassis cget -ixServerVersion ]
			set maxCardNumber [ chassis cget -maxCardCount ]
          
			set cardNumber 0
			for { set cIndex 1 } { $cIndex <= $maxCardNumber } { incr cIndex } {
				set result [card get $chasId $cIndex]
				if { $result } {
					continue
				}
				incr cardNumber
				set sn [card cget -serialNumber ]
				#LM Serial Number 082856 Assembly Number 860-1229-16 Revision G
				set typeName [card cget -typeName]
				# 10/100/1000 LSM XMV12	
				set portCnt [card cget -portCount]
				
				
				puts "<card>|chassis=${chassis}|sn=${sn}|type=${typeName}|portCnt=${portCnt}|card=${cIndex}"
			}

			set chasSn "NA"
            set chasSn [chassis cget -serialNumber]
			
			
			puts "<chassis>|chassis=${chassis}|sn=${chasSn}|os=${osVersion}|cardCnt=${cardNumber}"
		}


		if { $success } {
			puts "ACK"
		} else {
			puts "NAK"
		}

	} err ] } {
		puts "<error>|msg=$err"
		puts "NAK"
	}

}

#=========================================================================================
#process name:		QTP_PortListSet
#function:			set vports and connect them to the real ports.
#args description:	
#					port_list: the port list used in the test.
#
#return value:		if success, return handld list of the vports.
#					if the real card is not exist, puts error information.
#author:			Tim
#modification record:
#=========================================================================================
proc QTP_PortListSet {args} {
puts "|QTP_PortListSet|"
	#set variables
	foreach {key value} $args {
		switch -exact $key {
			-port_list {
				set port_list $value
			}
		}
	}
	
	set root [ixNet getRoot]
	#check real ports
	set newport_list [GetRealPort $port_list]
	if {$newport_list == [ixNet getNull] } {
		puts "The real card is not exist!"
		puts "NAK"
		after 3000
	} else {

		foreach value $newport_list {
			set hdle [ixNet add $root vport]
			ixNet commit
			set real_hdle [ixNet remapIds $hdle]
			ixNet setA $real_hdle -connectedTo $value
			ixNet setA $real_hdle -name [lindex $port_list [lsearch $newport_list $value]] 
			ixNet commit
			ixNet setA $real_hdle/l1Config/[ixNet getA $real_hdle -type] -enabledFlowControl False
			ixNet commit
		}

        set vport_list [ixNet getL $root vport]
        return $vport_list
		
	}
}	

#=========================================================================================
#process name:		QTP_NewQTobj
#function:			add trafficItem, set name and type of them.
#args description:	
#					quicktest: the name list of choosed quicktest.
#
#return value:		return the handle list of every quicktest.
#author:			Tim
#modification record:
#=========================================================================================
proc QTP_NewQTobj {args} {
	foreach {key value} $args {
		switch -exact $key {
			-quicktest {
				set quicktest $value
			}
		}
	}
	set handleList ""
	set root [ixNet getRoot]
	set qtList [ixNet getL $root quickTest]
	foreach qtName $quicktest {
		set handle [ixNet getL $qtList $qtName]
		foreach element $handle {
			ixNet remove $element
		}
		ixNet commit
		set handle [ixNet add $qtList $qtName]
		ixNet setA $handle -mode newMode
		ixNet commit
		
		set handleList [ixNet getL $qtList $qtName]
		set obj($qtName) $handleList	
	}
	return [array get obj]
}

#=========================================================================================
#process name:		QTP_EndPointSet
#function:			set the endpoint for every quicktest.
#args description:	
#					quicktest: the name list of choosed quicktest.
#					tra_mode: rfc2544 traffic mode, "pair" or "round".
#					port_list: list of ports used in the test.
#					protocol: type of protocol, "MAC" "IPv4" or "IPv6".
#					HOL: rfc2889 Congestion Control parameter, "oneGroup" or "manyGroup".
#					latency_type: rfc2544 Throughput parameter, "CutThrough" or "StoreAndForward".
#
#return value:		none.
#author:			Tim
#modification record:
#=========================================================================================
proc QTP_EndPointSet {args} {
	#set variables
	foreach {key value} $args {
		switch -exact -- $key {
			-quicktest {
				set quicktest $value
			}
			-tra_mode {
				set tra_mode $value
			}
			-port_list {
				set port_list $value
			}
			-protocol {
				set protocol $value
			}
			-HOL {
				set HOL $value
			}
			-latency_type {
				set latency_type $value
			}
		}
	}

	switch $protocol {
		MAC {
			set pro ethernetVlan
			
		}
		IPv4 {
			set pro ipv4
			
		}
		IPv6 {
			set pro ipv6
		}
	}

	#get quicktest lists' handle
	set testlist ""
	foreach qtName $quicktest {
		set root [ixNet getRoot]
		set qtList [ixNet getL $root quickTest]
		set handleList [ixNet getL $qtList $qtName]
		set obj($qtName) $handleList	
		lappend testlist $handleList
	}
	#add protocols and interface
	# if {$protocol == "MAC"} {
		# set lan [AddProtocol $protocol]
	# } else {
		# set interface [AddProtocol $protocol]
	# }
#puts 1	
	set interface ""
	set lan [AddProtocol MAC]
puts "lan: $lan"
	if {$protocol != "MAC"} {
		set interface [AddProtocol $protocol]
	}
	
	#get vport handle list
	set port_handle [ixNet getL $root vport]
puts "port_handle: $port_handle"	
	foreach element $testlist {
		
		#set portList
		foreach hdle $port_handle {
			set hd [ixNet add $element ports]
			set x [expr [lsearch $port_handle $hdle]+1]
			ixNet setMultiAttribute $hd \
				-id $hdle\
				-name "Ethernet\ -\ 00$x"
			ixNet commit
			ixNet setMultiAttribute $hd/slavechassisConfig \
				-role Master \
				-chainTopology Daisy
			ixNet commit
		}
#puts 2	
		#set traffic mode, if needed,and endpoint set(rfc2544 need, rfc2889 don't)
		if { [regexp {.*(rfc2544)+.+} $element]} {	
			
			set test_cfg [ixNet getL $element testConfig]
			if {$protocol == "MAC"} {
				ixNet setA $test_cfg -protocolItem $lan
			} else {
				ixNet setA $test_cfg -protocolItem $interface
			}
			ixNet commit
#puts 3			
			switch $latency_type {
				CutThrough {
					set latency_type cutThrough
				}
				StoreAndForward {
					set latency_type storeForward
				}
			}
puts "latency: $latency_type"
			if {[regexp {.*throughput+.+} $element]} {
				ixNet setA $test_cfg -latencyType $latency_type
				ixNet commit
			}
#puts 4			
			ixNet setA $element/frameData -trafficType $pro
			ixNet commit
			#set trafficMapping and trafficItem		
			set port_num [llength $port_handle]
			if {$tra_mode == "pair"} {
				if { [expr $port_num % 2] == 0} {					
					set root [ixNet getRoot]
					set tra [ixNet add $root/traffic trafficItem]
					ixNet setA $tra -name "QT-$element"
					ixNet commit

					set traffic [ixNet remapIds $tra]
					ixNet setA $traffic -trafficType $pro
					set tra_selection [ixNet add $element trafficSelection]
					ixNet setA $tra_selection -id $traffic
					ixNet commit
#puts 5
					#set endpoint and light map in pair mode
					foreach vport $port_handle {
						ixNet setA $element/trafficMapping -usesLightMaps true
						ixNet commit
						set light_map [ixNet add $element/trafficMapping lightMap]
						ixNet commit
						set light_map [ixNet remapIds $light_map]
						set edp [ixNet add $traffic endpointSet]
						ixNet commit
						set edp [ixNet remapIds $edp]
						set num [lsearch -exact $port_handle $vport]

						if {[expr ($num % 2)] == 0} {
							if {$protocol == "MAC"} {
								set src [lindex $lan $num]
								set dst [lindex $lan [expr ($num+1)]]
							} else {
								set src [lindex $interface $num]
								set dst [lindex $interface [expr ($num+1)]]
							}
							set map_src [lindex $port_handle $num]
							set map_dst [lindex $port_handle [expr ($num+1)]]
							ixNet setA $edp -sources $src
							ixNet setA $edp -destinations $dst
							ixNet setA $light_map/source:1 -portId $map_src
							ixNet setA $light_map/destination:1 -portId $map_dst
							ixNet commit
						} else {
							if {$protocol == "MAC"} {
								set src [lindex $lan $num]
								set dst [lindex $lan [expr ($num-1)]]
							} else {
								set src [lindex $interface $num]
								set dst [lindex $interface [expr ($num-1)]]
							}
							set map_src [lindex $port_handle $num]
							set map_dst [lindex $port_handle [expr ($num-1)]]
							ixNet setA $edp -sources $src
							ixNet setA $edp -destinations $dst
							ixNet setA $light_map/source:1 -portId $map_src
							ixNet setA $light_map/destination:1 -portId $map_dst
							ixNet commit
						}
					}
				} else {
					puts "Rfc2544 pair mode,the number of ports should be even!"
					puts "NAK"
					after 3000
				}
			}
			
#puts 6
			if {$tra_mode == "round"} {

				set root [ixNet getRoot]
				set tra [ixNet add $root/traffic trafficItem]
				ixNet setA $tra -name "QT-$element"
				ixNet commit
				set traffic [ixNet remapIds $tra]
				ixNet setA $traffic -trafficType $pro
				set tra_selection [ixNet add $element trafficSelection]
				ixNet setA $tra_selection -id $traffic
				ixNet commit
				#set endpoint in round mode
				foreach vport $port_handle {
					ixNet setA $element/trafficMapping -usesLightMaps true
					ixNet commit
					set light_map [ixNet add $element/trafficMapping lightMap]
					ixNet commit
					set light_map [ixNet remapIds $light_map]
					set edp [ixNet add $traffic endpointSet]
					ixNet commit
					set edp [ixNet remapIds $edp]
					set num [lsearch -exact $port_handle $vport]
					if {$num != [expr ([llength $port_handle]-1)]} {
						if {$protocol == "MAC"} {
							set src [lindex $lan $num]
							set dst [lindex $lan [expr ($num+1)]]
						} else {
							set src [lindex $interface $num]
							set dst [lindex $interface [expr ($num+1)]]
						}
						set map_src [lindex $port_handle $num]
						set map_dst [lindex $port_handle [expr ($num+1)]]
						ixNet setA $edp -sources $src
						ixNet setA $edp -destinations $dst
						ixNet setA $light_map/source:1 -portId $map_src
						ixNet setA $light_map/destination:1 -portId $map_dst
						ixNet commit
					} else {
						if {$protocol == "MAC"} {
							set src [lindex $lan $num]
							set dst [lindex $lan 0]
						} else {
							set src [lindex $interface $num]
							set dst [lindex $interface 0]
						}
						set map_src [lindex $port_handle $num]
						set map_dst [lindex $port_handle 0]
						ixNet setA $edp -sources $src
						ixNet setA $edp -destinations $dst
						ixNet setA $light_map/source:1 -portId $map_src
						ixNet setA $light_map/destination:1 -portId $map_dst
						ixNet commit
					}
				}
			}
			eval "QTP_TrafficSet -element $element $args"
			
		} else {
			set port_num [llength $port_handle]
			set root [ixNet getRoot]
			switch -regexp $element {
				.*rfc2889broadcastRate.* {
					set traffic [AddTrafficItem $element "ethernetVlan" $lan $interface]

					#set endpoint mode
					ixNet setMultiAttribute $element/trafficMapping \
						-mesh oneToMany \
						-usesLightMaps true
					set light_map [ixNet add $element/trafficMapping lightMap]
					ixNet commit
					set light_map [ixNet remapIds $light_map]
					set edp [ixNet add $traffic endpointSet]
					ixNet commit
					set edp [ixNet remapIds $edp]
					set i 1
					set dst ""
					foreach p $port_handle {
						if {[lsearch $port_handle $p] == 0} {
							set src $p/protocols
							set map_src $p
							ixNet setA $edp -sources $src
							ixNet commit
							ixNet setA $light_map/source:1 -portId $map_src
							ixNet commit
						} else {
							lappend dst $p/protocols
							set dst_map $light_map/destination:$i
							set i [expr ($i+1)]
							ixNet setA $dst_map -portId $p
							ixNet commit
						}		
					}
					ixNet setA $edp -destinations $dst
					ixNet commit
					set tra_selection [ixNet add $element trafficSelection]
					ixNet setA $tra_selection -id $traffic
					ixNet commit
					eval "QTP_TrafficSet -element $element $args"
				}
				.*rfc2889congestionControl.* {
					set traffic [AddTrafficItem $element $pro $lan $interface ]
#puts 1					
					#set endpoint mode
					ixNet setA $element/trafficMapping -mesh oneToMany
					ixNet commit
puts "HOL: $HOL"
					if {$HOL == "oneGroup"} {
						ixNet setMultiAttribute $element/trafficMapping/map:1 \
							-setName "Endpoint\ Set-1"\
							-source "Ethernet\ -\ 001" \
							-sourceId [lindex $port_handle 0] \
							-destination "Ethernet\ -\ 003" \
							-destinationId [lindex $port_handle 2]
						ixNet setMultiAttribute $element/trafficMapping/map:2 \
							-setName "Endpoint\ Set-1"\
							-source "Ethernet\ -\ 001" \
							-sourceId [lindex $port_handle 0] \
							-destination "Ethernet\ -\ 004" \
							-destinationId [lindex $port_handle 3]
						ixNet setMultiAttribute $element/trafficMapping/map:3 \
							-setName "Endpoint\ Set-2"\
							-source "Ethernet\ -\ 002" \
							-sourceId [lindex $port_handle 1] \
							-destination "Ethernet\ -\ 004" \
							-destinationId [lindex $port_handle 3]
						ixNet commit
						
						if {$protocol == "MAC"} {						
							set edp1 [ixNet add $traffic endpointSet]
							ixNet commit
							set edp1 [ixNet remapIds $edp1]
							ixNet setA $edp1 -sources [lindex $lan 0]
							ixNet setA $edp1 -destinations [list [lindex $lan 2] [lindex $lan 3]]
							ixNet commit
							set edp2 [ixNet add $traffic endpointSet]
							ixNet commit
							set edp2 [ixNet remapIds $edp2]
							ixNet setA $edp2 -sources [lindex $lan 1]
							ixNet setA $edp2 -destinations [lindex $lan 3]
							ixNet commit
						} else {
							set edp1 [ixNet add $traffic endpointSet]
							ixNet commit
							set edp1 [ixNet remapIds $edp1]
							ixNet setA $edp1 -sources [lindex $interface 0]
							ixNet setA $edp1 -destinations [list [lindex $interface 2] [lindex $interface 3]]
							ixNet commit
							set edp2 [ixNet add $traffic endpointSet]
							ixNet commit
							set edp2 [ixNet remapIds $edp2]
							ixNet setA $edp2 -sources [lindex $interface 1]
							ixNet setA $edp2 -destinations [lindex $interface 3]
							ixNet commit
							
						}
						
					} else {
						foreach {a b c d} $port_handle {
							if {$b != "" && $c != "" && $d != ""} {
								lappend nport_handle [list $a $b $c $d]
							}
						}
						set k 0
						set j 1
						foreach n_handle $nport_handle {

							ixNet setMultiAttribute $element/trafficMapping/map:[expr $k+1] \
								-setName "Endpoint\ Set-$j"\
								-source "Ethernet\ -\ 00[expr $k+1]" \
								-sourceId [lindex $n_handle 0] \
								-destination "Ethernet\ -\ 00[expr $k+3]" \
								-destinationId [lindex $n_handle 2]
							ixNet commit
							ixNet setMultiAttribute $element/trafficMapping/map:[expr $k+2] \
								-setName "Endpoint\ Set-$j"\
								-source "Ethernet\ -\ 00[expr $k+1]" \
								-sourceId [lindex $n_handle 0] \
								-destination "Ethernet\ -\ 00[expr $k+4]" \
								-destinationId [lindex $n_handle 3]
							ixNet commit
							set j [expr $j+1]
							ixNet setMultiAttribute $element/trafficMapping/map:[expr $k+3] \
								-setName "Endpoint\ Set-[expr $j]"\
								-source "Ethernet\ -\ 00[expr $k+2]" \
								-sourceId [lindex $n_handle 1] \
								-destination "Ethernet\ -\ 00[expr $k+4]" \
								-destinationId [lindex $n_handle 3]
							ixNet commit
							set j [expr $j+1]
#puts 111							
							if {$protocol == "MAC"} {						
								set edp1 [ixNet add $traffic endpointSet]
								ixNet commit
								set edp1 [ixNet remapIds $edp1]
								ixNet setA $edp1 -sources [lindex $lan $k]
								ixNet setA $edp1 -destinations [list [lindex $lan [expr $k+2]] [lindex $lan [expr $k+3]]]
								ixNet commit
								set edp2 [ixNet add $traffic endpointSet]
								ixNet commit
								set edp2 [ixNet remapIds $edp2]
								ixNet setA $edp2 -sources [lindex $lan [expr $k+1]]
								ixNet setA $edp2 -destinations [lindex $lan [expr $k+3]]
								ixNet commit
							} else {
#puts 222
								set edp1 [ixNet add $traffic endpointSet]
								ixNet commit
								set edp1 [ixNet remapIds $edp1]
								ixNet setA $edp1 -sources [lindex $interface $k]
								ixNet setA $edp1 -destinations [list [lindex $interface [expr $k+2]] [lindex $interface [expr $k+3]]]
								ixNet commit
								set edp2 [ixNet add $traffic endpointSet]
								ixNet commit
								set edp2 [ixNet remapIds $edp2]
								ixNet setA $edp2 -sources [lindex $interface [expr $k+1]]
								ixNet setA $edp2 -destinations [lindex $interface [expr $k+3]]
								ixNet commit
							}
							set k [expr $k+4]
						}
					}
					set tra_selection [ixNet add $element trafficSelection]
#puts 333
					ixNet setA $tra_selection -id $traffic
					ixNet commit
					eval "QTP_TrafficSet -element $element $args"
			    }
				.*rfc2889fullyMeshed.* {
					set traffic [AddTrafficItem $element $pro $lan $interface]

					#set endpoint mode
					ixNet setMultiAttribute $element/trafficMapping \
						-mesh fullMesh \
						-usesLightMaps true
					set light_map [ixNet add $element/trafficMapping lightMap]
					ixNet commit
					set light_map [ixNet remapIds $light_map]
					set edp [ixNet add $traffic endpointSet]
					ixNet commit
					set edp [ixNet remapIds $edp]
					set src ""
					set dst ""
					foreach p $port_handle {
						if {$protocol == "MAC"} {
							set src $lan
							set dst $lan							
						} else {
							set src $interface
							set dst $interface
						}
						ixNet setA $light_map/source:[expr [lsearch $port_handle $p]+1] -portId $p
						ixNet commit
					}
					
					# ixNet setMultiAttribute $edp \
						# -sources $src \
						# -destinations $dst
					# ixNet commit
					set tra_selection [ixNet add $element trafficSelection]
					ixNet setA $tra_selection -id $traffic
					ixNet commit
					eval "QTP_TrafficSet -element $element $args"
				}
				.*rfc2889partiallyMeshed.* {
					set traffic [AddTrafficItem $element $pro $lan $interface]

					#set endpoint mode
					ixNet setMultiAttribute $element/trafficMapping \
						-mesh manyToMany \
						-usesLightMaps true\
						-bidirectional true
					set light_map [ixNet add $element/trafficMapping lightMap]
					ixNet commit
					set light_map [ixNet remapIds $light_map]
					set edp [ixNet add $traffic endpointSet]
					ixNet commit
					set edp [ixNet remapIds $edp]
					if {[expr [llength $port_handle] % 2] == 0} {
						set p1 [lrange $port_handle 0 [expr [llength $port_handle] / 2 -1]]
						set p2 [lrange $port_handle [expr [llength $port_handle] / 2] end]
					} else {
						puts "Rfc2889 backbone: The number of ports should be even!"
                        puts "NAK"						
						after 3000
					}
					set src ""
					set dst ""
						if {$protocol == "MAC"} {
							set src [lrange $lan 0 [expr [llength $port_handle] / 2 -1]]
							set dst [lrange $lan [expr [llength $port_handle] / 2] end]						
						} else {
							set src [lrange $interface 0 [expr [llength $port_handle] / 2 -1]]
							set dst [lrange $interface [expr [llength $port_handle] / 2] end]
						}	
					foreach p $p1 {
						ixNet setA $light_map/source:[expr [lsearch $p1 $p] + 1] -portId $p
						ixNet commit
					}
					foreach p $p2 {
						ixNet setA $light_map/destination:[expr [lsearch $p2 $p] + 1] -portId $p
						ixNet commit
					}
					ixNet setMultiAttribute $edp \
						-sources $src \
						-destinations $dst
					ixNet commit
					set tra_selection [ixNet add $element trafficSelection]
					ixNet setA $tra_selection -id $traffic
					ixNet commit
					eval "QTP_TrafficSet -element $element $args"
				}
				.*rfc2889manyToOne.* {
					set traffic [AddTrafficItem $element $pro $lan $interface]

					#set endpoint mode
					ixNet setMultiAttribute $element/trafficMapping \
						-mesh manyToOne \
						-usesLightMaps true
					set light_map [ixNet add $element/trafficMapping lightMap]
					ixNet commit
					set light_map [ixNet remapIds $light_map]
					set edp [ixNet add $traffic endpointSet]
					ixNet commit
					set edp [ixNet remapIds $edp]
					set src ""
					set dst ""
					foreach p $port_handle {
						if {$p != [lindex $port_handle end]} {
							if {$protocol == "MAC"} {
								lappend src [lindex $lan [lsearch $port_handle $p]]						
							} else {
								lappend src [lindex $interface [lsearch $port_handle $p]]
							}
							ixNet setA $light_map/source:[expr [lsearch $port_handle $p]+1] -portId $p
							ixNet commit
						} else {
							if {$protocol == "MAC"} {
								set dst [lindex $lan [lsearch $port_handle $p]]							
							} else {
								set dst [lindex $interface [lsearch $port_handle $p]]
							}
							ixNet setA $light_map/destination:1 -portId $p
							ixNet commit
						}
					}
					ixNet setMultiAttribute $edp \
						-sources $src \
						-destinations $dst
					ixNet commit
					set tra_selection [ixNet add $element trafficSelection]
					ixNet setA $tra_selection -id $traffic
					ixNet commit
					eval "QTP_TrafficSet -element $element $args"
				}
				.*rfc2889oneToMany.* {
					set traffic [AddTrafficItem $element $pro $lan $interface]

					#set endpoint mode
					ixNet setMultiAttribute $element/trafficMapping \
						-mesh oneToMany \
						-usesLightMaps true
					set light_map [ixNet add $element/trafficMapping lightMap]
					ixNet commit
					set light_map [ixNet remapIds $light_map]
					set edp [ixNet add $traffic endpointSet]
					ixNet commit
					set edp [ixNet remapIds $edp]
					set src ""
					set dst ""
					foreach p $port_handle {
						if {$p != [lindex $port_handle end]} {
							if {$protocol == "MAC"} {
								lappend dst [lindex $lan [lsearch $port_handle $p]]						
							} else {
								lappend dst [lindex $interface [lsearch $port_handle $p]]
							}
							ixNet setA $light_map/destination:[expr [lsearch $port_handle $p]+1] -portId $p
							ixNet commit
						} else {
							if {$protocol == "MAC"} {
								set src [lindex $lan [lsearch $port_handle $p]]							
							} else {
								set src [lindex $interface [lsearch $port_handle $p]]
							}
							ixNet setA $light_map/source:1 -portId $p
							ixNet commit
						}
					}
					ixNet setMultiAttribute $edp \
						-sources $src \
						-destinations $dst
					ixNet commit
					set tra_selection [ixNet add $element trafficSelection]
					ixNet setA $tra_selection -id $traffic
					ixNet commit
					eval "QTP_TrafficSet -element $element $args"
				}
			}
		}
	}					
}
	
#=========================================================================================
#process name:		QTP_TrafficSet
#function:			set traffics.
#args description:	
#					element: the handle list of the quicktest.
#					protocol: the type of protocol, "MAC" "IPv4" or "IPv6".
#					ip_addr_start: the starting ip address.
#					ip_addr_step: the ip address' increasing step.
#					gw_addr_start: the starting gateway's ip address.
#					gw_addr_step: the gateway ip address' increasing step.
#					pfx_len: the prefix length of the ip address.
#					addr_count: the number of the ip address.
#					frame_size: the size of the frame.
#					lng_rate: the learning frequency.
#					lng_frames: the learning number of frames.
#					lng_mac_only: enable LearnSendMacOnly or not.
#					port_step: the ip address increase step by ports.
#					test_duration: the duration of each test trail.
#
#return value:		none.
#author:			Tim
#modification record:
#=========================================================================================
proc QTP_TrafficSet {args} {
	set addr_count 1
	set lng_rate 100
	set test_duration 10
	foreach {key value} $args {
		switch -exact $key {
			-element {
				set element $value
			}
			-protocol {
				set protocol $value
			}
			-ip_addr_start {
				set ip_addr_start $value
			}
			-ip_addr_step {
				set ip_addr_step $value
			}
			-gw_addr_start {
				set gw_addr_start $value
			}
			-gw_addr_step {
				set gw_addr_step $value
			}
			-pfx_len {
				set pfx_length $value
			}
			-addr_count {
				set addr_count $value
			}
			-frame_size {
				set frame_size $value
			}
			-lnl_rate -
			-lng_rate {
				set lng_rate $value
			}
			-lng_frames {
				set lng_frames $value
			}
			-lng_mac_only {
				set lng_mac_only $value
			}
			-port_step {
				set port_step $value
			}
			-test_duration {
				set test_duration $value
			}
		}
	}
	#framedata set
	if {[regexp {.*rfc2889broadcastRate.*} $element] == 0} {
		set f_handle [ixNet getL $element frameData]
		if {$protocol == "IPv4"} {
			set f_handle [ixNet getL $f_handle automaticIp]
			ixNet setMultiAttribute $f_handle/ip \
				-firstSrcIpAddr $ip_addr_start \
				-addrIncrementAcrossInterface $ip_addr_step \
				-firstGwIpAddr $gw_addr_start \
				-gwAddrIncr $gw_addr_step \
				-mask $pfx_length \
				-addrIncrement $port_step
			ixNet commit
		} elseif {$protocol == "IPv6"} {
			set f_handle [ixNet getL $f_handle automaticIpv6]
			ixNet setMultiAttribute $handle/ipv6 \
				-firstSrcIpAddr $ip_addr_start \
				-addrIncrementAcrossInterface $ip_addr_step \
				-firstGwIpAddr $gw_addr_start \
				-gwAddrIncr $gw_addr_step \
				-mask $pfx_length \
				-addrIncrement $port_step
			ixNet commit
		}
		if {$addr_count != 1} {
			ixNet setMultiAttribute $f_handle/addrCount \
				-enableRx true \
				-enableSameTx true \
				-rx $addr_count
			ixNet commit
		}
	}
	#traffic options
	set t_handle [ixNet getL $element testConfig]
	ixNet setMultiAttribute $t_handle \
		-frameSizeMode custom \
		-framesizeList $frame_size \
		-duration $test_duration
	ixNet commit
	if {[regexp {.*rfc2889congestionControl.*} $t_handle]} {
		ixNet setA $t_handle -amountOfTraffic duration
		ixNet commit
	}
	if {[regexp {.*rfc2544frameLoss.*} $t_handle]} {
		ixNet setA $t_handle -runmode duration
		ixNet commit
	}
	
	switch $lng_mac_only {
		1 {
		set $lng_mac_only true
		}
		0 {
		set $lng_mac_only false
		}
	}
	set l_handle [ixNet getL $element learnFrames]
	ixNet setMultiAttribute $l_handle \
		-learnFrequency $lng_rate \
		-learnNumFrames $lng_frames \
		-learnSendMacOnly $lng_mac_only
	ixNet commit
	#apply the settings
	ixNet exec apply $element
}

#=========================================================================================
#process name:		QTP_GetResult
#function:			run the QuickTest and save the results.
#args description:	
#					qtHandle:  the handle of the quicktest.
#                   speed:     the speed of the test ports
#
#return value:		
#author:			Tim
#modification record:
#=========================================================================================
proc QTP_GetResult {qtHandle speed} {
    global resfilepath
	global resPath
	if { [ catch {
	    puts "Apply QTtest"
		ixNet exec apply $qtHandle
		after 1000
		puts "Running Test"
		ixNet exec run $qtHandle
		after 2000
		ixNet exec waitForTest $qtHandle
		after 3000
		puts "Get results of the quick test"
		set path [ixNet getA $qtHandle/results -resultPath]
		puts "Initialpath: $path"
		set rfile [open $path/aggregateresults.csv r]
		set rpattern [read -nonewline $rfile]
		close $rfile
		puts $rpattern
		
		set temp [lindex [ split $qtHandle / ] end ]
		set qtname [lindex [ split $temp : ] 0 ]
		set newResPath "${resPath}/${qtname}_${speed}"
		puts "Resultpath: $newResPath"
		
		set  resfile [ open $resfilepath a+ ]
		puts $resfile "${speed}:$qtname Test Results:"
		puts $resfile $rpattern
		flush $resfile
		close $resfile
	} err ]} {
	    puts "error:$err"
	}
	
	
	if { [ catch {
	    file copy -force $path $newResPath
	} err ]} {
	    puts "Copy $qtHandle result error: $err"
	}
			
}

#=========================================================================================
#process name:		StartQT
#function:			config, run, save results of the quicktestlist, the main process
#args description:	
#					port_list: the list of ports used in the test.
#					2544_throughput_enable: whether test rfc2544 throughput or not, value "1" or "0"
#					2544_latency_enable: whether test rfc2544 latency or not, value "1" or "0"
#					2544_frameloss_enable: whether test rfc2544 frameLoss or not, value "1" or "0"
#					2544_b2b_enable: whether test rfc2544 backToBack or not, value "1" or "0"
#					2889_fully_enable: whether test rfc2889 fullyMeshed or not, value "1" or "0"
#					2889_hol_enable: whether test rfc2889 congestionControl or not, value "1" or "0"
#					2889_many2one_enable: whether test rfc2889 manyToOne or not, value "1" or "0"
#					2889_one2many_enable: whether test rfc2889 oneToMany or not, value "1" or "0"
#					2889_broadcast_enable: whether test rfc2889 broadcast or not, value "1" or "0"
#					2889_backbone_enable: whether test rfc2889 partiallyMeshed or not, value "1" or "0"
#					latency_type: rfc2544 Throughput parameter, "CutThrough" or "StoreAndForward"
#					hol_type: rfc2889 Congestion Control parameter, "oneGroup" or "manyGroup"
#					pair_enable: rfc2544 parameter, if value is 1, set the traffic mode to "pair"
#					round_enable: rfc2544 parameter, if value is 1, set the traffic mode to "round"
#					mac_enable: if value is 1, set the protocol to "MAC"
#					ip_enable: if value is 1, set the protocol to "IPv4"
#					ipv6_enable: if value is 1, set the protocol to "IPv6"
#					ip_addr_start: the starting ip address
#					ip_addr_step: the ip address' increasing step
#					gw_addr_start: the starting gateway's ip address
#					gw_addr_step: the gateway ip address' increasing step
#					pfx_len: the prefix length of the ip address
#					port_step: the ip address increase step by ports
#					fs64_enable: if value is 1, add the framesize list with 64
#					fs128_enable: if value is 1, add the framesize list with 128
#					fs256_enable: if value is 1, add the framesize list with 256
#					fs512_enable: if value is 1, add the framesize list with 512
#					fs590_enable: if value is 1, add the framesize list with 590
#					fs1024_enable: if value is 1, add the framesize list with 1024
#					fs1280_enable: if value is 1, add the framesize list with 1280
#					fs1518_enable: if value is 1, add the framesize list with 1518
#					fs_jumbo_enable: if value is 1, using jumbo frame during the test
#					jumbo_value: the framesize of the jumbo frame
#					test_duration: the time duration of every test trail
#					lng_rate: the learning frequency
#					frames_per_addr: the learning number of frames
#					send_mac_only_enable: if value is 1, enable LearnSendMacOnly
#					10m_enable: if value is 1, add the speed list with 10m
#					100m_enable: if value is 1, add the speed list with 100m
#					1g_enable: if value is 1, add the speed list with 1g
#					media: the media type, "fiber" or "copper"
#					autoneg: whether autoneg or not, "Auto" or "Half" or "Full"
#					10g_enable: if value is 1, add the speed list with 10g
#					25g_enable: if value is 1, add the speed list with 25g
#					40g_enable: if value is 1, add the speed list with 40g
#					100g_enable: if value is 1, add the speed list with 100g
#
#return value:		none
#author:			Tim
#modification record:
#=========================================================================================	
proc StartQT { args } {
    set quicktest ""
    set frame_size ""
	set lng_rate 100
	set frames_per_addr 5
	set test_duration 10
	global resPath resfilepath
puts 5
	ixNet exec newConfig
puts 10
	# after 10000
puts "args:$args"	
    foreach {key value} $args {
		switch -exact $key {
			-port_list {
				set port_list $value
				foreach tempport $port_list {
				    if { [regexp {^([0-9]+.[0-9]+.[0-9]+.[0-9]+:[0-9]+:[0-9]+)$} $tempport] } {
					} else {
					    puts "ERROR: -port_list format is not right, the value is $value"
						puts "NAK"
						after 3000
					}
				}
			}
            -2544_throughput_enable {
                if { $value == 1 && [lsearch $quicktest "rfc2544throughput"] == -1 } {
                    lappend quicktest rfc2544throughput 
                }
            }
            -2544_latency_enable {
                if { $value == 1 && [lsearch $quicktest "rfc2544throughput"] == -1 } {
                    lappend quicktest rfc2544throughput 
                }
            }
            -2544_frameloss_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2544frameLoss 
                }
            }
            -2544_b2b_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2544back2back 
                }
            }
            -2889_fully_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2889fullyMeshed
                }
            }
            -2889_hol_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2889congestionControl
                }
            }
            -2889_many2one_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2889manyToOne
                }
            }
            -2889_one2many_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2889oneToMany 
                }
            }
            -2889_broadcast_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2889broadcastRate 
                }
            }
            -2889_backbone_enable {
                if { $value == 1 } {
                    lappend quicktest rfc2889partiallyMeshed 
                }
            }
            -latency_type {
			    if { $value == "CutThrough" || $value == "StoreAndForward" } {
				    set latency_type $value
				} else {
				    puts "ERROR: -latency_type format is not right, the value is $value, should be CutThrough|StoreAndForward"
					puts "NAK"
					after 3000
				}
               
            }
            -hol_type {
			    if { $value == "oneGroup" || $value == "manyGroup" } {
				    set hol_type $value
				} else {
				    puts "ERROR: -hol_type format is not right, the value is $value, should be oneGroup|manyGroup"
					puts "NAK"
					after 3000
				}
                
            }
            -pair_enable {
                if { $value == 1 } {
                    set tra_mode "pair"
                }           
            }
            -round_enable {
                if { $value == 1 } {
                    set tra_mode "round" 
                }
            }           
            -mac_enable {
                if { $value == 1 } {
                    set protocol "MAC" 
                }
            }           
            -ip_enable {
                if { $value == 1 } {
                    set protocol "IPv4" 
                }
            }           
            -ipv6_enable {
                if { $value == 1 } {
                    set protocol "IPv6" 
                }
            }           
            -ip_addr_start {
                set ip_addr_start $value
            }
            -ip_addr_step {
                set ip_addr_step $value
            }
            -gw_addr_start {
                set gw_addr_start $value
            }
            -gw_addr_step {
                set gw_addr_step $value
            }
            -pfx_len {
                set pfx_len $value
            }
            -port_step {
                set port_step $value
            }
            -fs64_enable {
                if { $value == 1 } {
                    #lappend frame_size 64
					#set frame_size "${frame_size}64,"
					if { $frame_size == ""} {
					    set frame_size "64"
					} else {
					    set frame_size "${frame_size},64"
					}
                }
            }
            -fs128_enable {
                if { $value == 1 } {
                    #lappend frame_size 128
					#set frame_size "${frame_size}128,"
					if { $frame_size == ""} {
					    set frame_size "128"
					} else {
					    set frame_size "${frame_size},128"
					}
                }
            }
            -fs256_enable {
                if { $value == 1 } {
                    #lappend frame_size 256
					#set frame_size "${frame_size}256,"
					if { $frame_size == ""} {
					    set frame_size "256"
					} else {
					    set frame_size "${frame_size},256"
					}
                }
            }
            -fs512_enable {
                if { $value == 1 } {
                    #lappend frame_size 512
					#set frame_size "${frame_size}512,"
					if { $frame_size == ""} {
					    set frame_size "512"
					} else {
					    set frame_size "${frame_size},512"
					}
                }
            }
			-fs590_enable {
                if { $value == 1 } {
                    #lappend frame_size 590
					#set frame_size "${frame_size}590,"
					if { $frame_size == ""} {
					    set frame_size "590"
					} else {
					    set frame_size "${frame_size},590"
					}
                }
            }
            -fs1024_enable {
                if { $value == 1 } {
                    #lappend frame_size 1024
					#set frame_size "${frame_size}1024,"
					if { $frame_size == ""} {
					    set frame_size "1024"
					} else {
					    set frame_size "${frame_size},1024"
					}
                }
            }
            -fs1280_enable {
                if { $value == 1 } {
                    #lappend frame_size 1280
					#set frame_size "${frame_size}1280,"
					if { $frame_size == ""} {
					    set frame_size "1280"
					} else {
					    set frame_size "${frame_size},1280"
					}
                }
            }
            -fs1518_enable {
                if { $value == 1 } {
                    #lappend frame_size 1518
					#set frame_size "${frame_size}1518,"
					if { $frame_size == ""} {
					    set frame_size "1518"
					} else {
					    set frame_size "${frame_size},1518"
					}
                }
            }
            -fs_jumbo_enable {
                set fs_jumbo_enable $value
            }
            -jumbo_value {
                
				if {[ string is integer $value ]} {
				    set jumbo_value $value
				} else {
				    puts "Error:jumbo_value format error:jumbo_value:$jumbo_value, should be integer"
			        puts "NAK"
			        after 3000
				}
            }
            -test_duration {
			    if {[ string is integer $value ]} {
				    set test_duration $value
				} else {
				    puts "Error:test_duration format error:test_duration:$test_duration , should be integer"
			        puts "NAK"
			        after 3000
				}
            }
            -lng_rate {
             
				if {[ string is integer $value ]} {
				    set lng_rate $value
				} else {
				    puts "Error:lng_rate format error:lng_rate:$lng_rate , should be integer"
			        puts "NAK"
			        after 3000
				}
            }
            -frames_per_addr {
              
				if {[ string is integer $value ]} {
				    set frames_per_addr $value
				} else {
				    puts "Error:frames_per_addr format error:frames_per_addr:$frames_per_addr , should be integer"
			        puts "NAK"
			        after 3000
				}
            }
            -send_mac_only_enable {
                set send_mac_only_enable $value
            }            
            -10m_enable {
               set 10m_enable $value
            }
            -100m_enable {
               set 100m_enable $value
            }
            -1g_enable {
               set 1g_enable $value
            }
            -media {
               set media [string tolower $value]
			   if { $media == "fiber" || $medai ==  "copper" } {
			   } else {
			       puts "Error:media format error: media:$media, should be fiber | copper"
			       puts "NAK"
			       after 3000
			   }
            }
            -autoneg {
               set autoneg $value
			   if { $autoneg == "Auto" || $autoneg ==  "Half" || $autoneg ==  "Full" } {
			   } else {
			       puts "Error:autoneg format error: autoneg:$autoneg, should be Auto | Half | Full"
			       puts "NAK"
			       after 3000
			   }
            }
            -10g_enable {
               set 10g_enable $value
            }
            -25g_enable {
               set 25g_enable $value
            }
            -40g_enable {
               set 40g_enable $value
            }
            -100g_enable {
               set 100g_enable $value
            }
        }
    }

    if {$fs_jumbo_enable } {
        #lappend frame_size $jumbo_value
        #set frame_size "${frame_size}${jumbo_value},"	
        if { $frame_size == ""} {
			set frame_size "${jumbo_value}"
		} else {
			set frame_size "${frame_size},${jumbo_value}"
		}		
    }  

    if { $protocol == "IPv4" } {
	    if { [IsIPv4Address $ip_addr_start ] && [IsIPv4Address $ip_addr_step ] \
          && [IsIPv4Address $gw_addr_start ] && [IsIPv4Address $gw_addr_step ] \
		  && [IsIPv4Address $port_step ] } {
		} else {
		    puts "Error:ipv4 addrss format error: ip_addr_start:$ip_addr_start;ip_addr_step:$ip_addr_step"
			puts "gw_addr_start:$gw_addr_start;gw_addr_step:$gw_addr_step;port_step:$port_step"
			puts "NAK"
			after 3000
		}
		if {  [ string is integer $pfx_len ] && 0<=$pfx_len && $pfx_len <= 32  } {
		} else {
		    puts "Error:ipv4 pfx_len error: pfx_len:$pfx_len"
			puts "NAK"
			after 3000
		}
	} elseif { $protocol == "IPv6" } {
	    if { [IsIPv6Address $ip_addr_start ] && [IsIPv6Address $ip_addr_step ] \
          && [IsIPv6Address $gw_addr_start ] && [IsIPv6Address $gw_addr_step ] \
		  && [IsIPv6Address $port_step ] } {
		} else {
		    puts "Error:ipv6 addrss format error: ip_addr_start:$ip_addr_start;ip_addr_step:$ip_addr_step"
			puts "gw_addr_start:$gw_addr_start;gw_addr_step:$gw_addr_step;port_step:$port_step"
			puts "NAK"
			after 3000
		}
		
		if { [ string is integer $pfx_len ] && 0<=$pfx_len && $pfx_len <= 128  } {
		} else {
		    puts "Error:ipv6 pfx_len error: pfx_len:$pfx_len"
			puts "NAK"
			after 3000
		}
	}	
	
	puts "Reserve real port $port_list"
    set port_handle [QTP_PortListSet  -port_list $port_list]
	after 10000
puts 30  
    puts "Check ports state"
    foreach pHandle $port_handle {
	    set pState [ixNet getA $pHandle -state]
		if { $pState != "up" } {
		    after 5000
			set pState [ixNet getA $pHandle -state]
			if { $pState != "up" } {
				puts "Error:port state is not up: $pHandle state $pState"
				puts "NAK"
				after 3000
			}
		}
    }	
	after 1000
	if { $quicktest == "" } {
	    puts "Error:No quickTest is choosed"
		puts "NAK"
		after 3000
	}
    puts "Config quicktest list $quicktest"
    array set QTobj [QTP_NewQTobj -quicktest $quicktest]
    # puts "Quick Test EndPointsSet"
    # QTP_EndPointSet -quicktest $quicktest -tra_mode $tra_mode -HOL $hol_type
    # puts "traffic Frame Data Set "
    # QTP_TrafficSet -quicktest $quicktest -protocol $protocol -ip_addr_start $ip_addr_start \
                   # -ip_addr_step $ip_addr_step -gw_addr_start $gw_addr_start \
                   # -gw_addr_step $gw_addr_step  -pfx_len $pfx_len -port_step $port_step
    # puts "FrameSize Set "
    # QTP_FrameSizeSet -quicktest $quicktest -frame_size $frame_size -lng_rate $lng_rate \
                     # -lng_frames $frames_per_addr -lng_mac_only $send_mac_only_enable \
                     # -test_duration test_duration
	puts "QuickTest config"
					 
	QTP_EndPointSet -quicktest $quicktest -tra_mode $tra_mode -HOL $hol_type \
	                -protocol $protocol -ip_addr_start $ip_addr_start \
                    -ip_addr_step $ip_addr_step -gw_addr_start $gw_addr_start \
                    -gw_addr_step $gw_addr_step  -pfx_len $pfx_len -port_step $port_step \
					-frame_size $frame_size -lng_rate $lng_rate \
                    -lng_frames $frames_per_addr -lng_mac_only $send_mac_only_enable \
                    -test_duration $test_duration -latency_type $latency_type

	set speedProgressList [ list 10m_enable 100m_enable 1g_enable 10g_enable 25g_enable 40g_enable 100g_enable]
	set progressCnt 0
	foreach sp $speedProgressList {
		if { [ set $sp ] } {
			incr progressCnt
		}
	}
	set progressVolume [ expr round(70.0 / $progressCnt) ]
	puts "progress volume:$progressVolume"
	set progressInit 30
	set qtCnt [ llength [array names QTobj] ]
	set qtProgressVolume [ expr round($progressVolume /$qtCnt)]
	puts "qt progress volume:$qtProgressVolume"
	
    puts "Run quicktest in each speed"
	set resfilepath "$resPath/QTP.log"
	set resfile [open $resfilepath a+]
	close $resfile
	
    if {$10m_enable} {
        puts "10m $autoneg $media config"
        set ix_type ethernet
        foreach pHandle $port_handle {        
            ixNet setA $pHandle -type $ix_type
            ixNet commit
            ixNet setA $pHandle/l1Config/ethernet -media $media
            ixNet commit
            if { $autoneg == "Auto" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate True
                ixNet setA $pHandle/l1Config/ethernet -speedAuto {speed10fd speed10hd}
                ixNet commit
            } elseif { $autoneg == "Half" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate False
                ixNet setA $pHandle/l1Config/ethernet -speed speed10hd
                ixNet commit
            } elseif { $autoneg == "Full" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate False
                ixNet setA $pHandle/l1Config/ethernet -speed speed10fd
                ixNet commit
            }
            
        }
        
puts $progressInit
		foreach {key handle} [array get QTobj] {
            puts "10M speed, $autoneg ,media: $media Run quickTest:$key"
set progressInit [expr $progressInit + $qtProgressVolume]
			QTP_GetResult $handle "10M"
puts $progressInit	
        }
        
    }
    if {$100m_enable} {
         puts "100m $autoneg $media config"
        set ix_type ethernet
        foreach pHandle $port_handle {        
            ixNet setA $pHandle -type $ix_type
            ixNet commit
            ixNet setA $pHandle/l1Config/ethernet -media $media
            ixNet commit
            if { $autoneg == "Auto" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate True
                ixNet setA $pHandle/l1Config/ethernet -speedAuto {speed100fd speed100hd}
                ixNet commit
            } elseif { $autoneg == "Half" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate False
                ixNet setA $pHandle/l1Config/ethernet -speed speed100hd
                ixNet commit
            } elseif { $autoneg == "Full" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate False
                ixNet setA $pHandle/l1Config/ethernet -speed speed100fd
                ixNet commit
            }
            
        }
        
puts $progressInit
        foreach {key handle} [array get QTobj] {
            puts "100M speed, $autoneg ,media: $media Run quickTest:$key"
puts "init:$progressInit qt volume:$qtProgressVolume"
set progressInit [expr $progressInit + $qtProgressVolume]
puts "new progress:$progressInit"
			QTP_GetResult $handle "100M"
puts $progressInit	
        }
    }
    if {$1g_enable} {
         puts "1g $autoneg $media config"
        set ix_type ethernet
        foreach pHandle $port_handle {        
            ixNet setA $pHandle -type $ix_type
            ixNet commit
            ixNet setA $pHandle/l1Config/ethernet -media $media
            ixNet commit
            if { $autoneg == "Auto" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate True
                ixNet setA $pHandle/l1Config/ethernet -speedAuto auto
                ixNet commit
            } elseif { $autoneg == "Half" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate False
                ixNet setA $pHandle/l1Config/ethernet -speed speed1000
                ixNet commit
            } elseif { $autoneg == "Full" } {
                ixNet setA $pHandle/l1Config/ethernet -autoNegotiate False
                ixNet setA $pHandle/l1Config/ethernet -speed speed1000
                ixNet commit
            }
            
        }
        
puts $progressInit
        foreach {key handle} [array get QTobj] {
            puts "1g speed, $autoneg ,media: $media Run quickTest:$key"
set progressInit [expr $progressInit + $qtProgressVolume]
			QTP_GetResult $handle "1G"
puts $progressInit			
        }
    }
    if {$10g_enable} {
         puts "10g config"
        set ix_type tenGigLan
        foreach pHandle $port_handle {        
            ixNet setA $pHandle -type $ix_type
            ixNet commit                               
        }
        
puts $progressInit
        foreach {key handle} [array get QTobj] {
            puts "10g speed, Run quickTest:$key"
set progressInit [expr $progressInit + $qtProgressVolume]
			QTP_GetResult $handle "10G"
puts $progressInit		
        }
    }
    if {$25g_enable} {
	
puts $progressInit
        foreach {key handle} [array get QTobj] {
            puts "25g speed, Run quickTest:$key"
set progressInit [expr $progressInit + $qtProgressVolume]
			QTP_GetResult $handle "25G"
puts $progressInit		
        }
         

    }
    if {$40g_enable} {
         puts "40g config"
        set ix_type fortyGigLan
        foreach pHandle $port_handle {        
            ixNet setA $pHandle -type $ix_type
            ixNet commit                               
        }
        
puts $progressInit
        foreach {key handle} [array get QTobj] {
            puts "40g speed, Run quickTest:$key"
set progressInit [expr $progressInit + $qtProgressVolume]         
			QTP_GetResult $handle "40G"
puts $progressInit	
        }
    }
    if {$100g_enable} {
         puts "100g config"
        set ix_type hundredGigLan
        foreach pHandle $port_handle {        
            ixNet setA $pHandle -type $ix_type
            ixNet commit                               
        }
puts $progressInit        
        foreach {key handle} [array get QTobj] {
            puts "100g speed, Run quickTest:$key"
set progressInit [expr $progressInit + $qtProgressVolume] 
			QTP_GetResult $handle "100G"
puts $progressInit	
        }
    }
}

#=========================================================================================
#process name:		StopQT
#function:			stop the test.
#args description:	
#					none.
#
#return value:		none.
#author:			Tim
#modification record:
#=========================================================================================
proc StopQT {} {
    puts "stop the quick test"
	
	set RqtList [ixNet getA  ::ixNet::OBJ-/quickTest -runningTest]
	if {$RqtList != ""} {
	    foreach Rqt $RqtList {
		    ixNet exec stop $Rqt
		}
	}
	
}

