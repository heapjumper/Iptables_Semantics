theory Iface
imports String "../Common/Negation_Type"
begin

section{*Network Interfaces*}

(*TODO: add some rule that says an interface starting with ! is invalid (because we want to fail if negation occurs!) See man iptables.
  But the parser/lexer should handle this*)
datatype iface = Iface (iface_sel: "string")  --"no negation supported, but wildcards"

definition ifaceAny :: iface where
  "ifaceAny \<equiv> Iface ''+''"
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


context
begin
    
  subsection{*Helpers for the interface name (@{typ string})*}
    (*Do not use outside this thy! Type is really misleading.*)
    text{*
      argument 1: interface as in firewall rule - Wildcard support
      argument 2: interface a packet came from - No wildcard support*}
    private fun internal_iface_name_match :: "string \<Rightarrow> string \<Rightarrow> bool" where
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
  
  
    private fun iface_name_is_wildcard :: "string \<Rightarrow> bool" where
      "iface_name_is_wildcard [] \<longleftrightarrow> False" |
      "iface_name_is_wildcard [s] \<longleftrightarrow> s = CHR ''+''" |
      "iface_name_is_wildcard (_#ss) \<longleftrightarrow> iface_name_is_wildcard ss"
    private lemma iface_name_is_wildcard_alt: "iface_name_is_wildcard eth \<longleftrightarrow> eth \<noteq> [] \<and> last eth = CHR ''+''"
      apply(induction eth rule: iface_name_is_wildcard.induct)
        apply(simp_all)
      done
    private lemma iface_name_is_wildcard_alt': "iface_name_is_wildcard eth \<longleftrightarrow> eth \<noteq> [] \<and> hd (rev eth) = CHR ''+''"
      apply(simp add: iface_name_is_wildcard_alt)
      using hd_rev by fastforce
    private lemma iface_name_is_wildcard_fst: "iface_name_is_wildcard (i # is) \<Longrightarrow> is \<noteq> [] \<Longrightarrow> iface_name_is_wildcard is"
      by(simp add: iface_name_is_wildcard_alt)
  
    private fun internal_iface_name_to_set :: "string \<Rightarrow> string set" where
      "internal_iface_name_to_set i = (if \<not> iface_name_is_wildcard i
        then
          {i}
        else
          {(butlast i)@cs | cs. True})"
    private lemma "{(butlast i)@cs | cs. True} = (\<lambda>s. (butlast i)@s) ` (UNIV::string set)" by fastforce
    private lemma internal_iface_name_to_set: "internal_iface_name_match i p_iface \<longleftrightarrow> p_iface \<in> internal_iface_name_to_set i"
      apply(induction i p_iface rule: internal_iface_name_match.induct)
         apply(simp_all)
      apply(safe)
             apply(simp_all add: iface_name_is_wildcard_fst)
       apply (metis (full_types) iface_name_is_wildcard.simps(3) list.exhaust)
      by (metis append_butlast_last_id)
    private lemma internal_iface_name_to_set2: "internal_iface_name_to_set ifce = {i. internal_iface_name_match ifce i}"
      by (simp add: internal_iface_name_to_set)
      
  
    private lemma internal_iface_name_match_refl: "internal_iface_name_match i i"
     proof -
     { fix i j
       have "i=j \<Longrightarrow> internal_iface_name_match i j"
         by(induction i j rule: internal_iface_name_match.induct)(simp_all)
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
  
    lemma match_ifaceAny: "match_iface ifaceAny i"
      by(cases i, simp_all add: ifaceAny_def)
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
  
    private  definition internal_iface_name_wildcard_longest :: "string \<Rightarrow> string \<Rightarrow> string option" where
      "internal_iface_name_wildcard_longest i1 i2 = (
        if 
          take (min (length i1 - 1) (length i2 - 1)) i1 = take (min (length i1 - 1) (length i2 - 1)) i2
        then
          Some (if length i1 \<le> length i2 then i2 else i1)
        else
          None)"
    private lemma "internal_iface_name_wildcard_longest ''eth+'' ''eth3+'' = Some ''eth3+''" by eval
    private lemma "internal_iface_name_wildcard_longest ''eth+'' ''e+'' = Some ''eth+''" by eval
    private lemma "internal_iface_name_wildcard_longest ''eth+'' ''lo'' = None" by eval
  
    private  lemma internal_iface_name_wildcard_longest_commute: "iface_name_is_wildcard i1 \<Longrightarrow> iface_name_is_wildcard i2 \<Longrightarrow> 
      internal_iface_name_wildcard_longest i1 i2 = internal_iface_name_wildcard_longest i2 i1"
      apply(simp add: internal_iface_name_wildcard_longest_def)
      apply(safe)
        apply(simp_all add: iface_name_is_wildcard_alt)
        apply (metis One_nat_def append_butlast_last_id butlast_conv_take)
       by (metis min.commute)+
    private  lemma internal_iface_name_wildcard_longest_refl: "internal_iface_name_wildcard_longest i i = Some i"
      by(simp add: internal_iface_name_wildcard_longest_def)
  
  
    private lemma internal_iface_name_wildcard_longest_correct: "iface_name_is_wildcard i1 \<Longrightarrow> iface_name_is_wildcard i2 \<Longrightarrow> 
             match_iface (Iface i1) p_i \<and> match_iface (Iface i2) p_i \<longleftrightarrow>
             (case internal_iface_name_wildcard_longest i1 i2 of None \<Rightarrow> False | Some x \<Rightarrow> match_iface (Iface x) p_i)"
    proof -
      assume assm1: "iface_name_is_wildcard i1"
         and assm2: "iface_name_is_wildcard i2"
      { assume assm3: "internal_iface_name_wildcard_longest i1 i2 = None" 
        have "\<not> (internal_iface_name_match i1 p_i \<and> internal_iface_name_match i2 p_i)"
        proof -
          from match_iface_case_wildcard_prefix[OF assm1] have 1:
            "internal_iface_name_match i1 p_i = (take (length i1 - 1) i1 = take (length i1 - 1) p_i)" by(simp add: butlast_conv_take)
          from match_iface_case_wildcard_prefix[OF assm2] have 2:
            "internal_iface_name_match i2 p_i = (take (length i2 - 1) i2 = take (length i2 - 1) p_i)" by(simp add: butlast_conv_take)
          from assm3 have 3: "take (min (length i1 - 1) (length i2 - 1)) i1 \<noteq> take (min (length i1 - 1) (length i2 - 1)) i2"
           by(simp add: internal_iface_name_wildcard_longest_def split: split_if_asm)
          from 3 show ?thesis using 1 2 min.commute take_take by metis
        qed
      } note internal_iface_name_wildcard_longest_correct_None=this
    
      { fix X
        assume assm3: "internal_iface_name_wildcard_longest i1 i2 = Some X"
        have "(internal_iface_name_match i1 p_i \<and> internal_iface_name_match i2 p_i) \<longleftrightarrow> internal_iface_name_match X p_i"
        proof -
          from assm3 have assm3': "take (min (length i1 - 1) (length i2 - 1)) i1 = take (min (length i1 - 1) (length i2 - 1)) i2"
            unfolding internal_iface_name_wildcard_longest_def by(simp split: split_if_asm)
      
          { fix i1 i2
            assume iw1: "iface_name_is_wildcard i1" and iw2: "iface_name_is_wildcard i2" and len: "length i1 \<le> length i2" and
                   take_i1i2: "take (length i1 - 1) i1 = take (length i1 - 1) i2"
            from len have len': "length i1 - 1 \<le> length i2 - 1" by fastforce
            { fix x::string
             from len' have "take (length i1 - 1) x = take (length i1 - 1) (take (length i2 - 1) x)" by(simp add: min_def)
            } note takei1=this
        
            { fix m::nat and n::nat and a::string and b c
              have "m \<le> n \<Longrightarrow> take n a = take n b \<Longrightarrow> take m a = take m c \<Longrightarrow> take m c = take m b" by (metis min_absorb1 take_take)
            } note takesmaller=this
        
            from match_iface_case_wildcard_prefix[OF iw1, simplified] have 1:
                "internal_iface_name_match i1 p_i \<longleftrightarrow> take (length i1 - 1) i1 = take (length i1 - 1) p_i" by(simp add: butlast_conv_take)
            also have "\<dots> \<longleftrightarrow> take (length i1 - 1) (take (length i2 - 1) i1) = take (length i1 - 1) (take (length i2 - 1) p_i)" using takei1 by simp
            finally have  "internal_iface_name_match i1 p_i = (take (length i1 - 1) (take (length i2 - 1) i1) = take (length i1 - 1) (take (length i2 - 1) p_i))" .
            from match_iface_case_wildcard_prefix[OF iw2, simplified] have 2:
                "internal_iface_name_match i2 p_i \<longleftrightarrow> take (length i2 - 1) i2 = take (length i2 - 1) p_i" by(simp add: butlast_conv_take)
        
            have "internal_iface_name_match i2 p_i \<Longrightarrow> internal_iface_name_match i1 p_i"
              unfolding 1 2 
              apply(rule takesmaller[of "(length i1 - 1)" "(length i2 - 1)" i2 p_i])
                using len' apply (simp)
               apply simp
              using take_i1i2 apply simp
              done
          } note longer_iface_imp_shorter=this
        
         show ?thesis
          proof(cases "length i1 \<le> length i2")
          case True
            with assm3 have "X = i2" unfolding internal_iface_name_wildcard_longest_def by(simp split: split_if_asm)
            from True assm3' have take_i1i2: "take (length i1 - 1) i1 = take (length i1 - 1) i2" by linarith
            from longer_iface_imp_shorter[OF assm1 assm2 True take_i1i2] `X = i2`
            show "(internal_iface_name_match i1 p_i \<and> internal_iface_name_match i2 p_i) \<longleftrightarrow> internal_iface_name_match X p_i" by fastforce
          next
          case False
            with assm3 have "X = i1" unfolding internal_iface_name_wildcard_longest_def by(simp split: split_if_asm)
            from False assm3' have take_i1i2: "take (length i2 - 1) i2 = take (length i2 - 1) i1" by (metis min_def min_diff)
            from longer_iface_imp_shorter[OF assm2 assm1 _ take_i1i2] False `X = i1`
            show "(internal_iface_name_match i1 p_i \<and> internal_iface_name_match i2 p_i) \<longleftrightarrow> internal_iface_name_match X p_i" by auto
          qed
        qed
      } note internal_iface_name_wildcard_longest_correct_Some=this
    
      from internal_iface_name_wildcard_longest_correct_None internal_iface_name_wildcard_longest_correct_Some show ?thesis
        by(simp split:option.split)
    qed
  
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
      (*apply(safe) apply(simp_all add: internal_iface_name_wildcard_longest_refl)*)
      apply(auto simp: internal_iface_name_wildcard_longest_refl dest: internal_iface_name_wildcard_longest_correct)
               apply (metis match_iface.simps match_iface_case_nowildcard)+
      done

    lemma match_iface_refl: "match_iface (Iface x) x" by (simp add: internal_iface_name_match_refl)





    private definition internal_iface_name_subset :: "string \<Rightarrow> string \<Rightarrow> bool" where
      "internal_iface_name_subset i1 i2 = (case (iface_name_is_wildcard i1, iface_name_is_wildcard i2) of
        (True,  True) \<Rightarrow> length i1 \<ge> length i2 \<and> take ((length i2) - 1) i1 = butlast i2 |
        (True,  False) \<Rightarrow> False |
        (False, True) \<Rightarrow> take (length i2 - 1) i1 = butlast i2 |
        (False, False) \<Rightarrow> i1 = i2
        )"


    private lemma hlp1: "{x. \<exists>cs. x = i1 @ cs} \<subseteq> {x. \<exists>cs. x = i2 @ cs} \<Longrightarrow> length i2 \<le> length i1"
      apply(simp add: Set.Collect_mono_iff)
      by force
    private lemma hlp2: "{x. \<exists>cs. x = i1 @ cs} \<subseteq> {x. \<exists>cs. x = i2 @ cs} \<Longrightarrow> take (length i2) i1 = i2"
      apply(simp add: Set.Collect_mono_iff)
      by force

    private lemma internal_iface_name_subset: "internal_iface_name_subset i1 i2 \<longleftrightarrow> 
        {i. internal_iface_name_match i1 i} \<subseteq> {i. internal_iface_name_match i2 i}"
      unfolding internal_iface_name_subset_def
      apply(case_tac "iface_name_is_wildcard i1")
       apply(case_tac [!] "iface_name_is_wildcard i2")
         apply(simp_all)
         defer
         using internal_iface_name_match_refl match_iface_case_nowildcard apply fastforce
        using match_iface_case_nowildcard match_iface_case_wildcard_prefix apply force
       using match_iface_case_nowildcard  apply force
      apply(rule)
       apply(clarify, rename_tac x)
       apply(drule_tac p_i=x in match_iface_case_wildcard_prefix)+
       apply(simp)
       apply (smt One_nat_def append_take_drop_id butlast_conv_take cancel_comm_monoid_add_class.diff_cancel diff_commute diff_diff_cancel diff_is_0_eq drop_take length_butlast take_append)
      apply(subst(asm) internal_iface_name_to_set2[symmetric])+
      apply(simp add: internal_iface_name_to_set)
      apply(safe)
       apply(drule hlp1)
       apply(simp)
       apply (metis One_nat_def Suc_pred diff_Suc_eq_diff_pred diff_is_0_eq iface_name_is_wildcard.simps(1) length_greater_0_conv)
      apply(drule hlp2)
      apply(simp)
      by (metis One_nat_def butlast_conv_take length_butlast length_take take_take)
      
       
    
    definition iface_subset :: "iface \<Rightarrow> iface \<Rightarrow> bool" where
      "iface_subset i1 i2 \<longleftrightarrow> internal_iface_name_subset (iface_sel i1) (iface_sel i2)"
    
    lemma iface_subset: "iface_subset i1 i2 \<longleftrightarrow> {i. match_iface i1 i} \<subseteq> {i. match_iface i2 i}"
      unfolding iface_subset_def
      apply(cases i1, cases i2)
      by(simp add: internal_iface_name_subset)


    definition iface_is_wildcard :: "iface \<Rightarrow> bool" where
      "iface_is_wildcard ifce \<equiv> iface_name_is_wildcard (iface_sel ifce)"





  subsection{*Enumerating Interfaces*}
    private definition all_chars :: "char list" where
      "all_chars \<equiv> Enum.enum"
    private lemma all_chars: "set all_chars = (UNIV::char set)"
       by(simp add: all_chars_def enum_UNIV)
  
    text{*we can compute this, but its horribly inefficient!*}
    (*TODO: reduce size of valid chars to the printable ones*)
    private lemma strings_of_length_n: "set (List.n_lists n all_chars) = {s::string. length s = n}"
      apply(induction n)
       apply(simp)
      apply(simp add: all_chars)
      apply(safe)
       apply(simp)
      apply(simp)
      apply(rename_tac n x)
      apply(rule_tac x="drop 1 x" in exI)
      apply(simp)
      apply(case_tac x)
       apply(simp_all)
      done
  
    text{*Non-wildacrd interfaces of length @{term n}*}
    private definition non_wildcard_ifaces :: "nat \<Rightarrow> string list" where
     "non_wildcard_ifaces n \<equiv> filter (\<lambda>i. \<not> iface_name_is_wildcard i) (List.n_lists n all_chars)"

    text{*Example: (any number higher than zero are probably too inefficient)*}
    private lemma "non_wildcard_ifaces 0 = ['''']" by eval

    private lemma non_wildcard_ifaces: "set (non_wildcard_ifaces n) = {s::string. length s = n \<and> \<not> iface_name_is_wildcard s}"
      using strings_of_length_n non_wildcard_ifaces_def by auto
  
    private lemma  "(\<Union> i \<in> set (non_wildcard_ifaces n). internal_iface_name_to_set i) = {s::string. length s = n \<and> \<not> iface_name_is_wildcard s}"
     apply(simp_all only: internal_iface_name_to_set.simps if_True if_False not_True_eq_False not_False_eq_True non_wildcard_ifaces)
     apply(simp_all split: split_if_asm split_if)
     done
  
    text{*Non-wildacrd interfaces up to length @{term n}*}
    private fun non_wildcard_ifaces_upto :: "nat \<Rightarrow> string list" where
      "non_wildcard_ifaces_upto 0 = [[]]" |
      "non_wildcard_ifaces_upto (Suc n) = (non_wildcard_ifaces (Suc n)) @ non_wildcard_ifaces_upto n"
    private lemma non_wildcard_ifaces_upto: "set (non_wildcard_ifaces_upto n) = {s::string. length s \<le> n \<and> \<not> iface_name_is_wildcard s}"
      apply(induction n)
       apply(simp)
       apply fastforce
      apply(simp add: non_wildcard_ifaces)
      by fastforce


  subsection{*Negating Interfaces*}
    private lemma inv_iface_name_set: "- (internal_iface_name_to_set i) = (
      if iface_name_is_wildcard i
      then
        {c |c. length c < length (butlast i)} \<union> {c @ cs |c cs. length c = length (butlast i) \<and> c \<noteq> butlast i}
      else
        {c | c. length c < length i} \<union> {c@cs | c cs. length c \<ge> length i \<and> c \<noteq> i}
    )"
    proof -
      { fix i::string
        have inv_i_wildcard: "- {i@cs | cs. True} = {c | c. length c < length i} \<union> {c@cs | c cs. length c = length i \<and> c \<noteq> i}"
          apply(rule)
           prefer 2
           apply(safe)[1]
            apply(simp add:)
           apply(simp add:)
          apply(simp)
          apply(rule Compl_anti_mono[where B="{i @ cs |cs. True}" and A="- ({c | c. length c < length i} \<union> {c@cs | c cs. length c = length i \<and> c \<noteq> i})", simplified])
          apply(safe)
          apply(simp)
          apply(case_tac "(length i) = length x")
           apply(erule_tac x=x in allE, simp)
           apply(blast)
          apply(erule_tac x="take (length i) x" in allE)
          apply(simp add: min_def)
          by (metis append_take_drop_id)
      } note inv_i_wildcard=this
      { fix i::string
        have inv_i_nowildcard: "- {i::string} = {c | c. length c < length i} \<union> {c@cs | c cs. length c \<ge> length i \<and> c \<noteq> i}"
        proof -
          have x: "{c | c. length c = length i \<and> c \<noteq> i}  \<union> {c | c. length c > length i} = {c@cs | c cs. length c \<ge> length i \<and> c \<noteq> i}"
          apply(safe)
          apply force+
          done
          have "- {i::string} = {c |c . c \<noteq> i}"
           by(safe, simp)
          also have "\<dots> = {c | c. length c < length i} \<union> {c | c. length c = length i \<and> c \<noteq> i}  \<union> {c | c. length c > length i}"
          by(auto)
          finally show ?thesis using x by auto
        qed
      } note inv_i_nowildcard=this
    show ?thesis
    apply(case_tac "iface_name_is_wildcard i")
     apply(simp_all only: internal_iface_name_to_set.simps if_True if_False not_True_eq_False not_False_eq_True)
     apply(subst inv_i_wildcard)
     apply(simp)
    apply(subst inv_i_nowildcard)
    apply(simp)
    done
    qed

    text{*Negating is really not intuitive.
          The Interface @{term "''et''"} is in the negated set of @{term "''eth+''"}.
          And the Interface @{term "''et+''"} is also in this set! This is because @{term "''+''"}
          is a normal interface character and not a wildcard here!
          In contrast, the set described by @{term "''et+''"} (with @{term "''+''"} a wildcard)
          is not a subset of the previously negated set.*}
    lemma "''et'' \<in> - (internal_iface_name_to_set ''eth+'')" by(simp)
    lemma "''et+'' \<in> - (internal_iface_name_to_set ''eth+'')" by(simp)
    lemma "\<not> {i. match_iface (Iface ''et+'') i} \<subseteq> - (internal_iface_name_to_set ''eth+'')" by force

    text{*Because @{term "''+''"} can appear as interface wildcard and normal interface character,
          we cannot take negate an @{term "Iface i"} such that we get back @{typ "iface list"} which
          describe the negated interface.*}
    lemma "''+'' \<in> - (internal_iface_name_to_set ''eth+'')" by(simp)


  declare match_iface.simps[simp del]
  declare iface_name_is_wildcard.simps[simp del]
end

end
