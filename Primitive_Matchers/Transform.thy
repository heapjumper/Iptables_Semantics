theory Transform
imports "Common_Primitive_Matcher"
        "../Semantics_Ternary/Semantics_Ternary"
        "../Semantics_Ternary/Negation_Type_Matching"
        "Ports_Normalize"
        "IpAddresses_Normalize"
        "../Common/Remdups_Rev"
begin




(*TODO: move*)
lemma not_matches_removeAll: "\<not> matches \<gamma> m a p \<Longrightarrow>
  approximating_bigstep_fun \<gamma> p (removeAll (Rule m a) rs) Undecided = approximating_bigstep_fun \<gamma> p rs Undecided"
  apply(induction \<gamma> p rs Undecided rule: approximating_bigstep_fun.induct)
   apply(simp)
  apply(simp split: action.split)
  apply blast
  done


lemma approximating_bigstep_fun_remdups_rev:
  "approximating_bigstep_fun \<gamma> p (remdups_rev rs) s = approximating_bigstep_fun \<gamma> p rs s"
  proof(induction \<gamma> p rs s rule: approximating_bigstep_fun.induct)
    case 1 thus ?case by(simp add: remdups_rev_def)
    next
    case 2 thus ?case by (simp add: Decision_approximating_bigstep_fun)
    next
    case (3 \<gamma> p m a rs) thus ?case
      proof(cases "matches \<gamma> m a p")
        case False with 3 show ?thesis
         by(simp add: remdups_rev_fst remdups_rev_removeAll not_matches_removeAll) 
        next
        case True
        { fix rs s
          have "approximating_bigstep_fun \<gamma> p (filter (op \<noteq> (Rule m Log)) rs) s = approximating_bigstep_fun \<gamma> p rs s"
          proof(induction \<gamma> p rs s rule: approximating_bigstep_fun_induct)
          qed(auto simp add: Decision_approximating_bigstep_fun split: action.split)
        } note helper_Log=this
        { fix rs s
          have "approximating_bigstep_fun \<gamma> p (filter (op \<noteq> (Rule m Empty)) rs) s = approximating_bigstep_fun \<gamma> p rs s"
          proof(induction \<gamma> p rs s rule: approximating_bigstep_fun_induct)
          qed(auto simp add: Decision_approximating_bigstep_fun split: action.split)
        } note helper_Empty=this
        from True 3 show ?thesis
          apply(simp add: remdups_rev_fst split: action.split)
          apply(safe)
             apply(simp_all)
           apply(simp_all add: remdups_rev_removeAll)
           apply(simp_all add: removeAll_filter_not_eq helper_Empty helper_Log)
          done
        qed
  qed

lemma remdups_rev_simplers: "simple_ruleset rs \<Longrightarrow> simple_ruleset (remdups_rev rs)"
  by(induction rs) (simp_all add: remdups_rev_def simple_ruleset_def)

lemma remdups_rev_preserve_matches: "\<forall> m \<in> get_match ` set rs. P m \<Longrightarrow> \<forall> m \<in> get_match ` set (remdups_rev rs). P m"
  by(induction rs) (simp_all add: remdups_rev_def simple_ruleset_def)

(*TODO: move
  TODO: this is currently not used.*)
text{*Compress many @{const Extra} expressions to one expression.*}
fun compress_extra :: "common_primitive match_expr \<Rightarrow> common_primitive match_expr" where
  "compress_extra (Match x) = Match x" |
  "compress_extra (MatchNot (Match (Extra e))) = Match (Extra (''NOT (''@e@'')''))" |
  "compress_extra (MatchNot m) = (MatchNot (compress_extra m))" |
  (*"compress_extra (MatchAnd (Match (Extra e1)) (Match (Extra e2))) = compress_extra (Match (Extra (e1@'' ''@e2)))" |*)
  (*"compress_extra (MatchAnd (Match (Extra e1)) MatchAny) = Match (Extra e1)" |*)
  "compress_extra (MatchAnd (Match (Extra e1)) m2) = (case compress_extra m2 of Match (Extra e2) \<Rightarrow> Match (Extra (e1@'' ''@e2)) | MatchAny \<Rightarrow> Match (Extra e1) | m2' \<Rightarrow> MatchAnd (Match (Extra e1)) m2')" |
  "compress_extra (MatchAnd m1 m2) = MatchAnd (compress_extra m1) (compress_extra m2)" |
  (*"compress_extra (MatchAnd m1 m2) = (case (compress_extra m1, compress_extra m2) of 
        (Match (Extra e1), Match (Extra e2)) \<Rightarrow> Match (Extra (e1@'' ''@e2))
      | (Match (Extra e1), MatchAny) \<Rightarrow> Match (Extra e1)
      | (MatchAny, Match (Extra e2)) \<Rightarrow> Match (Extra e2)
      | (m1', m2') \<Rightarrow> MatchAnd m1' m2')" |*)
  "compress_extra MatchAny = MatchAny"

thm compress_extra.simps

value "compress_extra (MatchAnd (Match (Extra ''foo'')) (Match (Extra ''bar'')))"
value "compress_extra (MatchAnd (Match (Extra ''foo'')) (MatchNot (Match (Extra ''bar''))))"
value "compress_extra (MatchAnd (Match (Extra ''-m'')) (MatchAnd (Match (Extra ''addrtype'')) (MatchAnd (Match (Extra ''--dst-type'')) (MatchAnd (Match (Extra ''BROADCAST'')) MatchAny))))"

