theory Interface_Replace
imports
  No_Spoof
  Common_Primitive_toString
begin

section\<open>Trying to connect inbound interfaces by their IP ranges\<close>
subsection\<open>constraining interfaces\<close>

definition ipassmt_iface_constrain_srcip_mexpr :: "ipassignment \<Rightarrow> iface \<Rightarrow> common_primitive match_expr" where
  "ipassmt_iface_constrain_srcip_mexpr ipassmt ifce = (case ipassmt ifce of
          None \<Rightarrow> Match (IIface ifce)
        | Some ips \<Rightarrow> MatchAnd
            (Match (IIface ifce))
            (match_list_to_match_expr (map (Match \<circ> Src) (map (\<lambda>(ip, n). (Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) n)) ips)))
        )"


(*TODO: move*)
lemma ipv4s_to_set_Ip4AddrNetmask_case:
  "ipv4s_to_set (case x of (ip, x) \<Rightarrow> Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) x) =
       uncurry ipset_from_cidr x"
  by(cases x) (simp add: ipv4addr_of_dotdecimal_dotdecimal_of_ipv4addr ipv4set_from_cidr_def)


lemma matches_ipassmt_iface_constrain_srcip_mexpr: 
    "matches (common_matcher, \<alpha>) (ipassmt_iface_constrain_srcip_mexpr ipassmt ifce) a p \<longleftrightarrow> (case ipassmt ifce of
            None \<Rightarrow> match_iface ifce (p_iiface p)
          | Some ips \<Rightarrow> match_iface ifce (p_iiface p) \<and> p_src p \<in> ipcidr_union_set (set ips)
          )"
proof(cases "ipassmt ifce")
case None thus ?thesis by(simp add: ipassmt_iface_constrain_srcip_mexpr_def match_simplematcher_Iface; fail)
next
case (Some ips)
  have "matches (common_matcher, \<alpha>) (match_list_to_match_expr (map (Match \<circ> Src \<circ> (\<lambda>(ip, y). Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) y)) ips)) a p \<longleftrightarrow>
       (\<exists>m\<in>set ips. p_src p \<in> uncurry ipset_from_cidr m)" 
       apply(simp add: match_list_to_match_expr_disjunction[symmetric] match_list_matches match_simplematcher_SrcDst
          ipv4set_from_cidr_def )
       by(simp add: ipv4s_to_set_Ip4AddrNetmask_case)
  with Some show ?thesis
    apply(simp add: ipv4set_from_cidr_def ipcidr_union_set_uncurry uncurry_case_stmt)
    apply(simp add: ipassmt_iface_constrain_srcip_mexpr_def bunch_of_lemmata_about_matches)
    apply(simp add: match_simplematcher_Iface)
    done
qed


fun iiface_constrain :: "ipassignment \<Rightarrow> common_primitive match_expr \<Rightarrow> common_primitive match_expr" where
  "iiface_constrain _       MatchAny = MatchAny" |
  "iiface_constrain ipassmt (Match (IIface ifce)) = ipassmt_iface_constrain_srcip_mexpr ipassmt ifce" |
  "iiface_constrain ipassmt (Match a) = Match a" |
  "iiface_constrain ipassmt (MatchNot m) = MatchNot (iiface_constrain ipassmt m)" |
  "iiface_constrain ipassmt (MatchAnd m1 m2) = MatchAnd (iiface_constrain ipassmt m1) (iiface_constrain ipassmt m2)"


