drop table if exists #anns
select * 
into #anns
from nlp.txp_sample_annotation_wide

drop table if exists #nlp
select *
into #nlp
from nlp.txp_sample_wide_all_updated
where dual_transplant=0

----- TREATMENT PERFORMANCE ---------

drop table if exists #treatment_tp
select a.PatientICN, a.ScrSSN, a.treatment_TIU ann_tiu, a.treatment_TIU_ReferenceDateTime ann_date, n.treatment_TIU nlp_tiu, n.treatment_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.treatment_tiu_referencedatetime, n.treatment_TIU_ReferenceDateTime) date_diff 
into #treatment_tp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.treatment_tiu_referencedatetime, n.treatment_TIU_ReferenceDateTime)) < 90

drop table if exists #treatment_fn
select a.PatientICN, a.ScrSSN, a.treatment_TIU ann_tiu, a.treatment_TIU_ReferenceDateTime ann_date, n.treatment_TIU nlp_tiu, n.treatment_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.treatment_tiu_referencedatetime, n.treatment_TIU_ReferenceDateTime) date_diff 
into #treatment_fn
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.treatment_tiu_referencedatetime, n.treatment_TIU_ReferenceDateTime)) >= 90 or (a.treatment_TIU is not null and n.treatment_TIU is null)

drop table if exists #treatment_fp
select a.PatientICN, a.ScrSSN, a.treatment_TIU ann_tiu, a.treatment_TIU_ReferenceDateTime ann_date, n.treatment_TIU nlp_tiu, n.treatment_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.treatment_tiu_referencedatetime, n.treatment_TIU_ReferenceDateTime) date_diff 
into #treatment_fp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where a.treatment_TIU is null and n.treatment_TIU is not null