lemma compress_extra_correct_matchexpr: "matches (common_matcher, \<alpha>) m = matches (common_matcher, \<alpha>) (compress_extra m)"
  proof(simp add: fun_eq_iff, clarify, rename_tac a p)
    fix a p
    have "ternary_ternary_eval (map_match_tac common_matcher p m) = ternary_ternary_eval (map_match_tac common_matcher p (compress_extra m))"
      apply(induction m rule: compress_extra.induct)
      apply (simp_all)
      (*apply(simp_all add: eval_ternary_simps)*)
      apply(simp_all split: match_expr.split match_expr.split_asm common_primitive.split)
      (*apply(simp_all add: eval_ternary_simps_simple)*)
      done (*TODO: tune proof*)
    thus "matches (common_matcher, \<alpha>) m a p = matches (common_matcher, \<alpha>) (compress_extra m) a p"
      by(rule matches_iff_apply_f)
    qed



(*closure bounds*)

(*def: transform_optimize = optimize_matches opt_MatchAny_match_expr \<circ> optimize_matches optimize_primitive_univ
apply before and after initialization and closures
*)

(*without normalize_rules_dnf, the result cannot be normalized as optimize_primitive_univ can contain MatchNot MatchAny*)
definition transform_optimize_dnf_strict :: "common_primitive rule list \<Rightarrow> common_primitive rule list" where 
    "transform_optimize_dnf_strict = optimize_matches opt_MatchAny_match_expr \<circ> 
        normalize_rules_dnf \<circ> (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ))"


(* TODO: move? *)
lemma normalized_n_primitive_opt_MatchAny_match_expr: "normalized_n_primitive disc_sel f m \<Longrightarrow> normalized_n_primitive disc_sel f (opt_MatchAny_match_expr m)"
  proof-
  { fix disc::"('a \<Rightarrow> bool)" and sel::"('a \<Rightarrow> 'b)" and n m1 m2
    have "normalized_n_primitive (disc, sel) n (opt_MatchAny_match_expr m1) \<Longrightarrow>
         normalized_n_primitive (disc, sel) n (opt_MatchAny_match_expr m2) \<Longrightarrow>
         normalized_n_primitive (disc, sel) n m1 \<and> normalized_n_primitive (disc, sel) n m2 \<Longrightarrow>
         normalized_n_primitive (disc, sel) n (opt_MatchAny_match_expr (MatchAnd m1 m2))"
  by(induction "(MatchAnd m1 m2)" rule: opt_MatchAny_match_expr.induct) (auto)
  }note x=this
  assume "normalized_n_primitive disc_sel f m"
  thus ?thesis
    apply(induction disc_sel f m rule: normalized_n_primitive.induct)
          apply simp_all
    using x by simp
  qed
  