context
begin
  (*helper1: used in induction case MatchNot*)
  private lemma iiface_constrain_matches_Primitive:
          "matches (common_matcher, \<alpha>) (MatchNot (iiface_constrain ipassmt (Match x))) a p = matches (common_matcher, \<alpha>) (MatchNot (Match x)) a p \<longleftrightarrow>
           matches (common_matcher, \<alpha>) (iiface_constrain ipassmt (Match x)) a p = matches (common_matcher, \<alpha>) (Match x) a p"
  proof(cases x)
  case (IIface ifce)
    have "(matches (common_matcher, \<alpha>) (MatchNot (ipassmt_iface_constrain_srcip_mexpr ipassmt ifce)) a p = (\<not> match_iface ifce (p_iiface p))) \<longleftrightarrow>
      (matches (common_matcher, \<alpha>) (ipassmt_iface_constrain_srcip_mexpr ipassmt ifce) a p = match_iface ifce (p_iiface p))"
    proof(cases "ipassmt ifce")
    case None thus ?thesis
       apply(simp add: matches_ipassmt_iface_constrain_srcip_mexpr)
       apply(simp add: ipassmt_iface_constrain_srcip_mexpr_def match_simplematcher_Iface_not)
       done
     next
     case (Some ips)
       {  fix ips
          have "matches (common_matcher, \<alpha>)
                 (MatchNot (match_list_to_match_expr (map (Match \<circ> Src \<circ> (\<lambda>(ip, y). Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) y)) ips))) a p \<longleftrightarrow>
                 (p_src p \<notin> ipcidr_union_set (set ips))"
        apply(induction ips)
         apply(simp add: bunch_of_lemmata_about_matches ipcidr_union_set_def)
        apply(simp add: MatchOr_MatchNot)
        apply(simp add: ipcidr_union_set_uncurry)
        apply(simp add: match_simplematcher_SrcDst_not)
        apply(thin_tac _)
        apply(simp add: ipv4s_to_set_Ip4AddrNetmask_case ipv4set_from_cidr_def)
        done
       } note helper=this
       from Some show ?thesis
         apply(simp add: matches_ipassmt_iface_constrain_srcip_mexpr)
         apply(simp add: ipassmt_iface_constrain_srcip_mexpr_def match_simplematcher_Iface_not)
         apply(simp add: matches_DeMorgan)
         apply(simp add: helper)
         apply(simp add: match_simplematcher_Iface_not)
         by blast
     qed
     with IIface show ?thesis by(simp add: match_simplematcher_Iface_not match_simplematcher_Iface)
  qed(simp_all)
  
  
  (*helper2: used in induction base case*)
  private lemma matches_ipassmt_iface_constrain_srcip_mexpr_case_Iface:
        fixes ifce::iface
        assumes "ipassmt_sanity_nowildcards ipassmt" and "case ipassmt (Iface (p_iiface p)) of Some ips \<Rightarrow> p_src p \<in> ipcidr_union_set (set ips)"
        shows   "matches (common_matcher, \<alpha>) (ipassmt_iface_constrain_srcip_mexpr ipassmt ifce) a p \<longleftrightarrow>
                 matches (common_matcher, \<alpha>) (Match (IIface ifce)) a p"
  proof -
    have "matches (common_matcher, \<alpha>) (ipassmt_iface_constrain_srcip_mexpr ipassmt ifce) a p = match_iface ifce (p_iiface p)"
      proof(cases "ipassmt (Iface (p_iiface p))")
      case None
      from None show ?thesis
        proof(cases "ipassmt ifce")
          case None thus ?thesis by(simp add: matches_ipassmt_iface_constrain_srcip_mexpr)
          next
          case (Some a)
           from assms(1) have "\<not> match_iface ifce (p_iiface p)"
           apply(rule ipassmt_sanity_nowildcards_match_iface)
            by(simp_all add: Some None)
          with Some show ?thesis by(simp add: matches_ipassmt_iface_constrain_srcip_mexpr)
        qed
      next
      case (Some x)
        with assms(2) have assms2: "p_src p \<in> ipcidr_union_set (set x)" by(simp) (*unused*)
        show ?thesis
        proof(cases "ipassmt ifce")
          case None thus ?thesis by(simp add: matches_ipassmt_iface_constrain_srcip_mexpr)
          next
          case (Some y) with assms(2) have "(match_iface ifce (p_iiface p) \<and> p_src p \<in> ipcidr_union_set (set y)) = match_iface ifce (p_iiface p)"
            apply(cases ifce)
            apply(rename_tac ifce_str)
            apply(case_tac "ifce_str = (p_iiface p)")
             apply (simp add: match_iface_refl; fail)
            apply(simp)
            apply(subgoal_tac "\<not> match_iface (Iface ifce_str) (p_iiface p)")
             apply(simp)
            using assms(1) by (metis domI iface.sel iface_is_wildcard_def ipassmt_sanity_nowildcards_def match_iface_case_nowildcard)
            with Some show ?thesis by(simp add: matches_ipassmt_iface_constrain_srcip_mexpr)
        qed
    qed
    thus ?thesis by(simp add: match_simplematcher_Iface)
  qed
    

  lemma matches_iiface_constrain:
       "normalized_nnf_match m \<Longrightarrow> ipassmt_sanity_nowildcards ipassmt \<Longrightarrow>
        (case ipassmt (Iface (p_iiface p)) of Some ips \<Rightarrow> p_src p \<in> ipcidr_union_set (set ips)) \<Longrightarrow>
        matches (common_matcher, \<alpha>) (iiface_constrain ipassmt m) a p \<longleftrightarrow> matches (common_matcher, \<alpha>) m a p"
    proof(induction m)
    case MatchAny thus ?case by simp
    next
    case (MatchNot m)
      hence IH: "normalized_nnf_match m \<Longrightarrow> matches (common_matcher, \<alpha>) (iiface_constrain ipassmt m) a p = matches (common_matcher, \<alpha>) m a p" by blast
      with MatchNot.prems IH show ?case by(induction m) (simp_all add: iiface_constrain_matches_Primitive)
    next
    case(Match x) thus ?case
      proof(cases x)
        case (IIface ifce) with Match show ?thesis using matches_ipassmt_iface_constrain_srcip_mexpr_case_Iface by simp
      qed(simp_all)
    next
    case (MatchAnd m1 m2) thus ?case by(simp add: bunch_of_lemmata_about_matches)
    qed
