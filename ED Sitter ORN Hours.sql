
WITH SITTER AS
(
select
PAY_END_DT
,concat(sub.building, sub.cost_center) as BCC
,sub.Cost_Center_Desc as MYTIME_GL_COST_CENTER_NM
,sum(sub.[Hours]) as Total_Sitter_Hours
from
(
select
E.CODE as EMP_CODE
,ISNULL(e.LASTNAME, '')+','+ISNULL(e.FIRSTNAME, '') as EMPLOYEE_NAME
,substring(OU.OrganizationUnitCode3,6,3) as Company
,substring(OU.OrganizationUnitCode3,1,4) as Building
,OU.ORGANIZATIONUNITCODE as COST_CENTER
,OU.ORGANIZATIONUNITDESCRIPTION1 as COMPANY_NM
,ou.ORGANIZATIONUNITDESCRIPTION3 as BUILDING_NM
,ou.BRANCHORGANIZATIONUNITDESCRIPTION as COST_CENTER_DESC
,JC.CODE as JOB_CODE
,JC.[DESCRIPTION] as JOB_DESC
,EPB.WHENPOSTED as POSTDATE
,PC.CODE
,epb.HOURVALUE as [HOURS]
, pp.pay_period_End_dt PAY_END_DT
from  [Source_UWHealth].[MYTIME_EMPLOYEEPREMIUMBUCKET_CUR] EPB
inner join  [Source_UWHealth].[MYTIME_PAYCODE_CUR] PC
on EPB.PAYCODEID = PC.ID
inner join  [Source_UWHealth].[MYTIME_EMPLOYEE_CUR] E
on EPB.EMPLOYEEID = E.ID
inner join [Source_UWHealth].[MYTIME_ORGANIZATIONHIERARCHY_CUR]  OU
on EPB.ORGANIZATIONUNITID = OU.ORGANIZATIONUNITID
inner join [Source_UWHealth].[MYTIME_JOBCLASS_CUR]  JC
on EPB.JOBCLASSID = JC.ID
inner join  [Source_UWHealth].[MYTIME_LABORDISTRIBUTION_CUR] LD
on EPB.EMPLOYEEID = LD.EMPLOYEEID
inner join [Source_UWHealth].[MYTIME_SENIORITY_CUR]  S
on LD.SENIORITYID = S.ID
inner join  [Source_UWHealth].[MYTIME_PAYCODEINDICATOR_CUR]  PCI
on PC.ID = PCI.PAYCODEID
left join [Source_UWHealth].[UDD_EA_PRODUCTIVITY_MYTIME_TO_ERNCD] pb
on pc.code = pb.strip
left outer join  mart_UWHealth.Ref_all_PayPeriod PP
on epb.whenposted between pp.pay_period_Start_dt and pp.pay_period_End_DT
where
EPB.PAYMENTCLASSIFICATION = '1'
--and LD.ISEFFECTIVE = '1'
and LD.CLASSIFICATION = '1 '
and PCI.NUMBER = '1'
and PCI.CATEGORY = '1'
and PCI.CLASSIFICATION = '1'
and PCI.CODE = 'Y'
AND (
        LD.WhenExpire IS NULL
        OR LD.WhenExpire >= LD.WhenEffective
    ) -- Filter out invalid labor distributions (expire before effective)
AND (
        LD.WhenEffective <= EPB.WhenPosted
        AND (
                LD.WhenExpire IS NULL
                OR LD.WhenExpire >= EPB.WhenPosted
        )
    ) -- Locate the labor distribution that was effective at the time of the EPB entry
and EPB.HOURVALUE is not null
and pc.code in ('SITR', 'SIOTE', 'SIOTN', 'SIOSE') -- SIOTE & SIOSE are not being used currently.
) sub
Group by
PAY_END_DT
,concat(sub.building, sub.cost_center)
,sub.Cost_Center_Desc
)