theorem transform_optimize_dnf_strict: assumes simplers: "simple_ruleset rs" and wf\<alpha>: "wf_unknown_match_tac \<alpha>"
      shows "(common_matcher, \<alpha>),p\<turnstile> \<langle>transform_optimize_dnf_strict rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> (common_matcher, \<alpha>),p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
      and "simple_ruleset (transform_optimize_dnf_strict rs)"
      and "\<forall> m \<in> get_match ` set rs. \<not> has_disc disc m \<Longrightarrow> \<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). \<not> has_disc disc m"
      and "\<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). normalized_nnf_match m"
      and "\<forall> m \<in> get_match ` set rs. normalized_n_primitive disc_sel f m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). normalized_n_primitive disc_sel f m"
  proof -
    let ?\<gamma>="(common_matcher, \<alpha>)"
    let ?fw="\<lambda>rs. approximating_bigstep_fun ?\<gamma> p rs s"

    have simplers1: "simple_ruleset (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ) rs)"
      using simplers optimize_matches_simple_ruleset by (metis)

    show simplers_transform: "simple_ruleset (transform_optimize_dnf_strict rs)"
      unfolding transform_optimize_dnf_strict_def
      using simplers by (simp add: optimize_matches_simple_ruleset simple_ruleset_normalize_rules_dnf)

    have 1: "?\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> ?fw rs = t"
      using approximating_semantics_iff_fun_good_ruleset[OF simple_imp_good_ruleset[OF simplers]] by fast

    have "?fw rs = ?fw (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ) rs)"
      apply(rule optimize_matches[symmetric])
      using optimize_primitive_univ_correct_matchexpr opt_MatchAny_match_expr_correct by (metis comp_apply)
    also have "\<dots> = ?fw (normalize_rules_dnf (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ) rs))"
      apply(rule normalize_rules_dnf_correct[symmetric])
      using simplers1 by (metis good_imp_wf_ruleset simple_imp_good_ruleset)
    also have "\<dots> = ?fw (optimize_matches opt_MatchAny_match_expr (normalize_rules_dnf (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ) rs)))"
      apply(rule optimize_matches[symmetric])
      using opt_MatchAny_match_expr_correct by (metis)
    finally have rs: "?fw rs = ?fw (transform_optimize_dnf_strict rs)"
      unfolding transform_optimize_dnf_strict_def by(simp)

    have 2: "?fw (transform_optimize_dnf_strict rs) = t \<longleftrightarrow> ?\<gamma>,p\<turnstile> \<langle>transform_optimize_dnf_strict rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t "
      using approximating_semantics_iff_fun_good_ruleset[OF simple_imp_good_ruleset[OF simplers_transform], symmetric] by fast
    from 1 2 rs show "?\<gamma>,p\<turnstile> \<langle>transform_optimize_dnf_strict rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> ?\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t" by simp


    have tf1: "\<And>r rs. transform_optimize_dnf_strict (r#rs) =
      (optimize_matches opt_MatchAny_match_expr (normalize_rules_dnf (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ) [r])))@
        transform_optimize_dnf_strict rs"
      unfolding transform_optimize_dnf_strict_def by(simp add: optimize_matches_def)

    --"if the individual optimization functions preserve a property, then the whole thing does"
    { fix P m
      assume p1: "\<forall>m. P m \<longrightarrow> P (optimize_primitive_univ m)"
      assume p2: "\<forall>m. P m \<longrightarrow> P (opt_MatchAny_match_expr m)"
      assume p3: "\<forall>m. P m \<longrightarrow> (\<forall>m' \<in> set (normalize_match m). P m')"
      { fix rs
        have "\<forall> m \<in> get_match ` set rs. P m \<Longrightarrow> \<forall> m \<in> get_match ` set (optimize_matches (opt_MatchAny_match_expr \<circ> optimize_primitive_univ) rs). P m"
          apply(induction rs)
           apply(simp add: optimize_matches_def)
          apply(simp add: optimize_matches_def)
          using p1 p2 p3 by simp
      } note opt1=this
      have "\<forall> m \<in> get_match ` set rs. P m \<Longrightarrow> \<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). P m"
        apply(drule opt1)
        apply(induction rs)
         apply(simp add: optimize_matches_def transform_optimize_dnf_strict_def)
        apply(simp add: tf1 optimize_matches_def)
        apply(safe)
         apply(simp_all)
        using p1 p2 p3  by(simp)
    } note matchpred_rule=this

    { fix m
      have "\<not> has_disc disc m \<Longrightarrow> \<not> has_disc disc (optimize_primitive_univ m)"
      by(induction m rule: optimize_primitive_univ.induct) (simp_all)
    }  moreover { fix m 
      have "\<not> has_disc disc m \<Longrightarrow> \<not> has_disc disc (opt_MatchAny_match_expr m)"
      by(induction m rule: opt_MatchAny_match_expr.induct) simp_all
    }  moreover { fix m
      have "\<not> has_disc disc m \<longrightarrow> (\<forall>m' \<in> set (normalize_match m). \<not> has_disc disc m')"
      by(induction m rule: normalize_match.induct) (safe,auto) --"need safe, otherwise simplifier loops"
    } ultimately show "\<forall> m \<in> get_match ` set rs. \<not> has_disc disc m \<Longrightarrow> \<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). \<not> has_disc disc m"
      using matchpred_rule[of "\<lambda>m. \<not> has_disc disc m"] by fast
   
   { fix P a
     have "(optimize_primitive_univ (Match a)) = (Match a) \<or> (optimize_primitive_univ (Match a)) = MatchAny"
       by(induction "(Match a)" rule: optimize_primitive_univ.induct) (auto)
     hence "((optimize_primitive_univ (Match a)) = Match a \<Longrightarrow> P a) \<Longrightarrow> (optimize_primitive_univ (Match a) = MatchAny \<Longrightarrow> P a) \<Longrightarrow> P a" by blast
   } note optimize_primitive_univ_match_cases=this

   { fix m
      have "normalized_n_primitive disc_sel f m \<Longrightarrow> normalized_n_primitive disc_sel f (optimize_primitive_univ m)"
      apply(induction disc_sel f m rule: normalized_n_primitive.induct)
            apply(simp_all split: split_if_asm)
        apply(rule optimize_primitive_univ_match_cases, simp_all)+
      done
    }  moreover { fix m
      have "normalized_n_primitive disc_sel f m \<longrightarrow> (\<forall>m' \<in> set (normalize_match m). normalized_n_primitive disc_sel f  m')"
      apply(induction m rule: normalize_match.induct)
            apply(simp_all)[2]

          apply(case_tac disc_sel) --"no idea why the simplifier loops"
          apply(clarify)
          apply(simp)
          apply(clarify)
          apply(simp)

         apply(safe)
             apply(simp_all)
      done
    } ultimately show "\<forall> m \<in> get_match ` set rs. normalized_n_primitive disc_sel f m \<Longrightarrow> 
        \<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). normalized_n_primitive disc_sel f m"
      using matchpred_rule[of "\<lambda>m. normalized_n_primitive disc_sel f m"] normalized_n_primitive_opt_MatchAny_match_expr by fast
    

    { fix rs::"common_primitive rule list"
      {  fix m::"common_primitive match_expr"
             have "normalized_nnf_match m \<Longrightarrow> normalized_nnf_match (opt_MatchAny_match_expr m)"
               by(induction m rule: opt_MatchAny_match_expr.induct) (simp_all)
      } note x=this
      from normalize_rules_dnf_normalized_nnf_match[of "rs"]
      have "\<forall>x \<in> set (normalize_rules_dnf rs). normalized_nnf_match (get_match x)" .
      hence "\<forall>x \<in> set (optimize_matches opt_MatchAny_match_expr (normalize_rules_dnf rs)). normalized_nnf_match (get_match x)" 
        apply(induction rs rule: normalize_rules_dnf.induct)
         apply(simp_all add: optimize_matches_def x)
        using x by fastforce
    } 
    thus "\<forall> m \<in> get_match ` set (transform_optimize_dnf_strict rs). normalized_nnf_match m"
      unfolding transform_optimize_dnf_strict_def by simp
      
  qed



