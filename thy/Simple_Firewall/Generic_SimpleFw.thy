section\<open>Generalize Simple Firewall\<close>
theory Generic_SimpleFw
imports SimpleFw_Semantics "Common/List_Product_More"
begin


subsection\<open>Syntactic Helpers\<close>

definition option2set :: "'a option \<Rightarrow> 'a set" where
  "option2set n \<equiv> (case n of None \<Rightarrow> {} | Some s \<Rightarrow> {s})"

definition option2list :: "'a option \<Rightarrow> 'a list" where
  "option2list n \<equiv> (case n of None \<Rightarrow> [] | Some s \<Rightarrow> [s])"

lemma set_option2list[simp]: "set (option2list k) = option2set k"
  unfolding option2list_def option2set_def by (simp split: option.splits)

lemma option2list_simps[simp]: "option2list (Some x) = [x]" "option2list (None) = []"
  unfolding option2list_def option.simps by(fact refl)+

lemma option2set_None: "option2set None = {}"
  by(simp add: option2set_def)

subsection\<open>Generalized Simple firewall\<close>

text\<open>The semantics of the @{term simple_fw} is quite close to @{const List.find}. 
The idea of the generalized @{term simple_fw} semantics is that you can have anything as the 
resulting action, not only a @{type simple_action}.\<close>

definition generalized_sfw
  :: "('i::len simple_match \<times> 'a) list \<Rightarrow> ('i, 'pkt_ext) simple_packet_scheme \<Rightarrow> ('i simple_match \<times> 'a) option"
  where
  "generalized_sfw l p \<equiv> find (\<lambda>(m,a). simple_matches m p) l"

lemma generalized_sfw_simps:
  "generalized_sfw [] p = None"
  "generalized_sfw (a # as) p = (if (case a of (m,_) \<Rightarrow> simple_matches m p) then Some a else generalized_sfw as p)"
	unfolding generalized_sfw_def by simp_all

lemma generalized_sfw_append: "generalized_sfw (a @ b) p = (case generalized_sfw a p of Some x \<Rightarrow> Some x | None \<Rightarrow> generalized_sfw b p)"
	by(induction a) (simp_all add: generalized_sfw_simps)

lemma simple_generalized_undecided: "simple_fw fw p \<noteq> Undecided \<Longrightarrow> generalized_sfw (map simple_rule_dtor fw) p \<noteq> None" 
	by(induction fw) (clarsimp simp add: generalized_sfw_def simple_fw_alt simple_rule_dtor_def split: prod.splits if_splits simple_action.splits simple_rule.splits)+



text\<open>Joining two firewalls, i.e. a packet is send through both sequentially. \<close>
definition generalized_fw_join
  :: "('i::len simple_match \<times> 'a) list \<Rightarrow> ('i simple_match \<times> 'b) list \<Rightarrow> ('i simple_match \<times> 'a \<times> 'b) list"
  where
  "generalized_fw_join l1 l2 \<equiv> [(u,(a,b)). (m1,a) \<leftarrow> l1, (m2,b) \<leftarrow> l2, u \<leftarrow> option2list (simple_match_and m1 m2)]"

lemma generalized_fw_join_cons_1:
  "generalized_fw_join ((am,ad) # l1) l2 =
    [(u,(ad,b)). (m2,b) \<leftarrow> l2, u \<leftarrow> option2list (simple_match_and am m2)] @ generalized_fw_join l1 l2"
unfolding generalized_fw_join_def by(simp)

lemma generalized_fw_join_1_nomatch:
  "\<not> simple_matches am p \<Longrightarrow>
    generalized_sfw [(u,(ad,b)). (m2,b) \<leftarrow> l2, u \<leftarrow> option2list (simple_match_and am m2)] p = None"
	by(induction l2) (clarsimp simp add: generalized_sfw_simps generalized_sfw_append option2list_def simple_match_and_SomeD split: prod.splits option.splits)+
	
