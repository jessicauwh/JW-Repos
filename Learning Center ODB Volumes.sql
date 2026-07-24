/*Instructional Hours - Quarterly Volumes 
*/
------------------------------------------------------------

--Declare @QuarterStartDate as Date = '2025-10-01'; -642 Q4
--Declare @QuarterEndDate as Date = '2025-12-31';
Declare @QuarterStartDate as Date = '2025-10-01'; --583 Q1
Declare @QuarterEndDate as Date = '2025-12-31';
 
select
'ME_500610' as GL_Account_ID
,'10803035433' as ACC
,sum(hsp.QUANTITY)/4 UOS
from [Source_UWHealth].[EPIC_HSP_TRANSACTIONS_CUR] hsp
where CONCAT(substring(hsp.GL_CREDIT_NUM,4,4), substring(hsp.GL_CREDIT_NUM,14,7)) = '10803035433'
and cpt_code = 'HBZ9907'
and hsp.SERVICE_DATE  between @QuarterStartDate AND @QuarterEndDate