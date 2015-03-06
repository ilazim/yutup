#
# yutup v0.1
#
# Based on http://wiki.mikrotik.com/wiki/Sync_Address_List_with_DNS_Cache
# A Mikrotik script for syncing address list with DNS cache lookup by certain keyword.
# This script will try to resolve a CNAME to A records by doing dns recursive.
#
# 2015/03/07
# by Firman Gautama <firman@kodelatte.com>
#
# Tested on ROS v6.22 (RB750GL)
#

# REGEX match
:local search "youtube|googlevideo.com"
:local myaddressname "FRMN_YOUTUBE";

# Define Arrays
:local IPs ""
:local CNAMEs ""
:local Names ""

for x from=0 to 2 step=1 do={

# Reset Arrays
:set IPs ""
:set CNAMEs ""
:set Names ""

/ip dns cache all {
   :local name; :local type; :local data

   :foreach rule in=[print detail as-value where (static=no)] do={
      :set name ""; :set type ""; :set data ""

      :local num 0
      :foreach item in=$rule do={
         :if ($num = 2) do={ :set name $item }
         :if ($num = 4) do={ :set type $item }
         :if ($num = 1) do={ :set data $item }
         :set num ($num + 1)
      }

# identify CNAME and try to Resolve it
     :if ([:tostr $name] ~ [:tostr $search] && $type = "CNAME") do={
#         :put ("Found CNAME " . $name . " -> " . $data)
         :set CNAMEs ($CNAMEs . $data . ",")
         :set Names ($Names . $name . ",")

         :resolve $data;
      }

# get DNS A Record
     :if ([:tostr $name] ~ [:tostr $search] && $type = "A") do={
#         :put ("Found A Record " . $name . " -> " . $data)
         :set IPs ($IPs . $data . ",")
         :set Names ($Names . $name . ",")
      }

   }
# /ip dns cache all
}
}


##### 

##### clean up unique A Records
:local uniqueIPs ""
:set uniqueIPs ""


:foreach val in=[:toarray $IPs] do={
  :local unik 1;

 :if ($uniqueIPs = "") do={
    :set uniqueIPs ($uniqueIPs . $val . ",");
  }

  if ($uniqueIPs != "") do={
    :set unik 1;

    :foreach val2 in=[:toarray $uniqueIPs] do={
      :if ($val = $val2) do={
        :set unik 0;
      }
    }

    :if ($unik = 1) do={
      :set uniqueIPs ($uniqueIPs . $val . ",");
    }
  }
}

########################


:put ("DNS cache search found " . [:len [:toarray $IPs]] . " A match(es) for '" . $search . "'")
:put ("DNS cache search found " . [:len [:toarray $uniqueIPs]] . " Unique A match(es) for '" . $search . "'")
:put ("DNS cache search found " . [:len [:toarray $CNAMEs]] . " CNAME match(es) for '" . $search . "'")


# Search through IPs and add to address list
/ip firewall address-list {
   :local findex; :local listaddr; :local IPsFound ""

   :put ("Searching address list '" . $myaddressname . "'...")
   :foreach l in=[find list=($myaddressname)] do={
      :set listaddr [get $l address]
      :if ([:len [:find [:toarray $uniqueIPs] [:toip $listaddr]]] = 0) do={
         :put ("   " . $listaddr . " not found in search, removing...")
         remove $l
      } else={
         :put ($listaddr . " found address in IPs")
         :set IPsFound ($IPsFound . $listaddr . ",")
      }
   }

# Add remaining records to address list
   :set findex 0
   :foreach ip in=[:toarray $uniqueIPs] do={
      :if ([:len [:find [:toarray $IPsFound] [:toip $ip]]] = 0) do={
         :put ("   Adding address " . $ip)
         add list=($myaddressname) address=[:toip $ip] comment=([:pick [:toarray $Names] $findex]) disabled=no
      }
      :set findex ($findex + 1)
   }
# /ip firewall address-list
}