(*TODO move?*)
lemma has_unknowns_common_matcher: "has_unknowns common_matcher m \<longleftrightarrow> has_disc is_Extra m"
  proof -
  { fix A p
    have "common_matcher A p = TernaryUnknown \<longleftrightarrow> is_Extra A"
      by(induction A p rule: common_matcher.induct) (simp_all add: bool_to_ternary_Unknown)
  } thus ?thesis
  by(induction common_matcher m rule: has_unknowns.induct) (simp_all)
qed

definition transform_remove_unknowns_generic :: "('a, 'packet) match_tac \<Rightarrow> 'a rule list \<Rightarrow> 'a rule list" where 
    "transform_remove_unknowns_generic \<gamma> = optimize_matches_a (remove_unknowns_generic \<gamma>) "
theorem transform_remove_unknowns_generic:
   assumes simplers: "simple_ruleset rs" and wf\<alpha>: "wf_unknown_match_tac \<alpha>" and packet_independent_\<alpha>: "packet_independent_\<alpha> \<alpha>"
    shows "(common_matcher, \<alpha>),p\<turnstile> \<langle>transform_remove_unknowns_generic (common_matcher, \<alpha>) rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> (common_matcher, \<alpha>),p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
      and "simple_ruleset (transform_remove_unknowns_generic (common_matcher, \<alpha>) rs)"
      and "\<forall> m \<in> get_match ` set rs. \<not> has_disc disc m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_remove_unknowns_generic (common_matcher, \<alpha>) rs). \<not> has_disc disc m"
      and "\<forall> m \<in> get_match ` set (transform_remove_unknowns_generic (common_matcher, \<alpha>) rs). \<not> has_unknowns common_matcher m"
      (*may return MatchNot MatchAny*)
      (*and "\<forall> m \<in> get_match ` set rs. normalized_nnf_match m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_remove_unknowns_generic (common_matcher, \<alpha>) rs). normalized_nnf_match m"*)
      and "\<forall> m \<in> get_match ` set rs. normalized_n_primitive disc_sel f m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_remove_unknowns_generic (common_matcher, \<alpha>) rs). normalized_n_primitive disc_sel f m"
  proof -
    let ?\<gamma>="(common_matcher, \<alpha>)"
    let ?fw="\<lambda>rs. approximating_bigstep_fun ?\<gamma> p rs s"

    show simplers1: "simple_ruleset (transform_remove_unknowns_generic ?\<gamma> rs)"
      unfolding transform_remove_unknowns_generic_def
      using simplers optimize_matches_a_simple_ruleset by blast

    show "?\<gamma>,p\<turnstile> \<langle>transform_remove_unknowns_generic ?\<gamma> rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> ?\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
      unfolding approximating_semantics_iff_fun_good_ruleset[OF simple_imp_good_ruleset[OF simplers1]]
      unfolding approximating_semantics_iff_fun_good_ruleset[OF simple_imp_good_ruleset[OF simplers]]
      unfolding transform_remove_unknowns_generic_def
      using optimize_matches_a_simplers[OF simplers] remove_unknowns_generic by metis

    { fix a m
      have "\<not> has_disc disc m \<Longrightarrow> \<not> has_disc disc (remove_unknowns_generic ?\<gamma> a m)"
      by(induction ?\<gamma> a m rule: remove_unknowns_generic.induct) simp_all
    } thus "\<forall> m \<in> get_match ` set rs. \<not> has_disc disc m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_remove_unknowns_generic ?\<gamma> rs). \<not> has_disc disc m"
      unfolding transform_remove_unknowns_generic_def
      by(induction rs) (simp_all add: optimize_matches_a_def)

      { fix a m
        have "normalized_n_primitive disc_sel f m \<Longrightarrow> 
                normalized_n_primitive disc_sel f (remove_unknowns_generic ?\<gamma> a m)"
      by(induction ?\<gamma> a m rule: remove_unknowns_generic.induct) (simp_all,cases disc_sel, simp)
    } thus "\<forall> m \<in> get_match ` set rs. normalized_n_primitive disc_sel f m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_remove_unknowns_generic ?\<gamma> rs). normalized_n_primitive disc_sel f m"
      unfolding transform_remove_unknowns_generic_def
      by(induction rs) (simp_all add: optimize_matches_a_def)

    from simplers show "\<forall> m \<in> get_match ` set (transform_remove_unknowns_generic (common_matcher, \<alpha>) rs). \<not> has_unknowns common_matcher m"
      unfolding transform_remove_unknowns_generic_def
      apply(induction rs)
       apply(simp add: optimize_matches_a_def)
      apply(simp add: optimize_matches_a_def simple_ruleset_tail)
      apply(rule remove_unknowns_generic_specification[OF _ packet_independent_\<alpha> packet_independent_\<beta>_unknown_common_matcher])
      apply(simp add: simple_ruleset_def)
      done
qed





