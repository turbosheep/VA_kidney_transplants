drop table if exists #input_data
select * 
into #input_data
from nlp.final_nlp_output_long
where [label]!='OTHER_TRANSPLANT' and span not like '%tx%'and (other_transplant=0 or kidney_transplant_phrase=1)-- and other_transplant=0-- and modifier not like '%if%'

drop table if exists #dual_transplant
select distinct patienticn
into #dual_transplant
from #input_data
where [label]='DUAL_TRANSPLANT'

drop table if exists #treatment
select *
into #treatment
from (select i.*,
             row_number() over (partition by patienticn order by referencedatetime asc) as seqnum
      from (select * from #input_data where (modifier_label='1_TREATMENT_OPTION'-- and is_negated=0) -- treatment modifier
										or [label]='KIDNEY_TRANSPLANT_OPTION'-- treatment option phrase
										or modifier_label='5b_TRANSPLANT_EVAL' -- not a candidate modifier
										or [label]='5B_NOT_CANDIDATE' -- not a candidate phrase
										or modifier_label='2_TRANSPLANT_EVAL' -- evaluation implies education/option
										or [label]='KIDNEY_TRANSPLANT_EVALUATION' -- evaluation implies education/option 
										or [label]='TRANSPLANT_EVALUATION' 
										and (kidney_keyword=1 or nephrology_keyword=1 or nephrology_note=1)-- or dialysis_keyword=1)
										) i
     ) i
where seqnum = 1

drop table if exists #evaluation
select *
into #evaluation
from (select i.*,
             row_number() over (partition by patienticn order by referencedatetime asc) as seqnum
      from (select * from #input_data id where (([label]='KIDNEY_TRANSPLANT_EVALUATION' 
												or [label]='TRANSPLANT_EVALUATION'
												or modifier_label='2_TRANSPLANT_EVAL'
												)
										and (kidney_keyword=1 or nephrology_keyword=1 or nephrology_note=1)
										and is_negated=0
										and (modifier is null or (modifier not like '%up%' and modifier not like '%work%'))
										and not (modifier = 'pre' and [label]='TRANSPLANT_EVALUATION') -- no pre-transplant evals, "pre-transplant" ok, (pre kidney transplant) eval ok
										and not (span like '%process%' and modifier is null)
										and conditional_phrase=0
										and not_a_candidate_phrase=0
										and TIUDocumentDefinition not like '%education%' -- largely templated notes
										) ) i
     ) i
where seqnum = 1

drop table if exists #referral
select *
into #referral
from (select i.*,
             row_number() over (partition by patienticn order by referencedatetime asc) as seqnum
      from (select * from #input_data where 
	  [label]='TRANSPLANT_REFERRAL' or
	  transplant_assessment_note=1) i
     ) i
where seqnum = 1

drop table if exists #clinic
select *
into #clinic
from (select i.*,
             row_number() over (partition by patienticn order by referencedatetime asc) as seqnum
      from (select id.* from #input_data id
	  join #referral r on r.PatientICN=id.PatientICN and r.ReferenceDateTime <= id.ReferenceDateTime
	  where
	  (id.txp_sta3n=1 and id.transplant_note=1 and id.kidney_keyword=1)) i
     ) i
where seqnum = 1

drop table if exists #final_mention_5b
select *
into #final_mention_5b
from (select i.*,
             row_number() over (partition by patienticn order by referencedatetime asc) as seqnum
      from (select id.* from #input_data id
	  join #treatment t on t.PatientICN=id.PatientICN
	  join #evaluation e on e.PatientICN=id.PatientICN
	  join #referral r on r.PatientICN=id.PatientICN
	  join #clinic c on c.PatientICN=id.PatientICN 
	  where (id.modifier_label='5b_TRANSPLANT_EVAL' or id.[label] ='5B_NOT_CANDIDATE')
			and (id.kidney_keyword=1 or id.nephrology_note=1 or id.nephrology_keyword=1)
			and id.referencedatetime >= coalesce(c.referencedatetime, r.referencedatetime, e.referencedatetime, t.referencedatetime) 
	  ) i 
     ) i
where seqnum <= 1

