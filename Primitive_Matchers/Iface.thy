theory Iface
imports String "../Output_Format/Negation_Type"
begin

section{*Network Interfaces*}

(*TODO: add some rule that says an interface starting with ! is invalid (because we want to fail if negation occurs!)*)

datatype iface = Iface "string"  --"no negation supported, but wildcards"


definition IfaceAny :: iface where
  "IfaceAny \<equiv> Iface ''+''"
(* there is no IfaceFalse, proof below *)

text_raw{*If the interface name ends in a ``+'', then any interface which begins with this name will match. (man iptables)

Here is how iptables handles this wildcard on my system. A packet for the loopback interface \texttt{lo} is matched by the following expressions
\begin{itemize}
  \item lo
  \item lo+
  \item l+
  \item +
\end{itemize}

It is not matched by the following expressions
\begin{itemize}
  \item lo++
  \item lo+++
  \item lo1+
  \item lo1
\end{itemize}

By the way: \texttt{Warning: weird characters in interface ` ' ('/' and ' ' are not allowed by the kernel).}
*}


  
subsection{*Helpers for the interface name (@{typ string})*}
  (*Do not use outside this thy! Type is really misleading.*)
  text{*
    argument 1: interface as in firewall rule - Wildcard support
    argument 2: interface a packet came from - No wildcard support*}
  fun internal_iface_name_match :: "string \<Rightarrow> string \<Rightarrow> bool" where
    "internal_iface_name_match []     []         \<longleftrightarrow> True" |
    "internal_iface_name_match (i#is) []         \<longleftrightarrow> (i = CHR ''+'' \<and> is = [])" |
    "internal_iface_name_match []     (_#_)      \<longleftrightarrow> False" |
    "internal_iface_name_match (i#is) (p_i#p_is) \<longleftrightarrow> (if (i = CHR ''+'' \<and> is = []) then True else (
          (p_i = i) \<and> internal_iface_name_match is p_is
    ))"
  
  (*<*)
  --"Examples"
    lemma "internal_iface_name_match ''lo'' ''lo''" by eval
    lemma "internal_iface_name_match ''lo+'' ''lo''" by eval
    lemma "internal_iface_name_match ''l+'' ''lo''" by eval
    lemma "internal_iface_name_match ''+'' ''lo''" by eval
    lemma "\<not> internal_iface_name_match ''lo++'' ''lo''" by eval
    lemma "\<not> internal_iface_name_match ''lo+++'' ''lo''" by eval
    lemma "\<not> internal_iface_name_match ''lo1+'' ''lo''" by eval
    lemma "\<not> internal_iface_name_match ''lo1'' ''lo''" by eval
    text{*The wildcard interface name*}
    lemma "internal_iface_name_match ''+'' ''''" by eval (*>*)


  fun iface_name_is_wildcard :: "string \<Rightarrow> bool" where
    "iface_name_is_wildcard [] \<longleftrightarrow> False" |
    "iface_name_is_wildcard [s] \<longleftrightarrow> s = CHR ''+''" |
    "iface_name_is_wildcard (_#ss) \<longleftrightarrow> iface_name_is_wildcard ss"
  lemma iface_name_is_wildcard_alt: "iface_name_is_wildcard eth \<longleftrightarrow> eth \<noteq> [] \<and> last eth = CHR ''+''"
    apply(induction eth rule: iface_name_is_wildcard.induct)
      apply(simp_all)
    done
  lemma iface_name_is_wildcard_alt': "iface_name_is_wildcard eth \<longleftrightarrow> eth \<noteq> [] \<and> hd (rev eth) = CHR ''+''"
    apply(simp add: iface_name_is_wildcard_alt)
    using hd_rev by fastforce
  lemma iface_name_is_wildcard_fst: "iface_name_is_wildcard (i # is) \<Longrightarrow> is \<noteq> [] \<Longrightarrow> iface_name_is_wildcard is"
    by(simp add: iface_name_is_wildcard_alt)


  fun internal_iface_name_to_set :: "string \<Rightarrow> string set" where
    "internal_iface_name_to_set i = (if \<not> iface_name_is_wildcard i
      then
        {i}
      else
        {(butlast i)@cs | cs. True})"
   lemma "{(butlast i)@cs | cs. True} = (\<lambda>s. (butlast i)@s) ` (UNIV::string set)" by fastforce
   lemma internal_iface_name_to_set: "internal_iface_name_match i p_iface \<longleftrightarrow> p_iface \<in> internal_iface_name_to_set i"
    apply(induction i p_iface rule: internal_iface_name_match.induct)
       apply(simp_all)
    apply(safe)
           apply(simp_all add: iface_name_is_wildcard_fst)
     apply (metis (full_types) iface_name_is_wildcard.simps(3) list.exhaust)
    by (metis append_butlast_last_id)

    lemma internal_iface_name_match_refl: "internal_iface_name_match i i"
    proof -
    { fix i j
      have "i=j \<Longrightarrow> internal_iface_name_match i j"
        apply(induction i j rule: internal_iface_name_match.induct)
        by(simp_all)
    } thus ?thesis by simp
    qed

subsection{*Matching*}
  fun match_iface :: "iface \<Rightarrow> string \<Rightarrow> bool" where
    "match_iface (Iface i) p_iface \<longleftrightarrow> internal_iface_name_match i p_iface"
  
  --"Examples"
    lemma "  match_iface (Iface ''lo'')    ''lo''"
          "  match_iface (Iface ''lo+'')   ''lo''"
          "  match_iface (Iface ''l+'')    ''lo''"
          "  match_iface (Iface ''+'')     ''lo''"
          "\<not> match_iface (Iface ''lo++'')  ''lo''"
          "\<not> match_iface (Iface ''lo+++'') ''lo''"
          "\<not> match_iface (Iface ''lo1+'')  ''lo''"
          "\<not> match_iface (Iface ''lo1'')   ''lo''"
          "  match_iface (Iface ''+'')     ''eth0''"
          "  match_iface (Iface ''+'')     ''eth0''"
          "  match_iface (Iface ''eth+'')  ''eth0''"
          "\<not> match_iface (Iface ''lo+'')   ''eth0''"
          "  match_iface (Iface ''lo+'')   ''loX''"
          "\<not> match_iface (Iface '''')      ''loX''"
          (*<*)by eval+(*>*)

  lemma match_IfaceAny: "match_iface IfaceAny i"
    by(cases i, simp_all add: IfaceAny_def)
  lemma match_IfaceFalse: "\<not>(\<exists> IfaceFalse. (\<forall>i. \<not> match_iface IfaceFalse i))"
    apply(simp)
    apply(intro allI, rename_tac IfaceFalse)
    apply(case_tac IfaceFalse, rename_tac name)
    apply(rule_tac x="name" in exI)
    by(simp add: internal_iface_name_match_refl)
    


  --{*@{const match_iface} explained by the individual cases*}
  lemma match_iface_case_nowildcard: "\<not> iface_name_is_wildcard i \<Longrightarrow> match_iface (Iface i) p_i \<longleftrightarrow> i = p_i"
    apply(simp)
    apply(induction i p_i rule: internal_iface_name_match.induct)
       apply(auto simp add: iface_name_is_wildcard_alt split: split_if_asm)
    done
  lemma match_iface_case_wildcard_prefix:
    "iface_name_is_wildcard i \<Longrightarrow> match_iface (Iface i) p_i \<longleftrightarrow> butlast i = take (length i - 1) p_i"
    apply(simp)
    apply(induction i p_i rule: internal_iface_name_match.induct)
       apply(simp_all)
     apply(simp add: iface_name_is_wildcard_alt split: split_if_asm)
    apply(intro conjI)
     apply(simp add: iface_name_is_wildcard_alt split: split_if_asm)
    apply(intro impI)
    apply(simp add: iface_name_is_wildcard_fst)
    by (metis One_nat_def length_0_conv list.sel(1) list.sel(3) take_Cons')
  lemma match_iface_case_wildcard_length: "iface_name_is_wildcard i \<Longrightarrow> match_iface (Iface i) p_i \<Longrightarrow> length p_i \<ge> (length i - 1)"
    apply(simp)
    apply(induction i p_i rule: internal_iface_name_match.induct)
       apply(simp_all)
     apply(simp add: iface_name_is_wildcard_alt split: split_if_asm)
    done
  corollary match_iface_case_wildcard:
    "iface_name_is_wildcard i \<Longrightarrow> match_iface (Iface i) p_i \<longleftrightarrow> butlast i = take (length i - 1) p_i \<and> length p_i \<ge> (length i - 1)"
    using match_iface_case_wildcard_length match_iface_case_wildcard_prefix by blast


  lemma match_iface_set: "match_iface (Iface i) p_iface \<longleftrightarrow> p_iface \<in> internal_iface_name_to_set i"
    using internal_iface_name_to_set by simp

  definition internal_iface_name_wildcard_longest :: "string \<Rightarrow> string \<Rightarrow> string option" where
    "internal_iface_name_wildcard_longest i1 i2 = (
      if 
        take (min (length i1 - 1) (length i2 - 1)) i1 = take (min (length i1 - 1) (length i2 - 1)) i2
      then
        Some (if length i1 \<le> length i2 then i2 else i1)
      else
        None)"
  lemma "internal_iface_name_wildcard_longest ''eth+'' ''eth3+'' = Some ''eth3+''" by eval
  lemma "internal_iface_name_wildcard_longest ''eth+'' ''e+'' = Some ''eth+''" by eval
  lemma "internal_iface_name_wildcard_longest ''eth+'' ''lo'' = None" by eval

  lemma internal_iface_name_wildcard_longest_commute: "iface_name_is_wildcard i1 \<Longrightarrow> iface_name_is_wildcard i2 \<Longrightarrow> 
    internal_iface_name_wildcard_longest i1 i2 = internal_iface_name_wildcard_longest i2 i1"
    apply(simp add: internal_iface_name_wildcard_longest_def)
    apply(safe)
      apply(simp_all add: iface_name_is_wildcard_alt)
      apply (metis One_nat_def append_butlast_last_id butlast_conv_take)
     by (metis min.commute)+
   lemma internal_iface_name_wildcard_longest_refl: "internal_iface_name_wildcard_longest i i = Some i"
    by(simp add: internal_iface_name_wildcard_longest_def)
    

  lemma internal_iface_name_wildcard_longest_correct: "iface_name_is_wildcard i1 \<Longrightarrow> iface_name_is_wildcard i2 \<Longrightarrow> 
         match_iface (Iface i1) p_i \<and> match_iface (Iface i2) p_i \<longleftrightarrow>
         (case internal_iface_name_wildcard_longest i1 i2 of None \<Rightarrow> False | Some x \<Rightarrow> match_iface (Iface x) p_i)"
    apply(simp split:option.split)
    apply(intro conjI impI allI)
     apply(simp add: internal_iface_name_wildcard_longest_def split: split_if_asm)
     apply(drule match_iface_case_wildcard_prefix[of i1 p_i, simplified butlast_conv_take match_iface.simps])
     apply(drule match_iface_case_wildcard_prefix[of i2 p_i, simplified butlast_conv_take match_iface.simps])
     apply (metis One_nat_def min.commute take_take)
    apply(rename_tac x)
    apply(simp add: internal_iface_name_wildcard_longest_def split: split_if_asm)
     apply(simp add: min_def split: split_if_asm)
     apply(case_tac "internal_iface_name_match x p_i")
      apply(simp_all)
     apply(frule match_iface_case_wildcard_prefix[of i1 p_i])
     apply(frule_tac i=x in match_iface_case_wildcard_prefix[of _ p_i])
     apply(simp add: butlast_conv_take)
     apply (metis min_def take_take)
    apply(case_tac "internal_iface_name_match x p_i")
     apply(simp_all)
    apply(frule match_iface_case_wildcard_prefix[of i2 p_i])
    apply(frule_tac i=x in match_iface_case_wildcard_prefix[of _ p_i])
    apply(simp add: butlast_conv_take min_def split:split_if_asm)
    by (metis min.commute min_def take_take)

  fun iface_conjunct :: "iface \<Rightarrow> iface \<Rightarrow> iface option" where
    "iface_conjunct (Iface i1) (Iface i2) = (case (iface_name_is_wildcard i1, iface_name_is_wildcard i2) of
      (True,  True) \<Rightarrow> map_option Iface  (internal_iface_name_wildcard_longest i1 i2) |
      (True,  False) \<Rightarrow> (if match_iface (Iface i1) i2 then Some (Iface i2) else None) |
      (False, True) \<Rightarrow> (if match_iface (Iface i2) i1 then Some (Iface i1) else None) |
      (False, False) \<Rightarrow> (if i1 = i2 then Some (Iface i1) else None))"

  lemma iface_conjunct: "match_iface i1 p_i \<and> match_iface i2 p_i \<longleftrightarrow>
         (case iface_conjunct i1 i2 of None \<Rightarrow> False | Some x \<Rightarrow> match_iface x p_i)"
    apply(cases i1, cases i2, rename_tac i1name i2name)
    apply(simp split: bool.split option.split)
    apply(safe)
                                     apply(simp_all add: internal_iface_name_wildcard_longest_refl)
                 apply(auto dest: internal_iface_name_wildcard_longest_correct)
             apply (metis match_iface.simps match_iface_case_nowildcard)+
    done


    hide_const (open) internal_iface_name_wildcard_longest

hide_const (open) internal_iface_name_match

end