end




subsection\<open>Sanity checking the assumption\<close>
(*TODO: we need a good formulation of the assumption. the case stuff is so undefined fo the None case \<dots>
        EX-quantor is too strong
        Also holds if EX replaced by ALL*)
lemma "(\<exists>ips. ipassmt (Iface (p_iiface p)) = Some ips \<and> p_src p \<in> ipcidr_union_set (set ips)) \<Longrightarrow>
       (case ipassmt (Iface (p_iiface p)) of Some ips \<Rightarrow> p_src p \<in> ipcidr_union_set (set ips))"
  apply(cases "ipassmt (Iface (p_iiface p))")
   apply(simp_all)
  done



text\<open>Sanity check:
      If we assume that there are no spoofed packets, spoofing protection is trivially fulfilled.\<close>
(*TODO: only 32 simple_packet_scheme*)
lemma "\<forall> p:: (32,'pkt_ext) simple_packet_scheme. Iface (p_iiface p) \<in> dom ipassmt \<longrightarrow> p_src p \<in> ipcidr_union_set (set (the (ipassmt (Iface (p_iiface p))))) \<Longrightarrow> no_spoofing TYPE('pkt_ext) ipassmt rs"
  apply(simp add: no_spoofing_def)
  apply(clarify)
  apply(rename_tac iface ips p)
  apply(thin_tac "_,_\<turnstile> \<langle>rs, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision FinalAllow") (*not needed*)
  apply(erule_tac x="p\<lparr>p_iiface := iface_sel iface\<rparr>" in allE)
  apply(auto)
  done

text\<open>Sanity check:
      If the firewall features spoofing protection and we look at a packet which was allowed by the firewall.
      Then the packet's src ip must be according to ipassmt. (case Some)
      We don't case about packets from an interface which are not defined in ipassmt. (case None)\<close>