drop table if exists #final_mention_intermediate
select id.*
, case when id.modifier_label='5b_TRANSPLANT_EVAL' or id.[label] ='5B_NOT_CANDIDATE'
	   then 5
       when ((id.[label]='KIDNEY_TRANSPLANT_EVALUATION' 
												or id.[label]='TRANSPLANT_EVALUATION'
												or id.modifier_label='2_TRANSPLANT_EVAL'
												)
										and (id.kidney_keyword=1 or id.nephrology_keyword=1 or id.nephrology_note=1)
										and id.is_negated=0
										and (id.modifier is null or (id.modifier not like '%up%' and id.modifier not like '%work%'))
										and not (id.modifier = 'pre' and id.[label]='TRANSPLANT_EVALUATION') -- no pre-transplant evals, "pre-transplant" ok, (pre kidney transplant) eval ok
										and not (id.span like '%process%' and id.modifier is null)
										and id.conditional_phrase=0
										and id.not_a_candidate_phrase=0
										and id.TIUDocumentDefinition not like '%education%' -- largely templated notes
										) 
		   then 2
		   when (id.modifier_label='1_TREATMENT_OPTION'-- and is_negated=0) -- treatment modifier
										or id.[label]='KIDNEY_TRANSPLANT_OPTION'-- treatment option phrase
										or id.modifier_label='5b_TRANSPLANT_EVAL' -- not a candidate modifier
										or id.[label]='5B_NOT_CANDIDATE' -- not a candidate phrase
										or id.modifier_label='2_TRANSPLANT_EVAL' -- evaluation implies education/option
										or id.[label]='KIDNEY_TRANSPLANT_EVALUATION' -- evaluation implies education/option 
										or id.[label]='TRANSPLANT_EVALUATION' 
										)
										and (id.kidney_keyword=1 or id.nephrology_keyword=1 or id.nephrology_note=1)
			then 1 
		   when id.[label]='TRANSPLANT_REFERRAL' or id.transplant_assessment_note=1
		   then 3
		   when id.txp_sta3n=1 and id.transplant_note=1 and id.kidney_keyword=1
		   then 4 end class
into #final_mention_intermediate
from (select i.*
      from (select * from #input_data where (modifier_label='1_TREATMENT_OPTION' -- treatment modifier
										or [label]='KIDNEY_TRANSPLANT_OPTION' -- treatment option phrase
										or modifier_label='2_TRANSPLANT_EVAL' -- evaluation implies education/option
										or [label]='KIDNEY_TRANSPLANT_EVALUATION' -- evaluation implies education/option 
										or [label]='TRANSPLANT_EVALUATION' --and kidney_keyword=1) -- evaluation implies education/option
										or [label]='TRANSPLANT_REFERRAL'
										or [label]='TRANSPLANT_CONDITION'
										or modifier_label='TRANSPLANT_CONDITION'
										or [label]='TRANSPLNT_CENTER'
										or transplant_assessment_note=1 
										or modifier_label='5b_TRANSPLANT_EVAL' -- not a candidate modifier
										or [label] ='5B_NOT_CANDIDATE'
										or (txp_sta3n=1 and transplant_note=1 and kidney_keyword=1)
										)
										and (kidney_keyword=1 or nephrology_note=1 or nephrology_keyword=1)-- or dialysis_keyword=1)
										--and is_historical=0
										) i
     ) id
	  left join #treatment t on t.PatientICN=id.PatientICN
	  left join #evaluation e on e.PatientICN=id.PatientICN
	  left join #referral r on r.PatientICN=id.PatientICN
	  left join #clinic c on c.PatientICN=id.PatientICN 
	  where id.referencedatetime >= coalesce(c.referencedatetime, r.referencedatetime, e.referencedatetime, t.referencedatetime) 



