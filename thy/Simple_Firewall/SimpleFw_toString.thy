theory SimpleFw_toString
imports "Primitives/Primitives_toString"
        SimpleFw_Syntax
begin


section\<open>Simple Firewall toString Functions\<close>

fun simple_action_toString :: "simple_action \<Rightarrow> string" where
  "simple_action_toString Accept = ''ACCEPT''" |
  "simple_action_toString Drop = ''DROP''"

fun simple_rule_toString :: "32 simple_rule \<Rightarrow> string" where
  "simple_rule_toString (SimpleRule \<lparr>iiface=iif, oiface=oif, src=sip, dst=dip, proto=p, sports=sps, dports=dps \<rparr> a) = 
      simple_action_toString a @ ''     '' @ 
      protocol_toString p @ ''  --  '' @ 
      ipv4_cidr_toString sip @ ''            '' @
      ipv4_cidr_toString dip @ '' '' @ 
      iface_toString ''in: '' iif @ '' '' @ 
      iface_toString ''out: '' oif @ '' '' @ 
      ports_toString ''sports: '' sps @ '' '' @ 
      ports_toString ''dports: '' dps"

fun simple_rule_iptables_save_toString :: "string \<Rightarrow> 32 simple_rule \<Rightarrow> string" where
  "simple_rule_iptables_save_toString chain (SimpleRule \<lparr>iiface=iif, oiface=oif, src=sip, dst=dip, proto=p, sports=sps, dports=dps \<rparr> a) = 
    ''-A ''@chain@iface_toString '' -i '' iif @
                  iface_toString '' -o '' oif @
                  ipv4_cidr_opt_toString '' -s '' sip @
                  ipv4_cidr_opt_toString '' -d '' dip @
                  protocol_opt_toString '' -p '' p @
                  ports_toString '' --sport '' sps @
                  ports_toString '' --dport '' dps @
                  '' -j '' @ simple_action_toString a"


end