lemma 
  fixes p :: "(32,'pkt_ext) simple_packet_scheme"
  shows "no_spoofing TYPE('pkt_ext) ipassmt rs \<Longrightarrow> 
      (common_matcher, in_doubt_allow),p\<turnstile> \<langle>rs, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision FinalAllow \<Longrightarrow>
       case ipassmt (Iface (p_iiface p)) of Some ips \<Rightarrow> p_src p \<in> ipcidr_union_set (set ips) | None \<Rightarrow> True"
  apply(simp add: no_spoofing_def)
  apply(case_tac "Iface (p_iiface p) \<in> dom ipassmt")
   apply(erule_tac x="Iface (p_iiface p)" in ballE)
    apply(simp_all)
   apply(erule_tac x="p" in allE)
   apply(simp)
   apply fastforce
  by (simp add: domIff)






subsection\<open>Replacing Interfaces Completely\<close>
text\<open>This is a stringer rewriting since it removes the interface completely.
      However, it requires @{const ipassmt_sanity_disjoint}\<close>

thm ipassmt_sanity_disjoint_def

definition ipassmt_iface_replace_srcip_mexpr :: "ipassignment \<Rightarrow> iface \<Rightarrow> common_primitive match_expr" where
  "ipassmt_iface_replace_srcip_mexpr ipassmt ifce = (case ipassmt ifce of
          None \<Rightarrow> Match (IIface ifce)
        | Some ips \<Rightarrow> (match_list_to_match_expr (map (Match \<circ> Src) (map (\<lambda>(ip, n). (Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) n)) ips)))
        )"


lemma matches_ipassmt_iface_replace_srcip_mexpr: 
    "matches (common_matcher, \<alpha>) (ipassmt_iface_replace_srcip_mexpr ipassmt ifce) a p \<longleftrightarrow> (case ipassmt ifce of
            None \<Rightarrow> match_iface ifce (p_iiface p)
          | Some ips \<Rightarrow> (*match_iface ifce (p_iiface p) \<and>*) p_src p \<in> ipcidr_union_set (set ips)
          )"
proof(cases "ipassmt ifce")
case None thus ?thesis by(simp add: ipassmt_iface_replace_srcip_mexpr_def match_simplematcher_Iface)
next
case (Some ips)
  have "matches (common_matcher, \<alpha>) (match_list_to_match_expr (map (Match \<circ> Src \<circ> (\<lambda>(ip, y). Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) y)) ips)) a p \<longleftrightarrow>
       (\<exists>m\<in>set ips. p_src p \<in> (uncurry ipset_from_cidr m))" 
       by(simp add: match_list_to_match_expr_disjunction[symmetric]
                    match_list_matches match_simplematcher_SrcDst ipv4s_to_set_Ip4AddrNetmask_case)
  with Some show ?thesis
    apply(simp add: ipassmt_iface_replace_srcip_mexpr_def bunch_of_lemmata_about_matches)
    apply(simp add: match_simplematcher_Iface ipcidr_union_set_uncurry)
    done
qed


fun iiface_rewrite :: "ipassignment \<Rightarrow> common_primitive match_expr \<Rightarrow> common_primitive match_expr" where
  "iiface_rewrite _       MatchAny = MatchAny" |
  "iiface_rewrite ipassmt (Match (IIface ifce)) = ipassmt_iface_replace_srcip_mexpr ipassmt ifce" |
  "iiface_rewrite ipassmt (Match a) = Match a" |
  "iiface_rewrite ipassmt (MatchNot m) = MatchNot (iiface_rewrite ipassmt m)" |
  "iiface_rewrite ipassmt (MatchAnd m1 m2) = MatchAnd (iiface_rewrite ipassmt m1) (iiface_rewrite ipassmt m2)"