drop table if exists #final_mention
select * 
into #final_mention
from (select a.*, row_number() over (partition by a.patienticn order by referencedatetime desc) as seqnum
from #final_mention_intermediate a ) c
where seqnum <= 1

drop table if exists #opt_count
select PatientICN, count(distinct tiudocumentsid) num
into #opt_count
from #final_mention_intermediate
where class=1
group by PatientICN

drop table if exists #eval_count
select PatientICN, count(distinct tiudocumentsid) num
into #eval_count
from #final_mention_intermediate
where class=2
group by PatientICN

drop table if exists #ref_count
select PatientICN, count(distinct tiudocumentsid) num
into #ref_count
from #final_mention_intermediate
where class=3
group by PatientICN

drop table if exists #cli_count
select PatientICN, count(distinct tiudocumentsid) num
into #cli_count
from #final_mention_intermediate
where class=4
group by PatientICN

drop table if exists #not_count
select PatientICN, count(distinct tiudocumentsid) num
into #not_count
from #final_mention_intermediate
where class=5
group by PatientICN

drop table if exists #patient_cohort
select distinct PatientICN, a.ScrSSN, CohortEntryDate
into #patient_cohort
from nlp.final_patient_cohort a
join nlp.final_patient_cohort_dates b on cast(a.ScrSSN as int)=b.scrssn

drop table if exists #note_count
select a.patienticn, count(distinct tiudocumentsid) note_count
into #note_count
from nlp.final_note_cohort a
join #patient_cohort b on a.PatientICN=b.PatientICN
where referencedatetime <= cast('2021-12-31' as datetime2) --cutoff date
	and referencedatetime >= CohortEntryDate
group by a.PatientICN

drop table if exists #note_count_end
select id.patienticn, count(distinct id.tiudocumentsid) note_count
into #note_count_end
from nlp.final_note_cohort id
join #patient_cohort b on id.PatientICN=b.PatientICN
	  left join #treatment t on t.PatientICN=id.PatientICN
	  left join #evaluation e on e.PatientICN=id.PatientICN
	  left join #referral r on r.PatientICN=id.PatientICN
	  left join #clinic c on c.PatientICN=id.PatientICN 
	  where id.referencedatetime >= coalesce(c.referencedatetime, r.referencedatetime, e.referencedatetime, t.referencedatetime)
	  and id.referencedatetime <= cast('2021-12-31' as datetime2) --cutoff date
	  and id.referencedatetime >= b.CohortEntryDate
group by id.PatientICN

drop table if exists ##wide_table
select #patient_cohort.*
, case when #dual_transplant.PatientICN is null then 0 else 1 end dual_transplant
, case when #note_count.note_count is null then 0 else #note_count.note_count end note_count
, #treatment.TIUDocumentSID treatment_TIU
, #treatment.ReferenceDateTime treatment_TIU_ReferenceDateTime
, #evaluation.TIUDocumentSID evaluation_TIU
, #evaluation.ReferenceDateTime evaluation_TIU_ReferenceDateTime
, #referral.TIUDocumentSID referral_TIU
, #referral.ReferenceDateTime referral_TIU_ReferenceDateTime
, #clinic.TIUDocumentSID clinic_TIU
, #clinic.ReferenceDateTime clinic_TIU_ReferenceDateTime
, #final_mention.TIUDocumentSID final_mention_TIU
, #final_mention.ReferenceDateTime final_mention_TIU_ReferenceDateTime
, case when #opt_count.num is null then 0 else #opt_count.num end end_treatment_count
, case when #eval_count.num is null then 0 else #eval_count.num end end_evaluation_count
, case when #ref_count.num is null then 0 else #ref_count.num end end_referral_count
, case when #cli_count.num is null then 0 else #cli_count.num end end_clinic_count
, case when #not_count.num is null then 0 else #not_count.num end end_noncandidate_count
, case when #note_count_end.note_count is null then 0 else #note_count_end.note_count end end_note_count

into ##wide_table
from #patient_cohort 
left join #note_count on #patient_cohort.patienticn=#note_count.PatientICN
left join #treatment on #patient_cohort.patienticn=#treatment.PatientICN
left join #evaluation on #patient_cohort.patienticn=#evaluation.PatientICN
left join #referral on #patient_cohort.patienticn=#referral.PatientICN
left join #clinic on #patient_cohort.patienticn=#clinic.patienticn
left join #final_mention on #patient_cohort.patienticn=#final_mention.patienticn
left join #dual_transplant on #patient_cohort.PatientICN=#dual_transplant.patienticn
left join #opt_count on #patient_cohort.PatientICN=#opt_count.PatientICN
left join #eval_count on #patient_cohort.PatientICN=#eval_count.PatientICN
left join #ref_count on #patient_cohort.PatientICN=#ref_count.PatientICN
left join #cli_count on #patient_cohort.PatientICN=#cli_count.PatientICN
left join #not_count on #patient_cohort.PatientICN=#not_count.PatientICN
left join #note_count_end on #patient_cohort.PatientICN=#note_count_end.PatientICN

/*drop table nlp.final_nlp_event_table
select *
into nlp.final_nlp_event_table
from ##wide_table*/