(* TODO *)
definition transform_normalize_primitives :: "common_primitive rule list \<Rightarrow> common_primitive rule list" where 
    "transform_normalize_primitives =
      normalize_rules normalize_dst_ips \<circ>
      normalize_rules normalize_src_ips \<circ>
      normalize_rules normalize_dst_ports \<circ>
      normalize_rules normalize_src_ports"


 (*TODO: move*)
 (*tuned version for usage with normalize_primitive_extract*)
 lemma normalize_rules_match_list_semantics_3: 
    assumes "\<forall>m a. normalized_nnf_match m \<longrightarrow> match_list \<gamma> (f m) a p = matches \<gamma> m a p"
    and "simple_ruleset rs"
    and normalized: "\<forall> m \<in> get_match ` set rs. normalized_nnf_match m"
    shows "approximating_bigstep_fun \<gamma> p (normalize_rules f rs) s = approximating_bigstep_fun \<gamma> p rs s"
    apply(rule normalize_rules_match_list_semantics_2)
     using normalized assms(1) apply blast
    using assms(2) by simp
    

 (*TODO: move and*)
  lemma normalize_rules_primitive_extract_preserves_nnf_normalized: "\<forall>m\<in>get_match ` set rs. normalized_nnf_match m \<Longrightarrow> wf_disc_sel disc_sel C \<Longrightarrow>
     \<forall>m\<in>get_match ` set (normalize_rules (normalize_primitive_extract disc_sel C f) rs). normalized_nnf_match m"
  apply(rule normalize_rules_preserves[where P="normalized_nnf_match" and f="(normalize_primitive_extract disc_sel C f)"])
   apply(simp)
  apply(cases disc_sel)
  using normalize_primitive_extract_preserves_nnf_normalized by fast


 thm normalize_primitive_extract_preserves_unrelated_normalized_n_primitive
 lemma normalize_rules_preserves_unrelated_normalized_n_primitive:
   assumes "\<forall> m \<in> get_match ` set rs. normalized_nnf_match m \<and> normalized_n_primitive (disc2, sel2) P m" 
       and "wf_disc_sel (disc1, sel1) C"
       and "\<forall>a. \<not> disc2 (C a)"
    shows "\<forall>m \<in> get_match ` set (normalize_rules (normalize_primitive_extract (disc1, sel1) C f) rs). normalized_nnf_match m \<and> normalized_n_primitive (disc2, sel2) P m"
    thm normalize_rules_preserves[where P="\<lambda>m. normalized_nnf_match m \<and> normalized_n_primitive  (disc2, sel2) P m"
        and f="normalize_primitive_extract (disc1, sel1) C f"]
    apply(rule normalize_rules_preserves[where P="\<lambda>m. normalized_nnf_match m \<and> normalized_n_primitive  (disc2, sel2) P m"
        and f="normalize_primitive_extract (disc1, sel1) C f"])
     using assms(1) apply(simp)
    apply(safe)
     using normalize_primitive_extract_preserves_nnf_normalized[OF _ assms(2)] apply fast
    using normalize_primitive_extract_preserves_unrelated_normalized_n_primitive[OF _ _ assms(2) assms(3)] by blast


  lemma normalize_rules_normalized_n_primitive:
   assumes "\<forall> m \<in> get_match ` set rs. normalized_nnf_match m"
       and "\<forall>m. normalized_nnf_match m \<longrightarrow>
             (\<forall>m' \<in> set (normalize_primitive_extract (disc, sel) C f m). normalized_n_primitive (disc, sel) P m')"
    shows "\<forall>m \<in> get_match ` set (normalize_rules (normalize_primitive_extract (disc, sel) C f) rs).
           normalized_n_primitive (disc, sel) P m"
    apply(rule normalize_rules_property[where P=normalized_nnf_match and f="normalize_primitive_extract (disc, sel) C f"])
     using assms(1) apply simp
    using assms(2) by simp