context
begin
  (*helper1: used in induction case MatchNot*)
  private lemma iiface_rewrite_matches_Primitive:
          "matches (common_matcher, \<alpha>) (MatchNot (iiface_rewrite ipassmt (Match x))) a p = matches (common_matcher, \<alpha>) (MatchNot (Match x)) a p \<longleftrightarrow>
           matches (common_matcher, \<alpha>) (iiface_rewrite ipassmt (Match x)) a p = matches (common_matcher, \<alpha>) (Match x) a p"
  proof(cases x)
  case (IIface ifce)
    have "(matches (common_matcher, \<alpha>) (MatchNot (ipassmt_iface_replace_srcip_mexpr ipassmt ifce)) a p = (\<not> match_iface ifce (p_iiface p))) \<longleftrightarrow>
      (matches (common_matcher, \<alpha>) (ipassmt_iface_replace_srcip_mexpr ipassmt ifce) a p = match_iface ifce (p_iiface p))"
    proof(cases "ipassmt ifce")
    case None thus ?thesis
       apply(simp add: matches_ipassmt_iface_replace_srcip_mexpr)
       apply(simp add: ipassmt_iface_replace_srcip_mexpr_def match_simplematcher_Iface_not)
       done
     next
     case (Some ips)
       {  fix ips
          have "matches (common_matcher, \<alpha>)
                 (MatchNot (match_list_to_match_expr (map (Match \<circ> Src \<circ> (\<lambda>(ip, y). Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) y)) ips))) a p \<longleftrightarrow>
                 (p_src p \<notin> ipcidr_union_set (set ips))"
        apply(induction ips)
         apply(simp add: bunch_of_lemmata_about_matches ipcidr_union_set_def)
        apply(simp add: MatchOr_MatchNot)
        apply(simp add: ipcidr_union_set_uncurry)
        apply(simp add: match_simplematcher_SrcDst_not)
        apply(thin_tac _)
        apply(simp add: ipv4s_to_set_Ip4AddrNetmask_case)
        done
       } note helper=this
       from Some show ?thesis
         apply(simp add: matches_ipassmt_iface_replace_srcip_mexpr)
         apply(simp add: ipassmt_iface_replace_srcip_mexpr_def match_simplematcher_Iface_not)
         apply(simp add: helper)
         done
     qed
     with IIface show ?thesis by(simp add: match_simplematcher_Iface_not match_simplematcher_Iface)
  qed(simp_all)


  (*helper2: used in induction base case*)
  private lemma matches_ipassmt_iface_replace_srcip_mexpr_case_Iface:
        fixes ifce::iface
        assumes "ipassmt_sanity_nowildcards ipassmt"
            and "ipassmt_sanity_disjoint ipassmt"
            and "ipassmt (Iface (p_iiface p)) = Some p_ips \<and> p_src p \<in> ipcidr_union_set (set p_ips)"
        shows   "matches (common_matcher, \<alpha>) (ipassmt_iface_replace_srcip_mexpr ipassmt ifce) a p \<longleftrightarrow>
                 matches (common_matcher, \<alpha>) (Match (IIface ifce)) a p"
  proof -
    have "matches (common_matcher, \<alpha>) (ipassmt_iface_replace_srcip_mexpr ipassmt ifce) a p = match_iface ifce (p_iiface p)"
      proof -
        show ?thesis
        proof(cases "ipassmt ifce")
          case None thus ?thesis by(simp add: matches_ipassmt_iface_replace_srcip_mexpr)
          next
          case (Some y) with assms(2) have "p_src p \<in> ipcidr_union_set (set y) = match_iface ifce (p_iiface p)"
            using assms(1) assms(3) ipassmt_disjoint_matcheq_iifce_srcip by blast
            with Some show ?thesis by(simp add: matches_ipassmt_iface_replace_srcip_mexpr)
        qed
    qed
    thus ?thesis by(simp add: match_simplematcher_Iface)
  qed



  lemma matches_iiface_rewrite:
       "normalized_nnf_match m \<Longrightarrow> ipassmt_sanity_nowildcards ipassmt \<Longrightarrow> ipassmt_sanity_disjoint ipassmt \<Longrightarrow>
        (\<exists>p_ips. ipassmt (Iface (p_iiface p)) = Some p_ips \<and> p_src p \<in> ipcidr_union_set (set p_ips)) \<Longrightarrow>
        matches (common_matcher, \<alpha>) (iiface_rewrite ipassmt m) a p \<longleftrightarrow> matches (common_matcher, \<alpha>) m a p"
    proof(induction m)
    case MatchAny thus ?case by simp
    next
    case (MatchNot m)
      hence IH: "normalized_nnf_match m \<Longrightarrow>
        matches (common_matcher, \<alpha>) (iiface_rewrite ipassmt m) a p =matches (common_matcher, \<alpha>) m a p" by blast
      with MatchNot.prems IH show ?case by(induction m) (simp_all add: iiface_rewrite_matches_Primitive)
    next
    case(Match x) thus ?case
      proof(cases x)
        case (IIface ifce) with Match show ?thesis
        apply(cases "ipassmt (Iface (p_iiface p))")
         prefer 2
          apply(simp add: matches_ipassmt_iface_replace_srcip_mexpr_case_Iface; fail)
        by auto
      qed(simp_all)
    next
    case (MatchAnd m1 m2) thus ?case by(simp add: bunch_of_lemmata_about_matches)
    qed