lemma generalized_fw_join_2_nomatch:
  "\<not> simple_matches bm p \<Longrightarrow>
    generalized_sfw (generalized_fw_join as ((bm, bd) # bs)) p = generalized_sfw (generalized_fw_join as bs) p"
proof(induction as)
	case (Cons a as)
	note mIH = Cons.IH[OF Cons.prems]
	obtain am ad where a[simp]: "a = (am, ad)" by(cases a)
	have *: "generalized_sfw (concat (map (\<lambda>(m2, b). map (\<lambda>u. (u, ad, b)) (option2list (simple_match_and am m2))) ((bm, bd) # bs))) p = 
		generalized_sfw (concat (map (\<lambda>(m2, b). map (\<lambda>u. (u, ad, b)) (option2list (simple_match_and am m2))) bs)) p" 
		unfolding list.map prod.simps
		apply(cases "simple_match_and am bm")
		 apply(simp add: option2list_def; fail)
		apply(frule simple_match_and_SomeD[of _ _ _ p])
		apply(subst option2list_def)
		apply(unfold concat.simps)
		apply(simp add: generalized_sfw_simps Cons.prems)
	done
	show ?case 
		unfolding a
		unfolding generalized_fw_join_cons_1
		unfolding generalized_sfw_append
		unfolding mIH
		unfolding *
		..
qed(simp add: generalized_fw_join_def; fail)

lemma generalized_fw_joinI:
  "\<lbrakk>generalized_sfw f1 p = Some (r1,d1); generalized_sfw f2 p = Some (r2,d2)\<rbrakk> \<Longrightarrow>
     generalized_sfw (generalized_fw_join f1 f2) p = Some (the (simple_match_and r1 r2), d1,d2)"
proof(induction f1)
	case (Cons a as)
	obtain am ad where a[simp]: "a = Pair am ad" by(cases a)
	show ?case proof(cases "simple_matches am p")
		case True
		hence dra: "d1 = ad" "r1 = am" using Cons.prems by(simp_all add: generalized_sfw_simps)
		from Cons.prems(2) show ?thesis unfolding a dra
		proof(induction f2)
			case (Cons b bs)
			obtain bm bd where b[simp]: "b = Pair bm bd" by(cases b)
			thus ?case
			proof(cases "simple_matches bm p")
				case True
				hence drb: "d2 = bd" "r2 = bm" using Cons.prems by(simp_all add: generalized_sfw_simps)
				from True \<open>simple_matches am p\<close> obtain ruc where sma[simp]:
				  "simple_match_and am bm = Some ruc" "simple_matches ruc p"
					using simple_match_and_correct[of am p bm]
					by(simp split: option.splits)
				show ?thesis unfolding b
					by(simp add: generalized_fw_join_def option2list_def generalized_sfw_simps drb)
			next
				case False
				with Cons.prems have bd:
          "generalized_sfw (b # bs) p = generalized_sfw bs p"
          "generalized_sfw (b # bs) p = Some (r2, d2)"
				by(simp_all add: generalized_sfw_simps)
				note mIH = Cons.IH[OF bd(2)[unfolded bd(1)]]
				show ?thesis 
					unfolding mIH[symmetric] b
					using generalized_fw_join_2_nomatch[OF False, of "(am, ad) # as" bd bs]
					.
			qed
		qed(simp add: generalized_sfw_simps generalized_fw_join_def)
		  (*and empty_concat: "concat (map (\<lambda>x. []) ms) = []" by simp*)
	next
		case False 
		with Cons.prems have "generalized_sfw (a # as) p = generalized_sfw as p"
		  by(simp add: generalized_sfw_simps)
		with Cons.prems have "generalized_sfw as p = Some (r1, d1)" by simp
		note mIH = Cons.IH[OF this Cons.prems(2)]
		show ?thesis
			unfolding mIH[symmetric] a
			unfolding generalized_fw_join_cons_1
			unfolding generalized_sfw_append
			unfolding generalized_fw_join_1_nomatch[OF False, of ad f2]
			by simp
	qed
qed(simp add: generalized_fw_join_def generalized_sfw_simps;fail)


lemma generalized_fw_join_2_Nil[simp]: "generalized_fw_join f1 [] = []"
unfolding generalized_fw_join_def by(induction f1) simp_all
lemma generalized_fw_join_1_Nil[simp]: "generalized_fw_join [] f2 = []"
unfolding generalized_fw_join_def by(induction f2) simp_all

(* The structure is nearly the same as with generalized_fw_joinI, so it should be possible to show 
   it in one proof. But I felt like this is the better way *)
lemma generalized_fw_joinD:
  "generalized_sfw (generalized_fw_join f1 f2) p = Some (u, d1,d2) \<Longrightarrow>
    \<exists>r1 r2. generalized_sfw f1 p = Some (r1,d1) \<and> generalized_sfw f2 p = Some (r2,d2) \<and> Some u = simple_match_and r1 r2"
proof(induction f1)
	case (Cons a as)
	obtain am ad where a[simp]: "a = Pair am ad" by(cases a)
	show ?case proof(cases "simple_matches am p", rule exI)
		case True
		show "\<exists>r2. generalized_sfw (a # as) p = Some (am, d1) \<and> generalized_sfw f2 p = Some (r2, d2) \<and> Some u = simple_match_and am r2"
		using Cons.prems
		proof(induction f2)
			case (Cons b bs)
			obtain bm bd where b[simp]: "b = Pair bm bd" by(cases b)
			show ?case
			proof(cases "simple_matches bm p", rule exI)
				case True
				with \<open>simple_matches am p\<close> obtain u' (* u' = u, but I don't need that yet. *) 
					where sma: "simple_match_and am bm = Some u' \<and> simple_matches u' p" 
					using simple_match_and_correct[of am p bm] by(simp split: option.splits)
				show "generalized_sfw (a # as) p = Some (am, d1) \<and> generalized_sfw (b # bs) p = Some (bm, d2) \<and> Some u = simple_match_and am bm"
				using Cons.prems True \<open>simple_matches am p\<close>
				by(simp add: generalized_fw_join_def generalized_sfw_append sma generalized_sfw_simps)
			next
				case False
				have "generalized_sfw (generalized_fw_join (a # as) bs) p = Some (u, d1, d2)" 
					using Cons.prems unfolding b unfolding generalized_fw_join_2_nomatch[OF False] .
				note Cons.IH[OF this]
				moreover have "generalized_sfw (b # bs) p = generalized_sfw bs p" using False by(simp add: generalized_sfw_simps)
				ultimately show ?thesis by presburger
			qed
		qed(simp add: generalized_sfw_simps)
	next
		case False
		with Cons.prems have "generalized_sfw (generalized_fw_join as f2) p = Some (u, d1, d2)" by(simp add: generalized_fw_join_cons_1 generalized_sfw_append generalized_fw_join_1_nomatch)
		note Cons.IH[OF this]
		moreover have "generalized_sfw (a # as) p = generalized_sfw as p" using False by(simp add: generalized_sfw_simps)
		ultimately show ?thesis by presburger
	qed
qed(simp add: generalized_fw_join_def generalized_sfw_simps)

definition "simple_action_to_state a \<equiv> (case a of simple_action.Accept \<Rightarrow> Decision FinalAllow | simple_action.Drop \<Rightarrow> Decision FinalDeny)"
lemma simple_fw_iff_generalized_fw: "simple_fw fw p = simple_action_to_state a \<longleftrightarrow> (\<exists>r. generalized_sfw (map simple_rule_dtor fw) p = Some (r,a))"
by(induction fw) (clarsimp simp add: generalized_sfw_simps simple_rule_dtor_def simple_fw_alt simple_action_to_state_def split: simple_rule.splits if_splits simple_action.splits)+

lemmas simple_fw_iff_generalized_fw_accept = simple_fw_iff_generalized_fw[where a = simple_action.Accept, unfolded simple_action_to_state_def simple_action.simps]
lemmas simple_fw_iff_generalized_fw_drop = simple_fw_iff_generalized_fw[where a = simple_action.Drop, unfolded simple_action_to_state_def simple_action.simps]

lemma generalized_sfw_mapsnd[simp]: "generalized_sfw (map (apsnd f) fw) p = map_option (apsnd f) (generalized_sfw fw p)"
	by(induction fw) (simp_all add: generalized_sfw_simps split: prod.splits)

definition "generalized_sfw_conjunct_i t \<equiv> (case t of (a,b) \<Rightarrow> (case a of simple_action.Accept \<Rightarrow> b | simple_action.Drop \<Rightarrow> simple_action.Drop))"
definition "generalized_sfw_conjunct_o \<equiv> map (apsnd generalized_sfw_conjunct_i)"

text\<open>We imagine two firewalls are positioned directly after each other.
      The first one has ruleset rs1 installed, the second one has ruleset rs2 installed.
      A packet needs to pass both firewalls.\<close>

theorem simple_fw_join:
  defines "rule_translate \<equiv>
    map (\<lambda>(u,a,b). SimpleRule u (if a = Accept \<and> b = Accept then Accept else Drop))"
  shows
  "simple_fw rs1 p = Decision FinalAllow \<and> simple_fw rs2 p = Decision FinalAllow \<longleftrightarrow>
    simple_fw (rule_translate (generalized_fw_join (map simple_rule_dtor rs1) (map simple_rule_dtor rs2))) p = Decision FinalAllow"
proof -
  have hlp1:
    "simple_rule_dtor \<circ> (\<lambda>(u, a, b). SimpleRule u (if a = Accept \<and> b = Accept then Accept else Drop)) =
      apsnd (\<lambda>(a, b). if a = Accept \<and> b = Accept then Accept else Drop)"
  unfolding fun_eq_iff comp_def by(simp add: simple_rule_dtor_def)
  show ?thesis
  unfolding simple_fw_iff_generalized_fw_accept
    apply(rule)
     apply(clarify)
     apply(drule (1) generalized_fw_joinI)
     apply(simp add: hlp1 rule_translate_def;fail)
    apply(clarsimp simp add: hlp1 rule_translate_def)
    apply(drule generalized_fw_joinD)
    apply(clarsimp split: if_splits)
  done
qed

theorem simple_fw_join2:
    "simple_fw rs1 p = Decision FinalAllow \<and> simple_fw rs2 p = Decision FinalAllow \<longleftrightarrow>
       map_option snd (generalized_sfw (generalized_sfw_conjunct_o
       	(generalized_fw_join (map simple_rule_dtor rs1) (map simple_rule_dtor rs2))) p) = Some simple_action.Accept"
unfolding simple_fw_iff_generalized_fw_accept
	apply(rule)
	 apply(clarify)
	 apply(drule (1) generalized_fw_joinI)
	 apply(clarsimp simp add: generalized_sfw_conjunct_o_def generalized_sfw_conjunct_i_def;fail)
	apply(clarsimp simp add: generalized_sfw_conjunct_o_def generalized_sfw_conjunct_i_def)
	apply(drule generalized_fw_joinD)
	apply(clarsimp split: if_splits simple_action.splits)
done

lemma concat_map_foldr: "concat (map (\<lambda>x. f x) l) = foldr (\<lambda>x. op @ (f x)) l []"
by(induction l) simp_all

lemma generalized_fw_join_1_1: "generalized_fw_join [(m1,d1)] fw2 = foldr (\<lambda>(m2,d2). op @ (case simple_match_and m1 m2 of None \<Rightarrow> [] | Some mu \<Rightarrow> [(mu,d1,d2)])) fw2 []"
	apply(clarsimp simp: generalized_fw_join_cons_1 option2list_def)
	apply(unfold list.map concat_map_foldr prod.case_distrib option.case_distrib)
	apply simp
done

lemma generalized_fw_split: "generalized_sfw fw p = Some r \<Longrightarrow> \<exists>fw1 fw3. fw = fw1 @ r # fw3 \<and> generalized_sfw fw1 p = None"
	apply(induction fw rule: rev_induct)
	 apply(simp add: generalized_sfw_simps generalized_sfw_append split: option.splits;fail)
	apply(clarsimp simp add: generalized_sfw_simps generalized_sfw_append split: option.splits if_splits)
	  apply blast+
done

lemma generalized_sfw_2_join_None: "generalized_sfw fw2 p = None \<Longrightarrow> generalized_sfw (generalized_fw_join fw1 fw2) p = None"
	by(induction fw2) (simp_all add: generalized_sfw_simps generalized_sfw_append generalized_fw_join_2_nomatch split: if_splits option.splits prod.splits)

lemma generalized_sfw_1_join_None: "generalized_sfw fw1 p = None \<Longrightarrow> generalized_sfw (generalized_fw_join fw1 fw2) p = None"
	by(induction fw1) (simp_all add: generalized_sfw_simps generalized_fw_join_cons_1 generalized_sfw_append generalized_fw_join_1_nomatch split: if_splits option.splits prod.splits)


lemma generalized_sfw_filterD: "generalized_sfw (filter f fw) p = Some (r,d) \<Longrightarrow> simple_matches r p \<and> f (r,d)"
by(induction fw) (simp_all add: generalized_sfw_simps split: if_splits)


context begin
  (*TODO: this lemma is probably already somewhere*)
  private lemma find_SomeD:
    "List.find P xs = Some x \<Longrightarrow> P x"
    "List.find P xs = Some x \<Longrightarrow> x\<in>set xs"
    by (auto simp add: find_Some_iff)
lemma generalized_sfwD: "generalized_sfw fw p = Some (r,d) \<Longrightarrow> (r,d) \<in> set fw \<and> simple_matches r p"
unfolding generalized_sfw_def
  using find_SomeD(1) find_SomeD(2) by fastforce
end
lemma generalized_sfw_NoneD: "generalized_sfw fw p = None \<Longrightarrow> \<forall>(a,b) \<in> set fw. \<not>simple_matches a p"
	by(induction fw) (clarsimp simp add: generalized_sfw_simps split: if_splits)+

lemma in_fw_join_set: "(a, b1, b2) \<in> set (generalized_fw_join f1 f2) \<Longrightarrow> \<exists>a1 a2. (a1, b1) \<in> set f1 \<and> (a2, b2) \<in> set f2 \<and> simple_match_and a1 a2 = Some a"
unfolding generalized_fw_join_def by(clarsimp simp: option2set_def split: option.splits) blast

subsection\<open>Validity\<close>
text\<open>There's validity of matches on @{const generalized_sfw}, too, even on the join.\<close>
lemma conjunctSomeProtoAnyD: "Some ProtoAny = simple_proto_conjunct a (Proto b) \<Longrightarrow> False"
by(cases a) (simp_all split: if_splits)
lemma simple_match_inject: " \<lparr>iiface = iifacea, oiface = oifacea, src = srca, dst = dsta, proto = protoa, sports = sportsa, dports = dportsa\<rparr>
      = \<lparr>iiface = iifaceb, oiface = oifaceb, src = srcb, dst = dstb, proto = protob, sports = sportsb, dports = dportsb\<rparr> \<longleftrightarrow>
      (iifacea = iifaceb \<and> oifacea = oifaceb \<and> srca = srcb \<and> dsta = dstb \<and> protoa = protob \<and> sportsa = sportsb \<and> dportsa = dportsb)"
by simp


definition gsfw_valid :: "('i::len simple_match \<times> 'c) list \<Rightarrow> bool" where
  "gsfw_valid \<equiv> list_all (simple_match_valid \<circ> fst)"

lemma gsfw_join_valid: "gsfw_valid f1 \<Longrightarrow> gsfw_valid f2 \<Longrightarrow> gsfw_valid (generalized_fw_join f1 f2)"
  unfolding gsfw_valid_def
  apply(induction f1)
   apply(simp;fail)
  apply(simp)
  apply(rename_tac a f1)
  apply(case_tac a)
  apply(simp add: generalized_fw_join_cons_1)
  apply(clarify)
  apply(thin_tac "list_all _ f1")
  apply(thin_tac "list_all _ (generalized_fw_join _ _)")
  apply(induction f2)
   apply(simp;fail)
  apply(simp)
  apply(clarsimp simp add: option2list_def list_all_iff)
  using simple_match_and_valid apply metis
  done

lemma gsfw_validI: "simple_fw_valid fw \<Longrightarrow> gsfw_valid (map simple_rule_dtor fw)"
  unfolding gsfw_valid_def simple_fw_valid_def 
  by(clarsimp simp add: simple_rule_dtor_def list_all_iff split: simple_rule.splits) fastforce


end