,RES_ORI AS
(
SELECT 
        PAY_END_DT
        ,CONCAT([ORIGINAL_GL_BUILDING_ID],[ORIGINAL_GL_COST_CENTER_ID]) AS BCC
        ,SUM(WORKED_HR) AS RES_ORI_HOURS
  FROM [Mart_UWHealth].[PRODUCTIVITY_PAYROLL_BWK]
  where JOB_CD_DESC LIKE '%Resident%'
  AND ELEMENT_NAME LIKE '%Orientation%'
  AND DELETE_ROW_FLG = 'N'
  GROUP BY PAY_END_DT
        ,CONCAT([ORIGINAL_GL_BUILDING_ID],[ORIGINAL_GL_COST_CENTER_ID])
)

,TOTAL_WORKED AS
(
select
CONCAT([ORIGINAL_GL_BUILDING_ID],[ORIGINAL_GL_COST_CENTER_ID]) AS BCC
,GL_BUILDING_NM
,GL_COST_CENTER_NM
,bwk.Pay_end_dt
,sum(bwk.worked_hr) as Total_Worked_hours
,sum(bwk.NON_PROD_WORKED_HR) as Total_Non_Prod_Worked_hours
from Mart_UWHealth.PRODUCTIVITY_PAYROLL_BWK bwk
Where
bwk.delete_row_Flg = 'N'
group by
CONCAT([ORIGINAL_GL_BUILDING_ID],[ORIGINAL_GL_COST_CENTER_ID])
,GL_BUILDING_NM
,GL_COST_CENTER_NM
,bwk.Pay_end_dt
)

SELECT
        A.PAY_END_DT
        ,CASE WHEN dep.ROLLUP_CD <> '0' then ROLLUP_CD ELSE A.BCC END AS BCC
        ,case when dep.ROLLUP_CD <> '0' then 'Rollup' else A.GL_BUILDING_NM end as GL_BUILDING_NM
        ,case when dep.ROLLUP_CD <> '0' then dep.ROLLUP_DESC else A.GL_COST_CENTER_NM end as GL_COST_CENTER_NM
        ,SUM(A.TOTAL_WORKED_HOURS)/80 AS TOTAL_WORKED_FTE
        ,SUM(A.TOTAL_NON_PROD_WORKED_HOURS)/80 AS TOTAL_NON_PROD_WORKED_FTE
        ,coalesce(SUM(B.TOTAL_SITTER_HOURS),0)/80 AS TOTAL_SITTER_FTE
        ,coalesce(SUM(C.RES_ORI_HOURS),0)/80 AS RES_ORI_FTE
FROM TOTAL_WORKED A
LEFT JOIN SITTER B
        ON A.BCC = B.BCC AND A.PAY_END_DT = B.PAY_END_DT
LEFT JOIN RES_ORI C
        ON A.BCC = C.BCC AND A.PAY_END_DT = C.PAY_END_DT
left join  [Source_UWHealth].[UDD_EA_PRODUCTIVITY_COST_CENTER] dep 
        on  A.BCC  = CONCAT(dep.GL_BUILDING_ID,dep.GL_COST_CENTER_ID) 
        and A.pay_end_dt between DEP.Target_start_dt and DEP.Target_end_Dt
WHERE A.PAY_END_DT between 
(SELECT DATEADD(YEAR, -1, MAX(PAY_END_DT)) FROM TOTAL_WORKED)
  AND (SELECT MAX(PAY_END_DT) FROM TOTAL_WORKED)
  AND A.BCC = '10803033114'
GROUP BY A.PAY_END_DT
        ,CASE WHEN dep.ROLLUP_CD <> '0' then ROLLUP_CD ELSE A.BCC END
        ,case when dep.ROLLUP_CD <> '0' then 'Rollup' else A.GL_BUILDING_NM end
        ,case when dep.ROLLUP_CD <> '0' then dep.ROLLUP_DESC else A.GL_COST_CENTER_NM end
ORDER by CASE WHEN dep.ROLLUP_CD <> '0' then ROLLUP_CD ELSE A.BCC END
    , A.PAY_END_DT DESC
