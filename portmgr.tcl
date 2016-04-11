if { [ catch {

	set success 1
	puts "please input the chassis address:"
	gets stdin chassis

	set out ""
	
	package req IxTclNetwork
	package req IxTclHal
	if { $success } {
	    ixConnectToTclServer $chassis
		set result [ixConnectToChassis $chassis]
		if { $result } {
			puts "<error>|msg=fail to connect to chassis"
			set success 0
		}
	}
	if { $success } {
		chassis get $chassis
		set chasId [ chassis cget -id ]		
		set chasSn [chassis cget -serialNumber]		
		#set out "$chasSn"
		
		set CHASSNLIST { XM2-P1022662 }
		if { [lsearch $CHASSNLIST $chasSn] == -1 } {
		    set success 0
			puts "<error>|msg=$chassis,SN:$chasSn is not in the legal Chassis SN"
		    puts "NAK"
			
		}
		
	}

	if { $success } {
	    ixNet connect localhost -version 7.0
	    set root [ixNet getRoot]
		set chas [ixNet add $root/availableHardware chassis]
		ixNet setA $chas -hostname $chassis
		ixNet commit
		
		set success 0
		for { set index 0 } { $index < 10 } {incr index} {
			set state [ ixNet getA $chas -state ]
			if { $state == "ready" } {
				set success 1
				break
			} else {
				after 1000
				set err "chassis connection timeout"
			}
		}
	}
	
	if { $success } {
		set cardList [ ixNet getL $chas card ]
puts "cards:$cardList"		

		foreach card $cardList {
			set cardId [ ixNet getA $card -cardId ]
			set portList [ixNet getL $card port]
			foreach port $portList {
				set portId [ixNet getA $port -portId]
				set out "$out $chassis:$cardId:$portId"
			}
		}
	}
	
	after 2000
	
	if { $success } {
		puts "out=$out"
		puts "ACK"
	} else {
		puts "<error>|msg=$err"
		puts "NAK"
	}

} err ] } {
	puts "<error>|msg=$err"
	puts "NAK"
}