end

  text\<open>Finally, we show that @{const ipassmt_sanity_disjoint} is really needed.\<close>
  lemma iface_replace_needs_ipassmt_disjoint:
    assumes "ipassmt_sanity_nowildcards ipassmt"
    and iface_replace: "\<And> ifce p:: 32 simple_packet.
          (matches (common_matcher, \<alpha>) (ipassmt_iface_replace_srcip_mexpr ipassmt ifce) a p \<longleftrightarrow> matches (common_matcher, \<alpha>) (Match (IIface ifce)) a p)" 
    shows "ipassmt_sanity_disjoint ipassmt"
  unfolding ipassmt_sanity_disjoint_def
  proof(intro ballI impI)
    fix i1 i2
    assume "i1 \<in> dom ipassmt" and "i2 \<in> dom ipassmt" and "i1 \<noteq> i2"
    from \<open>i1 \<in> dom ipassmt\<close> obtain i1_ips where i1_ips: "ipassmt i1 = Some i1_ips" by blast
    from \<open>i2 \<in> dom ipassmt\<close> obtain i2_ips where i2_ips: "ipassmt i2 = Some i2_ips" by blast

    { fix p :: "32 simple_packet"
      from iface_replace[of  i1 "p\<lparr> p_iiface := iface_sel i2\<rparr>"] have
        "(p_src p \<in> ipcidr_union_set (set i2_ips) \<Longrightarrow> (p_src p \<in> ipcidr_union_set (set i1_ips)) = match_iface i1 (iface_sel i2))"
      apply(simp add: match_simplematcher_Iface  \<open>i1 \<in> dom ipassmt\<close>)
      apply(simp add: matches_ipassmt_iface_replace_srcip_mexpr i1_ips)
      done
      with \<open>i1 \<noteq> i2\<close> have "\<not> (p_src p \<in> ipcidr_union_set (set i2_ips) \<and> (p_src p \<in> ipcidr_union_set (set i1_ips)))"
        by (metis \<open>i1 \<in> dom ipassmt\<close> assms(1) iface.exhaust_sel iface_is_wildcard_def ipassmt_sanity_nowildcards_def match_iface_case_nowildcard) 
    }
    hence "\<And>src. \<not> (src \<in> ipcidr_union_set (set i2_ips) \<and> (src \<in> ipcidr_union_set (set i1_ips)))"
      by (metis select_convs(3)) 

    thus "ipcidr_union_set (set (the (ipassmt i1))) \<inter> ipcidr_union_set (set (the (ipassmt i2))) = {}"
      apply(simp add: i1_ips i2_ips)
      by blast
  qed