declare @t_tp float
set @t_tp = (select count(*) from #treatment_tp)
declare @t_fp float
set @t_fp = (select count(*) from #treatment_fp)
declare @t_fn float
set @t_fn = (select count(*) from #treatment_fn)

declare @t_recall float
set @t_recall = @t_tp/(@t_tp + @t_fn)
declare @t_precision float
set @t_precision = @t_tp/(@t_tp + @t_fp)
declare @t_f1 float
select @t_f1 = 2*@t_tp/(2*@t_tp+@t_fp+@t_fn)

declare @t_date_diff float
set @t_date_diff = (select avg(date_diff) from (select * from #treatment_fn union select * from #treatment_fp) a)
declare @t_date_diff_abs float
set @t_date_diff_abs = (select avg(abs(date_diff)) from (select * from #treatment_fn union select * from #treatment_fp) a)
declare @t_date_diff_flr float
set @t_date_diff_flr = (select avg(greatest(0,date_diff)) from (select * from #treatment_fn union select * from #treatment_fp) a)


select @t_precision treatment_precision, @t_recall treatment_recall, @t_f1 treatment_f1, @t_date_diff date_diff, @t_date_diff_abs date_diff_abs, @t_date_diff_flr date_diff_flr

----- EVALUATION PERFORMANCE ---------

drop table if exists #evaluation_tp
select a.PatientICN, a.ScrSSN, a.evaluation_TIU ann_tiu, a.evaluation_TIU_ReferenceDateTime ann_date, n.evaluation_TIU nlp_tiu, n.evaluation_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.evaluation_tiu_referencedatetime, n.evaluation_TIU_ReferenceDateTime) date_diff 
into #evaluation_tp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.evaluation_tiu_referencedatetime, n.evaluation_TIU_ReferenceDateTime)) < 90

drop table if exists #evaluation_fn
select a.PatientICN, a.ScrSSN, a.evaluation_TIU ann_tiu, a.evaluation_TIU_ReferenceDateTime ann_date, n.evaluation_TIU nlp_tiu, n.evaluation_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.evaluation_tiu_referencedatetime, n.evaluation_TIU_ReferenceDateTime) date_diff 
into #evaluation_fn
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.evaluation_tiu_referencedatetime, n.evaluation_TIU_ReferenceDateTime)) >= 90 or (a.evaluation_TIU is not null and n.evaluation_TIU is null)

drop table if exists #evaluation_fp
select a.PatientICN, a.ScrSSN, a.evaluation_TIU ann_tiu, a.evaluation_TIU_ReferenceDateTime ann_date, n.evaluation_TIU nlp_tiu, n.evaluation_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.evaluation_tiu_referencedatetime, n.evaluation_TIU_ReferenceDateTime) date_diff 
into #evaluation_fp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where a.evaluation_TIU is null and n.evaluation_TIU is not null

declare @e_tp float
set @e_tp = (select count(*) from #evaluation_tp)
declare @e_fp float
set @e_fp = (select count(*) from #evaluation_fp)
declare @e_fn float
set @e_fn = (select count(*) from #evaluation_fn)

declare @e_recall float
set @e_recall = @e_tp/(@e_tp + @e_fn)
declare @e_precision float
set @e_precision = @e_tp/(@e_tp + @e_fp)
declare @e_f1 float
select @e_f1 = 2*@e_tp/(2*@e_tp+@e_fp+@e_fn)

declare @e_date_diff float
set @e_date_diff = (select avg(date_diff) from (select * from #evaluation_fn union select * from #evaluation_fp) a)
declare @e_date_diff_abs float
set @e_date_diff_abs = (select avg(abs(date_diff)) from (select * from #evaluation_fn union select * from #evaluation_fp) a)
declare @e_date_diff_flr float
set @e_date_diff_flr = (select avg(greatest(0,date_diff)) from (select * from #evaluation_fn union select * from #evaluation_fp) a)


select @e_precision evaluation_precision, @e_recall evaluation_recall, @e_f1 evaluation_f1, @e_date_diff date_diff, @e_date_diff_abs date_diff_abs, @e_date_diff_flr date_diff_flr

----- REFERRAL PERFORMANCE ---------

drop table if exists #referral_tp
select a.PatientICN, a.ScrSSN, a.referral_TIU ann_tiu, a.referral_TIU_ReferenceDateTime ann_date, n.referral_TIU nlp_tiu, n.referral_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.referral_tiu_referencedatetime, n.referral_TIU_ReferenceDateTime) date_diff 
into #referral_tp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.referral_tiu_referencedatetime, n.referral_TIU_ReferenceDateTime)) < 90

drop table if exists #referral_fn
select a.PatientICN, a.ScrSSN, a.referral_TIU ann_tiu, a.referral_TIU_ReferenceDateTime ann_date, n.referral_TIU nlp_tiu, n.referral_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.referral_tiu_referencedatetime, n.referral_TIU_ReferenceDateTime) date_diff 
into #referral_fn
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where (a.referral_TIU is not null and n.referral_TIU is null) or abs(DATEDIFF(day, a.referral_tiu_referencedatetime, n.referral_TIU_ReferenceDateTime)) >= 90

drop table if exists #referral_fp
select a.PatientICN, a.ScrSSN, a.referral_TIU ann_tiu, a.referral_TIU_ReferenceDateTime ann_date, n.referral_TIU nlp_tiu, n.referral_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.referral_tiu_referencedatetime, n.referral_TIU_ReferenceDateTime) date_diff 
into #referral_fp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where a.referral_TIU is null and n.referral_TIU is not null

declare @r_tp float
set @r_tp = (select count(*) from #referral_tp)
declare @r_fp float
set @r_fp = (select count(*) from #referral_fp)
declare @r_fn float
set @r_fn = (select count(*) from #referral_fn)

declare @r_recall float
set @r_recall = @r_tp/(@r_tp + @r_fn)
declare @r_precision float
set @r_precision = @r_tp/(@r_tp + @r_fp)
declare @r_f1 float
select @r_f1 = 2*@r_tp/(2*@r_tp+@r_fp+@r_fn)

declare @r_date_diff float
set @r_date_diff = (select avg(date_diff) from (select * from #referral_fn union select * from #referral_fp) a)
declare @r_date_diff_abs float
set @r_date_diff_abs = (select avg(abs(date_diff)) from (select * from #referral_fn union select * from #referral_fp) a)
declare @r_date_diff_flr float
set @r_date_diff_flr = (select avg(greatest(0,date_diff)) from (select * from #referral_fn union select * from #referral_fp) a)


select @r_precision referral_precision, @r_recall referral_recall, @r_f1 referral_f1, @r_date_diff date_diff, @r_date_diff_abs date_diff_abs, @r_date_diff_flr date_diff_flr


----- CLINIC PERFORMANCE ---------

drop table if exists #clinic_tp
select a.PatientICN, a.ScrSSN, a.clinic_TIU ann_tiu, a.clinic_TIU_ReferenceDateTime ann_date, n.clinic_TIU nlp_tiu, n.clinic_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.clinic_tiu_referencedatetime, n.clinic_TIU_ReferenceDateTime) date_diff 
into #clinic_tp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.clinic_tiu_referencedatetime, n.clinic_TIU_ReferenceDateTime)) < 90

drop table if exists #clinic_fn
select a.PatientICN, a.ScrSSN, a.clinic_TIU ann_tiu, a.clinic_TIU_ReferenceDateTime ann_date, n.clinic_TIU nlp_tiu, n.clinic_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.clinic_tiu_referencedatetime, n.clinic_TIU_ReferenceDateTime) date_diff 
into #clinic_fn
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.clinic_tiu_referencedatetime, n.clinic_TIU_ReferenceDateTime)) >= 90 or (a.clinic_TIU is not null and n.clinic_TIU is null)

drop table if exists #clinic_fp
select a.PatientICN, a.ScrSSN, a.clinic_TIU ann_tiu, a.clinic_TIU_ReferenceDateTime ann_date, n.clinic_TIU nlp_tiu, n.clinic_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.clinic_tiu_referencedatetime, n.clinic_TIU_ReferenceDateTime) date_diff 
into #clinic_fp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where a.clinic_TIU is null and n.clinic_TIU is not null

declare @c_tp float
set @c_tp = (select count(*) from #clinic_tp)
declare @c_fp float
set @c_fp = (select count(*) from #clinic_fp)
declare @c_fn float
set @c_fn = (select count(*) from #clinic_fn)

declare @c_recall float
set @c_recall = @c_tp/(@c_tp + @c_fn)
declare @c_precision float
set @c_precision = @c_tp/(@c_tp + @c_fp)
declare @c_f1 float
select @c_f1 = 2*@c_tp/(2*@c_tp+@c_fp+@c_fn)

declare @c_date_diff float
set @c_date_diff = (select avg(date_diff) from (select * from #clinic_fn union select * from #clinic_fp) a)
declare @c_date_diff_abs float
set @c_date_diff_abs = (select avg(abs(date_diff)) from (select * from #clinic_fn union select * from #clinic_fp) a)
declare @c_date_diff_flr float
set @c_date_diff_flr = (select avg(greatest(0,date_diff)) from (select * from #clinic_fn union select * from #clinic_fp) a)


select @c_precision clinic_precision, @c_recall clinic_recall, @c_f1 clinic_f1, @c_date_diff date_diff, @c_date_diff_abs date_diff_abs, @c_date_diff_flr date_diff_flr


----- FINAL MENTION PERFORMANCE ---------

drop table if exists #final_mention_tp
select a.PatientICN, a.ScrSSN, a.final_mention_TIU ann_tiu, a.final_mention_TIU_ReferenceDateTime ann_date, n.final_mention_TIU nlp_tiu, n.final_mention_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.final_mention_tiu_referencedatetime, n.final_mention_TIU_ReferenceDateTime) date_diff 
into #final_mention_tp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.final_mention_tiu_referencedatetime, n.final_mention_TIU_ReferenceDateTime)) < 90

drop table if exists #final_mention_fn
select a.PatientICN, a.ScrSSN, a.final_mention_TIU ann_tiu, a.final_mention_TIU_ReferenceDateTime ann_date, n.final_mention_TIU nlp_tiu, n.final_mention_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.final_mention_tiu_referencedatetime, n.final_mention_TIU_ReferenceDateTime) date_diff 
into #final_mention_fn
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where abs(DATEDIFF(day, a.final_mention_tiu_referencedatetime, n.final_mention_TIU_ReferenceDateTime)) >= 90 or (a.final_mention_TIU is not null and n.final_mention_TIU is null)

drop table if exists #final_mention_fp
select a.PatientICN, a.ScrSSN, a.final_mention_TIU ann_tiu, a.final_mention_TIU_ReferenceDateTime ann_date, n.final_mention_TIU nlp_tiu, n.final_mention_TIU_ReferenceDateTime nlp_date, DATEDIFF(day, a.final_mention_tiu_referencedatetime, n.final_mention_TIU_ReferenceDateTime) date_diff 
into #final_mention_fp
from #anns a
join #nlp n
on a.PatientICN=n.PatientICN
where a.final_mention_TIU is null and n.final_mention_TIU is not null

declare @f_tp float
set @f_tp = (select count(*) from #final_mention_tp)
declare @f_fp float
set @f_fp = (select count(*) from #final_mention_fp)
declare @f_fn float
set @f_fn = (select count(*) from #final_mention_fn)

declare @f_recall float
set @f_recall = @f_tp/(@f_tp + @f_fn)
declare @f_precision float
set @f_precision = @f_tp/(@f_tp + @f_fp)
declare @f_f1 float
select @f_f1 = 2*@f_tp/(2*@f_tp+@f_fp+@f_fn)

declare @f_date_diff float
set @f_date_diff = (select avg(date_diff) from (select * from #final_mention_fn union select * from #final_mention_fp) a)
declare @f_date_diff_abs float
set @f_date_diff_abs = (select avg(abs(date_diff)) from (select * from #final_mention_fn union select * from #final_mention_fp) a)
declare @f_date_diff_flr float
set @f_date_diff_flr = (select avg(greatest(0,date_diff)) from (select * from #final_mention_fn union select * from #final_mention_fp) a)


select @f_precision final_mention_precision, @f_recall final_mention_recall, @f_f1 final_mention_f1, @f_date_diff date_diff, @f_date_diff_abs date_diff_abs, @f_date_diff_flr date_diff_flr