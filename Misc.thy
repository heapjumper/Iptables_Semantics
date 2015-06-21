theory Misc
imports Main
begin

lemma list_app_singletonE:
  assumes "rs\<^sub>1 @ rs\<^sub>2 = [x]"
  obtains (first) "rs\<^sub>1 = [x]" "rs\<^sub>2 = []"
        | (second) "rs\<^sub>1 = []" "rs\<^sub>2 = [x]"
using assms
by (cases "rs\<^sub>1") auto

lemma list_app_eq_cases:
  assumes "xs\<^sub>1 @ xs\<^sub>2 = ys\<^sub>1 @ ys\<^sub>2"
  obtains (longer)  "xs\<^sub>1 = take (length xs\<^sub>1) ys\<^sub>1" "xs\<^sub>2 = drop (length xs\<^sub>1) ys\<^sub>1 @ ys\<^sub>2"
        | (shorter) "ys\<^sub>1 = take (length ys\<^sub>1) xs\<^sub>1" "ys\<^sub>2 = drop (length ys\<^sub>1) xs\<^sub>1 @ xs\<^sub>2"
using assms (* TODO larsrh fix proof *)
apply (cases "length xs\<^sub>1 \<le> length ys\<^sub>1")
apply (metis append_eq_append_conv_if)+
done


context
begin
  (*TODO: all those help lemmas!*)
  definition "remdups_rev rs = (rev (remdups (rev rs)))"
  value "remdups_rev [1, 1::int, 1, 2 ,1]"
  
  
  private lemma help3: "remdups (rs @ rs2) = remdups [r\<leftarrow>rs . r \<notin> set rs2] @ remdups rs2"
  by(induction rs arbitrary: rs2) (simp_all)
  
  private lemma "set rs \<inter> set rs2 \<noteq> {} \<Longrightarrow> remdups_rev (rs @ rs2) = remdups_rev rs @ remdups_rev (filter (\<lambda>r. r \<notin> set rs) rs2)"
  proof(induction rs arbitrary: rs2)
  case Cons thus ?case by(simp add: help3 rev_filter remdups_rev_def)
  qed(simp)
  
  private lemma help5: "r \<notin> set rs \<Longrightarrow> remdups_rev (r # rs) = r # remdups_rev rs"
    unfolding remdups_rev_def
    proof(induction rs)
    case (Cons r rs)
      { fix rs and rs2::"'a list"
        have "set rs \<inter> set rs2 = {} \<Longrightarrow> remdups (rs @ rs2) = remdups rs @ remdups rs2"
          by(induction rs arbitrary: rs2) (simp_all)
      } note h=this
      { fix r and rs::"'a list"
        from h[of "rev rs" "[r]"] have "r \<notin> set rs \<Longrightarrow> remdups (rev rs @ [r]) = remdups (rev rs) @ [r]" by simp
      }
      with Cons show ?case by fastforce  
    qed(simp)


  private lemma help5': "r \<in> set rs \<Longrightarrow> remdups_rev (r # rs) = r # remdups_rev (rev (removeAll r (rev rs)))"
    unfolding remdups_rev_def
    proof(induction rs)
    case Cons thus ?case
      apply(simp add: removeAll_filter_not_eq help3)
      apply(safe)
        apply(simp_all)
       apply metis
      apply metis
      done
    qed(simp)
  
  private lemma help6: "rev (removeAll r (rev rs)) = removeAll r rs"
  by (simp add: removeAll_filter_not_eq rev_filter)
  
  lemma remdups_rev_fst: "remdups_rev (r#rs) = (if r \<in> set rs then r#remdups_rev (removeAll r rs) else r#remdups_rev rs)"
    using help5 help5' help6 by metis


  lemma remdups_rev_removeAll: "remdups_rev (removeAll r rs) = removeAll r (remdups_rev rs)"
    by (simp add: remdups_filter remdups_rev_def removeAll_filter_not_eq rev_filter)
end

end
