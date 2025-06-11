USE [DATABASE_NAME]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE view [nlp].[final_nlp_output_long] as with

-- patient ist
patient_cohort as (
select patienticn, patientsid, CohortEntryDate from nlp.final_patient_cohort a
join nlp.final_patient_cohort_dates b on cast(a.ScrSSN as int)=b.scrssn
),

-- note list
tiu_list as (
select * from nlp.final_note_cohort
where referencedatetime <= cast('2021-12-31' as datetime2) --cutoff date
),

-- raw nlp output
nlp_raw as (
select distinct * from 
[nlp].final_nlp_output
),

-- gather note IDs for exclusion including other current/ongoing non-kidney transplants
other_transplant as (
select distinct nlp_raw.tiudocumentsid from nlp_raw 
where ([label]='OTHER_TRANSPLANT' and (is_historical=0 or modifier is not null)) -- remove notes with other non historical transplant mentions
),

-- gather note IDs for exclusion including prior kidney transplants
kidney_translant_phrase as (
select distinct nlp_raw.tiudocumentsid from nlp_raw 
where [label] like '%kidney%' and [label]!='PRIOR_KIDNEY_TRANSPLANT'
),

-- gather note IDs with at least one NLP identified conditions on transplant
conditional_phrase as (
select distinct nlp_raw.tiudocumentsid from nlp_raw 
where ([label]='TRANSPLANT_CONDITION' or modifier_label='TRANSPLANT_CONDITION') 
),

-- gather note IDs with at least one NLP identified explicit lack of candidacy phrase
not_a_candidate_phrase as (
select distinct nlp_raw.tiudocumentsid from nlp_raw 
where [label]='5B_TRANSPLANT_EVAL' or modifier_label='5b_TRANSPLANT_EVAL'
),

-- gather all input data except raw nlp data, patient data, note data, and note metadata including binary flags for keywords
input_data as (
	select patient_cohort.patienticn, patient_cohort.patientsid, TIUDocumentSID, CohortEntryDate, ReferenceDateTime, sta3n, TIUDocumentDefinitionSID, kidney_keyword, nephrology_keyword, dialysis_keyword
	from patient_cohort
	join tiu_list
	on patient_cohort.patientsid=tiu_list.patientsid
	where referencedatetime >= dateadd( year, -2, CohortEntryDate)
),

-- gathering note titles or note definitions as extra metadata
input_tiu_defs as (
select a.*, b.TIUDocumentDefinition
from input_data a
join dim.TIUDocumentDefinition b
on a.tiudocumentdefinitionsid=b.tiudocumentdefinitionsid
),


-- filtering out note definitions that contain bad reporttext
filter_out_defs as (
select * from input_tiu_defs
where tiudocumentdefinition not like '%TIME OUT NON-OR%'
and tiudocumentdefinition not like '%RADIOLOGY QUALITY ASSURANCE%'
and tiudocumentdefinition not like '%POST IMAGING W/CONTRAST DISCHARGE EDUCATION%' --"interviewed patient about kidney transplant" templated notes
and TIUDocumentDefinition not like '%liver transpl%'
and TIUDocumentDefinition not like '%heart transpl%'
and TIUDocumentDefinition not like '%cardiac transpl%'
and TIUDocumentDefinition not like '%group%'
),

-- filter out specific noisy nlp output, but not the whole note
filter_out_nlp as (
select nlp_raw.* from nlp_raw 
join tiu_list on nlp_raw.tiudocumentsid=tiu_list.tiudocumentsid
where lower(span) != 'tx' 
and not ([label]='KIDNEY_TRANSPLANT' and modifier is null)
and not ([label]='UNKNOWN_TRANSPLANT' and modifier is null)
)

-- build cleaned up table with extra metadata
select distinct a.PatientICN
, a.PatientSID
, a.sta3n
, a.CohortEntryDate
, a.TIUDocumentDefinition
, a.ReferenceDateTime
, case when a.sta3n in (648, 580, 578, 636, 521, 526, 646, 688) -- is a va location that performs kidney transplants
	then 1 
	else 0
	end txp_sta3n
, case when TIUDocumentDefinition like '%neph%' -- note title/definition has nephrology/kidney keywords
	or TIUDocumentDefinition like '%renal%' 
	or TIUDocumentDefinition like '%kidney%'
	then 1
	else 0
	end nephrology_note
, case when TIUDocumentDefinition like '%transplant%' and (TIUDocumentDefinition like '%physician%' and TIUDocumentDefinition like '%assessment%')  -- note title/definition is a transplant assessment title
    then 1
	else 0
	end transplant_assessment_note
, case when TIUDocumentDefinition like '%transplant%'  -- note title/definition has the word "transplant"
    then 1
	else 0
	end transplant_note
, a.TIUDocumentSID
, b.span
, case when b.[label] = 'DUAL_TRANSPLANT' and b.span like '%pancreas%' then 'KIDNEY_TRANSPLANT' else b.[label] end [label]  -- if dual transplant was detected, but it was a joint kidney/pancreas transplant, override
, b.start_char
, b.end_char
, b.modifier
, b.modifier_label
, b.is_historical
, b.is_negated
, input_data.kidney_keyword
, input_data.nephrology_keyword
, input_data.dialysis_keyword
, case when c.tiudocumentsid is null then 0 else 1 end kidney_transplant_phrase  --flag whole note for certain nlp output
, case when d.tiudocumentsid is null then 0 else 1 end conditional_phrase
, case when e.tiudocumentsid is null then 0 else 1 end not_a_candidate_phrase
, case when f.tiudocumentsid is null then 0 else 1 end other_transplant

from 
input_data
left join filter_out_defs a 
on input_data.tiudocumentsid=a.tiudocumentsid
left join filter_out_nlp b
on a.tiudocumentsid=b.tiudocumentsid
left join kidney_translant_phrase c
on a.tiudocumentsid=c.tiudocumentsid
left join conditional_phrase d
on a.tiudocumentsid=d.tiudocumentsid
left join not_a_candidate_phrase e
on a.tiudocumentsid=e.tiudocumentsid
left join other_transplant f
on a.tiudocumentsid=f.tiudocumentsid
where a.PatientICN is not null
GO


