declare @QuarterStartDate date =  '1/1/2026'
declare @QuarterEndDate date =  '3/31/2026'
declare @FiscalYear varchar(4) = '2026'
declare @FiscalPeriodBegin varchar(2) = '07'	--FP must be two digits
declare @FiscalPeriodEnd varchar(2) = '09'	--FP must be two digits 06 = December
;


--Use the below query to Pull initial data
--Make sure to update the FY and FP filters before running the below query (there are two places)
--Double check most recent version of the ActionOI Master APC and Work RVU Weights Table worksheet and make sure cpt codes that start with the following letters are still not on it
----'A','B','E','F','H','I','J','K','L','N','O','R','S','T','W','X','Y','Z'
----Table is usually updated once per year in line with Q1 of the calendar year
------Current table (as of 8/9/2023) is APC and ProfWork RVU Worksheet June 2023 saved here:  U:UWHealth\EA\SpecialShares\PPA\Benchmarking\ODB\Data Collection\1 - Upload Files\GL Upload File\Worksheets\APC and ProfWork RVU Worksheet June 2023.xlsx
--If any CPT codes in the worksheet start with any of the above letters, remove those letters from every instance of this filter below:
----AND substr(rev.CPT_HCPCS,1,1) not in ('A','B','E','F','H','I','J','K','L','N','O','R','S','T','W','X','Y','Z')--Double check most recent version of the ActionOI Master APC and Work RVU Weights Table
--then run

select top 1000 * from Mart_UWHealth.UWHC_REVENUE_USAGE rev
where --rev.GL_COMPANY_ID = '211'
--AND CONCAT(rev.GL_BUILDING_ID,rev.GL_COST_CENTER_ID) = '10803035587'
--AND 
	rev.GL_COST_CENTER_ID = '3033113'

--This part of the query finds volumes for UWHC
With HB_Volume_Query as (
SELECT
	concat(rev.GL_BUILDING_ID,rev.GL_COST_CENTER_ID) AS ACC
	,rev.CPT_HCPCS AS CPT_HCPCS_Code
	,SUM(rev.CUR_TOT_VOL) AS Total_Procedures
	,CASE WHEN SUM(rev.CUR_IP_VOL) < 0 THEN 0
	ELSE SUM(rev.CUR_IP_VOL)
	END AS Inpatient_Procedures
FROM
	Mart_UWHealth.UWHC_REVENUE_USAGE rev
WHERE
	rev.GL_COMPANY_ID = '211'
	AND rev.FISCAL_YEAR =  @FiscalYear 
	AND rev.FISCAL_PERIOD BETWEEN @FiscalPeriodBegin AND @FiscalPeriodEnd 
	AND rev.CPT_HCPCS IS NOT NULL --NULL CPTs are for HBZ codes and supplies that don't drop a billable CPT code
	AND substring(rev.CPT_HCPCS,1,1) not in ('A','B','E','F','H','I','J','K','L','N','O','R','S','T','W','X','Y','Z')--Double check most recent version of the ActionOI Master APC and Work RVU Weights Table
	--AND rev.GL_COST_CENTER_ID not like '3031%'--clin lab cost centers
	--AND rev.GL_COST_CENTER_ID not like '3030%'--clinics cost centers
	AND rev.GL_COST_CENTER_ID not like '3041%'--reg services cost centers

GROUP BY
	concat(rev.GL_BUILDING_ID,rev.GL_COST_CENTER_ID)
	,rev.CPT_HCPCS
HAVING
	SUM(rev.CUR_TOT_VOL) > 0
--ORDER BY
--	concat(rev.GL_BUILDING_ID,rev.GL_COST_CENTER_ID)
--	,rev.CPT_HCPCS
)

--This part of the query finds volumes for UWMF cost centers that do not have UWHC equivalents
,PB_Volume_Query as (
   select
         concat(substring(agl.credit_gl, 4, 4),substring(agl.credit_gl, 14, 7)) as ACC
         ,pbt.cpt_code
		 ,sum(pbt.procedure_quantity)   as Total_Procedures
		 ,'0' as Inpatient_Procedures
    from Source_UWHealth.EPIC_ARPB_TRANSACTIONS_CUR pbt 
        left join Source_UWHealth.EPIC_CLARITY_EAP_CUR eap on pbt.proc_id = eap.proc_id
        left join Source_UWHealth.EPIC_ARPB_TX_GL_CUR agl on pbt.tx_id = agl.tx_id
            and agl.gl_type_c = 1 --grab string values from original post
        left join Source_UWHealth.EPIC_PAT_ENC_CUR pe on pbt.pat_enc_csn_id = pe.pat_enc_csn_id
            and pe.appt_status_c in (2,6)
        left join Source_UWHealth.EPIC_CLARITY_DEP_CUR dep on pe.department_id = dep.department_id
        left join Source_UWHealth.EPIC_CLARITY_PRC_CUR prc on pe.appt_prc_id = prc.prc_id
        left join Source_UWHealth.EPIC_CLARITY_POS_CUR tpos on pbt.pos_id = tpos.pos_id
        left join Source_UWHealth.EPIC_BILL_AREA_CUR bil on pbt.bill_area_id = bil.bill_area_id
    where 1=1   
        and pbt.tx_type_c = 1
       and pbt.service_date between @QuarterStartDate AND @QuarterEndDate
        and substring(agl.credit_gl, 1, 3) = '310'
        and pbt.void_date is null --exclude voided procedures
        and pbt.cpt_code != '36415'
		and substring(pbt.cpt_code,1,1) not in ('A','B','E','F','H','I','J','K','L','N','O','R','S','T','W','X','Y','Z')
        and substring(agl.credit_gl, 14, 7) not like '3030%'--clinics
		and substring(agl.credit_gl, 14, 7) not like '3041%'--reg services
		and substring(agl.credit_gl, 14, 7) not like '3035%'--nursing
		and substring(agl.credit_gl, 14, 7) not like '5%'
		and substring(agl.credit_gl, 14, 7) not like '6%'
		and substring(agl.credit_gl, 14, 7) not like '0000000%'
        --and bil.gl_prefix not like '3031%' --exclude bill area mapping to lab
		and concat(substring(agl.credit_gl, 4, 4),substring(agl.credit_gl, 14, 7)) not in (select ACC from HB_Volume_Query)
		group by 
		concat(substring(agl.credit_gl, 4, 4),substring(agl.credit_gl, 14, 7))
         ,pbt.cpt_code

) 

select * FROM
HB_Volume_Query
UNION ALL
SELECT * FROM
PB_Volume_Query