definition "iface_try_rewrite ipassmt rs \<equiv> if ipassmt_sanity_disjoint (map_of ipassmt) \<and> ipassmt_sanity_defined rs (map_of ipassmt) then
  optimize_matches (iiface_rewrite (map_of_ipassmt ipassmt)) rs
  else
  optimize_matches (iiface_constrain (map_of_ipassmt ipassmt)) rs"


text\<open>In @{file "Transform.thy"} there should be the final correctness theorem for @{text "iface_try_rewrite"}. 
     Here are some structural properties.\<close>


lemma iface_try_rewrite_simplers: "simple_ruleset rs \<Longrightarrow> simple_ruleset (iface_try_rewrite ipassmt rs)"
    by(simp add: iface_try_rewrite_def optimize_matches_simple_ruleset)


(*TODO: move?*)
lemma match_list_to_match_expr_not_has_disc: 
    "\<forall>a. \<not> disc (X a) \<Longrightarrow> \<not> has_disc disc (match_list_to_match_expr (map (Match \<circ> X) ls))"
  apply(induction ls)
   apply(simp; fail)
  by(simp add: MatchOr_def)



lemma iiface_rewrite_preserves_nodisc: "\<forall>a. \<not> disc (Src a) \<Longrightarrow> \<not> has_disc disc m \<Longrightarrow> \<not> has_disc disc (iiface_rewrite ipassmt m)"
  proof(induction ipassmt m rule: iiface_rewrite.induct)
  case 2 
    have "\<forall>a. \<not> disc (Src a) \<Longrightarrow> \<not> disc (IIface ifce) \<Longrightarrow> \<not> has_disc disc (ipassmt_iface_replace_srcip_mexpr ipassmt ifce)"
      for ifce ipassmt
      apply(simp add: ipassmt_iface_replace_srcip_mexpr_def split: option.split)
      apply(intro allI impI, rename_tac ips)
      apply(drule_tac X=Src and ls="map (\<lambda>(ip, n). (Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) n)) ips" in match_list_to_match_expr_not_has_disc)
      apply(simp)
      done
    with 2 show ?case by simp
  qed(simp_all)
lemma iiface_constrain_preserves_nodisc: "\<forall>a. \<not> disc (Src a) \<Longrightarrow> \<not> has_disc disc m \<Longrightarrow> \<not> has_disc disc (iiface_constrain ipassmt m)"
  proof(induction ipassmt m rule: iiface_rewrite.induct)
  case 2 
    have "\<forall>a. \<not> disc (Src a) \<Longrightarrow> \<not> disc (IIface ifce) \<Longrightarrow> \<not> has_disc disc (ipassmt_iface_constrain_srcip_mexpr ipassmt ifce)"
      for ifce ipassmt
      apply(simp add: ipassmt_iface_constrain_srcip_mexpr_def split: option.split)
      apply(intro allI impI, rename_tac ips)
      apply(drule_tac X=Src and ls="map (\<lambda>(ip, n). (Ip4AddrNetmask (dotdecimal_of_ipv4addr ip) n)) ips" in match_list_to_match_expr_not_has_disc)
      apply(simp)
      done
    with 2 show ?case by simp
  qed(simp_all)

lemma iface_try_rewrite_preserves_nodisc: "\<forall>a. \<not> disc (Src a) \<Longrightarrow> 
      \<forall>m\<in>get_match ` set rs. \<not> has_disc disc m \<Longrightarrow>
        \<forall>m\<in>get_match ` set (iface_try_rewrite ipassmt rs). \<not> has_disc disc m"   
  apply(simp add: iface_try_rewrite_def)
  apply(intro conjI impI)
   apply(rule optimize_matches_preserves[simplified])
   apply(simp add: iiface_rewrite_preserves_nodisc)
  apply(rule optimize_matches_preserves[simplified])
  apply(simp add: iiface_constrain_preserves_nodisc)
  done


end