theorem transform_normalize_primitives:
  assumes simplers: "simple_ruleset rs"
      and wf\<alpha>: "wf_unknown_match_tac \<alpha>"
      and normalized: "\<forall> m \<in> get_match ` set rs. normalized_nnf_match m"
  shows "(common_matcher, \<alpha>),p\<turnstile> \<langle>transform_normalize_primitives rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> (common_matcher, \<alpha>),p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
    and "simple_ruleset (transform_normalize_primitives rs)"
        (*TODO: add sto to wf_disc_sel and remove the disc1 and disc2 preconditions*)
    and "\<forall>a. \<not> disc1 (Src_Ports a) \<Longrightarrow> \<forall>a. \<not> disc1 (Dst_Ports a) \<Longrightarrow> 
         \<forall>a. \<not> disc1 (Src a) \<Longrightarrow> \<forall>a. \<not> disc1 (Dst a) \<Longrightarrow> 
           \<forall> m \<in> get_match ` set rs. \<not> has_disc disc1 m \<Longrightarrow> \<forall> m \<in> get_match ` set (transform_normalize_primitives rs). \<not> has_disc disc1 m"
    and "\<forall> m \<in> get_match ` set (transform_normalize_primitives rs). normalized_nnf_match m"
    and "\<forall> m \<in> get_match ` set (transform_normalize_primitives rs).
          normalized_src_ports m \<and> normalized_dst_ports m \<and> normalized_src_ips m \<and> normalized_dst_ips m"
    and "\<forall>a. \<not> disc2 (Src_Ports a) \<Longrightarrow> \<forall>a. \<not> disc2 (Dst_Ports a) \<Longrightarrow> \<forall>a. \<not> disc2 (Src a) \<Longrightarrow> \<forall>a. \<not> disc2 (Dst a) \<Longrightarrow>
         \<forall> m \<in> get_match ` set rs. normalized_n_primitive (disc2, sel2) f m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_normalize_primitives rs). normalized_n_primitive (disc2, sel2) f m"
  proof -
    let ?\<gamma>="(common_matcher, \<alpha>)"
    let ?fw="\<lambda>rs. approximating_bigstep_fun ?\<gamma> p rs s"

    show simplers_t: "simple_ruleset (transform_normalize_primitives rs)"
      unfolding transform_normalize_primitives_def
      by(simp add: simple_ruleset_normalize_rules simplers)

    let ?rs1="normalize_rules normalize_src_ports rs"
    let ?rs2="normalize_rules normalize_dst_ports ?rs1"
    let ?rs3="normalize_rules normalize_src_ips ?rs2"
    let ?rs4="normalize_rules normalize_dst_ips ?rs3"

    from normalize_rules_primitive_extract_preserves_nnf_normalized[OF normalized wf_disc_sel_common_primitive(1)]
         normalize_src_ports_def normalize_ports_step_def
    have normalized_rs1: "\<forall>m \<in> get_match ` set ?rs1. normalized_nnf_match m" by presburger
    from normalize_rules_primitive_extract_preserves_nnf_normalized[OF this wf_disc_sel_common_primitive(2)]
         normalize_dst_ports_def normalize_ports_step_def
    have normalized_rs2: "\<forall>m \<in> get_match ` set ?rs2. normalized_nnf_match m" by presburger
    from normalize_rules_primitive_extract_preserves_nnf_normalized[OF this wf_disc_sel_common_primitive(3)]
         normalize_src_ips_def
    have normalized_rs3: "\<forall>m \<in> get_match ` set ?rs3. normalized_nnf_match m" by presburger
    from normalize_rules_primitive_extract_preserves_nnf_normalized[OF this wf_disc_sel_common_primitive(4)]
         normalize_dst_ips_def
    have normalized_rs4: "\<forall>m \<in> get_match ` set ?rs4. normalized_nnf_match m" by presburger
    thus "\<forall> m \<in> get_match ` set (transform_normalize_primitives rs). normalized_nnf_match m"
      unfolding transform_normalize_primitives_def by simp

    show "?\<gamma>,p\<turnstile> \<langle>transform_normalize_primitives rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> ?\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
     unfolding approximating_semantics_iff_fun_good_ruleset[OF simple_imp_good_ruleset[OF simplers_t]]
     unfolding approximating_semantics_iff_fun_good_ruleset[OF simple_imp_good_ruleset[OF simplers]]
     unfolding transform_normalize_primitives_def
     apply(simp)
     apply(subst normalize_rules_match_list_semantics_3)
        using normalize_dst_ips apply simp
       using simplers simple_ruleset_normalize_rules apply blast
      using normalized_rs3 apply simp
     apply(subst normalize_rules_match_list_semantics_3)
        using normalize_src_ips apply simp
       using simplers simple_ruleset_normalize_rules apply blast
      using normalized_rs2 apply simp
     apply(subst normalize_rules_match_list_semantics_3)
        using normalize_dst_ports apply simp
       using simplers simple_ruleset_normalize_rules apply blast
      using normalized_rs1 apply simp
     apply(subst normalize_rules_match_list_semantics_3)
        using normalize_src_ports apply simp
       using simplers simple_ruleset_normalize_rules apply blast
      using normalized apply simp
     by simp


    from normalize_src_ports_normalized_n_primitive
    have normalized_src_ports: "\<forall>m \<in> get_match ` set ?rs1.  normalized_src_ports m"
    using normalize_rules_property[OF normalized, where f=normalize_src_ports and Q=normalized_src_ports] by fast
      (*why u no rule?*)
    from normalize_dst_ports_normalized_n_primitive
         normalize_rules_property[OF normalized_rs1, where f=normalize_dst_ports and Q=normalized_dst_ports]
    have normalized_dst_ports: "\<forall>m \<in> get_match ` set ?rs2.  normalized_dst_ports m" by fast
    from normalize_src_ips_normalized_n_primitive
         normalize_rules_property[OF normalized_rs2, where f=normalize_src_ips and Q=normalized_src_ips]
    have normalized_src_ips: "\<forall>m \<in> get_match ` set ?rs3.  normalized_src_ips m" by fast
    from normalize_dst_ips_normalized_n_primitive
         normalize_rules_property[OF normalized_rs3, where f=normalize_dst_ips and Q=normalized_dst_ips]
    have normalized_dst_ips: "\<forall>m \<in> get_match ` set ?rs4.  normalized_dst_ips m" by fast


    from normalize_rules_preserves_unrelated_normalized_n_primitive[of _ is_Src_Ports src_ports_sel "(\<lambda>pts. length pts \<le> 1)",
         folded normalized_src_ports_def2 normalize_ports_step_def]
    have preserve_normalized_src_ports: "\<And>rs disc sel C f. 
      \<forall>m\<in>get_match ` set rs. normalized_nnf_match m  \<Longrightarrow>
      \<forall>m\<in>get_match ` set rs. normalized_src_ports m \<Longrightarrow>
      wf_disc_sel (disc, sel) C \<Longrightarrow>
      \<forall>a. \<not> is_Src_Ports (C a) \<Longrightarrow>
      \<forall>m\<in>get_match ` set (normalize_rules (normalize_primitive_extract (disc, sel) C f) rs). normalized_src_ports m"
      by metis
    from preserve_normalized_src_ports[OF normalized_rs1 normalized_src_ports wf_disc_sel_common_primitive(2),
         where f="(\<lambda>me. map (\<lambda>pt. [pt]) (ipt_ports_compress me))",
         folded normalize_ports_step_def normalize_dst_ports_def]
    have normalized_src_ports_rs2: "\<forall>m \<in> get_match ` set ?rs2.  normalized_src_ports m" by force
    from preserve_normalized_src_ports[OF normalized_rs2 normalized_src_ports_rs2 wf_disc_sel_common_primitive(3),
         where f=ipt_ipv4range_compress, folded normalize_src_ips_def]
    have normalized_src_ports_rs3: "\<forall>m \<in> get_match ` set ?rs3.  normalized_src_ports m" by force
    from preserve_normalized_src_ports[OF normalized_rs3 normalized_src_ports_rs3 wf_disc_sel_common_primitive(4),
         where f=ipt_ipv4range_compress, folded normalize_dst_ips_def]
    have normalized_src_ports_rs4: "\<forall>m \<in> get_match ` set ?rs4.  normalized_src_ports m" by force

    from normalize_rules_preserves_unrelated_normalized_n_primitive[of _ is_Dst_Ports dst_ports_sel "(\<lambda>pts. length pts \<le> 1)",
         folded normalized_dst_ports_def2 normalize_ports_step_def]
    have preserve_normalized_dst_ports: "\<And>rs disc sel C f. 
      \<forall>m\<in>get_match ` set rs. normalized_nnf_match m  \<Longrightarrow>
      \<forall>m\<in>get_match ` set rs. normalized_dst_ports m \<Longrightarrow>
      wf_disc_sel (disc, sel) C \<Longrightarrow>
      \<forall>a. \<not> is_Dst_Ports (C a) \<Longrightarrow>
      \<forall>m\<in>get_match ` set (normalize_rules (normalize_primitive_extract (disc, sel) C f) rs). normalized_dst_ports m"
      by metis
    from preserve_normalized_dst_ports[OF normalized_rs2 normalized_dst_ports wf_disc_sel_common_primitive(3),
         where f1=ipt_ipv4range_compress, folded normalize_src_ips_def]
    have normalized_dst_ports_rs3: "\<forall>m \<in> get_match ` set ?rs3.  normalized_dst_ports m" by force
    from preserve_normalized_dst_ports[OF normalized_rs3 normalized_dst_ports_rs3 wf_disc_sel_common_primitive(4),
         where f1=ipt_ipv4range_compress, folded normalize_dst_ips_def] (*TODO: why is this f1 and not f in 2015-RC0?*)
    have normalized_dst_ports_rs4: "\<forall>m \<in> get_match ` set ?rs4.  normalized_dst_ports m" by force

    from normalize_rules_preserves_unrelated_normalized_n_primitive[of ?rs3 is_Src src_sel "(\<lambda>ip. case ip of Ip4AddrNetmask _ _ \<Rightarrow> True | _ \<Rightarrow> False)",
         OF _ wf_disc_sel_common_primitive(4),
         where f=ipt_ipv4range_compress, folded normalize_dst_ips_def normalized_src_ips_def2]
         normalized_rs3 normalized_src_ips
    have normalized_src_rs4: "\<forall>m \<in> get_match ` set ?rs4. normalized_src_ips m" by force
    from normalized_src_ports_rs4 normalized_dst_ports_rs4 normalized_src_rs4 normalized_dst_ips
    show "\<forall> m \<in> get_match ` set (transform_normalize_primitives rs).
          normalized_src_ports m \<and> normalized_dst_ports m \<and> normalized_src_ips m \<and> normalized_dst_ips m"
      unfolding transform_normalize_primitives_def by force
   

   show  "\<forall>a. \<not> disc2 (Src_Ports a) \<Longrightarrow> \<forall>a. \<not> disc2 (Dst_Ports a) \<Longrightarrow> \<forall>a. \<not> disc2 (Src a) \<Longrightarrow> \<forall>a. \<not> disc2 (Dst a) \<Longrightarrow>
          \<forall> m \<in> get_match ` set rs. normalized_n_primitive (disc2, sel2) f m \<Longrightarrow>
            \<forall> m \<in> get_match ` set (transform_normalize_primitives rs). normalized_n_primitive  (disc2, sel2) f m"
   proof -
     assume "\<forall>m\<in>get_match ` set rs. normalized_n_primitive  (disc2, sel2) f m"
     with normalized have a': "\<forall>m\<in>get_match ` set rs. normalized_nnf_match m \<and> normalized_n_primitive (disc2, sel2) f m" by blast

     assume a_Src_Ports: "\<forall>a. \<not> disc2 (Src_Ports a)"
     assume a_Dst_Ports: "\<forall>a. \<not> disc2 (Dst_Ports a)"
     assume a_Src: "\<forall>a. \<not> disc2 (Src a)"
     assume a_Dst: "\<forall>a. \<not> disc2 (Dst a)"

     from normalize_rules_preserves_unrelated_normalized_n_primitive[OF a' wf_disc_sel_common_primitive(1),
       of "(\<lambda>me. map (\<lambda>pt. [pt]) (ipt_ports_compress me))",
       folded normalize_src_ports_def normalize_ports_step_def] a_Src_Ports
     have "\<forall>m\<in>get_match ` set ?rs1. normalized_n_primitive (disc2, sel2) f m" by simp
     with normalized_rs1 normalize_rules_preserves_unrelated_normalized_n_primitive[OF _ wf_disc_sel_common_primitive(2) a_Dst_Ports,
       of ?rs1 sel2 f "(\<lambda>me. map (\<lambda>pt. [pt]) (ipt_ports_compress me))",
       folded normalize_dst_ports_def normalize_ports_step_def]
     have "\<forall>m\<in>get_match ` set ?rs2. normalized_n_primitive (disc2, sel2) f m" by blast
     with normalized_rs2 normalize_rules_preserves_unrelated_normalized_n_primitive[OF _ wf_disc_sel_common_primitive(3) a_Src,
       of ?rs2 sel2 f ipt_ipv4range_compress,
       folded normalize_src_ips_def]
     have "\<forall>m\<in>get_match ` set ?rs3. normalized_n_primitive (disc2, sel2) f m" by blast
     with normalized_rs3 normalize_rules_preserves_unrelated_normalized_n_primitive[OF _ wf_disc_sel_common_primitive(4) a_Dst,
       of ?rs3 sel2 f ipt_ipv4range_compress,
       folded normalize_dst_ips_def]
     have "\<forall>m\<in>get_match ` set ?rs4. normalized_n_primitive (disc2, sel2) f m" by blast
     thus ?thesis
       unfolding transform_normalize_primitives_def by simp
   qed

   { fix m and m' and disc::"(common_primitive \<Rightarrow> bool)" and sel::"(common_primitive \<Rightarrow> 'x)" and C'::" ('x \<Rightarrow> common_primitive)"
         and f'::"('x negation_type list \<Rightarrow> 'x list)"
     assume am: "\<not> has_disc disc1 m"
        and nm: "normalized_nnf_match m"
        and am': "m' \<in> set (normalize_primitive_extract (disc, sel) C' f' m)"
        and wfdiscsel: "wf_disc_sel (disc,sel) C'"

        and disc_different: "\<forall>a. \<not> disc1 (C' a)"

        (*from wfdiscsel disc_different have "\<forall>a. \<not> disc1 (C' a)"
          apply(simp add: wf_disc_sel.simps)*)

        from disc_different have af: "\<forall>spts. (\<forall>a \<in> Match ` C' ` set (f' spts). \<not> has_disc disc1 a)"
          by(simp)

        obtain as ms where asms: "primitive_extractor (disc, sel) m = (as, ms)" by fastforce

        from am' asms have "m' \<in> (\<lambda>spt. MatchAnd (Match (C' spt)) ms) ` set (f' as)"
          unfolding normalize_primitive_extract_def by(simp)
        hence goalrule:"\<forall>spt \<in> set (f' as). \<not> has_disc disc1 (Match (C' spt)) \<Longrightarrow> \<not> has_disc disc1 ms \<Longrightarrow> \<not> has_disc disc1 m'" by fastforce

        from am primitive_extractor_correct(4)[OF nm wfdiscsel asms] have 1: "\<not> has_disc disc1 ms" by simp
        from af have 2: "\<forall>spt \<in> set (f' as). \<not> has_disc disc1 (Match (C' spt))" by simp

        from goalrule[OF 2 1] have "\<not> has_disc disc1 m'" .
        moreover from nm have "normalized_nnf_match m'" by (metis am' normalize_primitive_extract_preserves_nnf_normalized wfdiscsel)
        ultimately have "\<not> has_disc disc1 m' \<and> normalized_nnf_match m'" by simp
   }
   hence x: "\<And>disc sel C' f'.  wf_disc_sel (disc, sel) C' \<Longrightarrow> \<forall>a. \<not> disc1 (C' a) \<Longrightarrow>
   \<forall>m. normalized_nnf_match m \<and> \<not> has_disc disc1 m \<longrightarrow> (\<forall>m'\<in>set (normalize_primitive_extract (disc, sel) C' f' m). normalized_nnf_match m' \<and> \<not> has_disc disc1 m')"
   by blast


   have "\<forall>a. \<not> disc1 (Src_Ports a) \<Longrightarrow> \<forall>a. \<not> disc1 (Dst_Ports a) \<Longrightarrow> 
         \<forall>a. \<not> disc1 (Src a) \<Longrightarrow> \<forall>a. \<not> disc1 (Dst a) \<Longrightarrow> 
         \<forall> m \<in> get_match ` set rs. \<not> has_disc disc1 m \<and> normalized_nnf_match m \<Longrightarrow>
    \<forall> m \<in> get_match ` set (transform_normalize_primitives rs). normalized_nnf_match m \<and> \<not> has_disc disc1 m"
   unfolding transform_normalize_primitives_def
   apply(simp)
   apply(rule normalize_rules_preserves')+
       apply(simp)
      using x[OF wf_disc_sel_common_primitive(1), 
             of "(\<lambda>me. map (\<lambda>pt. [pt]) (ipt_ports_compress me))",folded normalize_src_ports_def normalize_ports_step_def] apply blast
     using x[OF wf_disc_sel_common_primitive(2), 
            of "(\<lambda>me. map (\<lambda>pt. [pt]) (ipt_ports_compress me))",folded normalize_dst_ports_def normalize_ports_step_def] apply blast
    using x[OF wf_disc_sel_common_primitive(3), of ipt_ipv4range_compress,folded normalize_src_ips_def] apply blast
   using x[OF wf_disc_sel_common_primitive(4), of ipt_ipv4range_compress,folded normalize_dst_ips_def] apply blast
   done
   

   thus "\<forall>a. \<not> disc1 (Src_Ports a) \<Longrightarrow> \<forall>a. \<not> disc1 (Dst_Ports a) \<Longrightarrow> 
         \<forall>a. \<not> disc1 (Src a) \<Longrightarrow> \<forall>a. \<not> disc1 (Dst a) \<Longrightarrow> 
    \<forall> m \<in> get_match ` set rs. \<not> has_disc disc1 m \<Longrightarrow> \<forall> m \<in> get_match ` set (transform_normalize_primitives rs). \<not> has_disc disc1 m"
   using normalized by blast
qed



end
