/*
ODB DEPARTMENT(S)
10133042065, CLINICAL NUTRITION - WEST
10803042065, CLINICAL NUTRITION - UH
CLINICAL NUTRITION - AFCH (10813042065, 10813042108)
 
MEASURE
Total Medical Nutritional Therapy Interventions
 
DEFINITION
Total medical nutrition therapy interventions provided by Food and Nutritional Services staff from this department. 
Include both initial and follow up consults. A Medical Nutrition Intervention is defined as a 15 minute block of time
allocated directly to the assessment, planning, patient education or provision of patient nutrition care. 
Excluded is screening and time spent in inservice education, classes provided to non patients, staff meetings, and program development time. 
Count each 15 minute block of time as an intervention.This is a subset of Patient Activity.
 
 
DATE			DEVELOPER			ACTION
3/25/2022		Brooke Temple		Copied historical query
5/10/2022		Brooke Temple		Query updated to change minutes per encounter for 10803042065 from 57 to 56
6/17/2024		Matthew Cornelius	Coverted to SSMS
*/
 
 
DECLARE @BeginDate DATE = '20240501'
DECLARE @EndDate DATE = '20240531'
 
 
--INSERT INTO Adhoc_UWHealth.ODB_GL_TEMP 
--(      Uncomment to make tabel
SELECT 
	'ME_500132' AS GL_Account_ID,
	sub2.BUILDING_CC AS ACC,
	CASE 
		WHEN sub2.BUILDING_CC = '10603042065' THEN (sum(sub2.QTY)* 78)/15 --based on number of minutes established per encounter as of 11/20/2020 --may need to update regularly
		WHEN sub2.BUILDING_CC = '10813042065' THEN (sum(sub2.QTY)* 78)/15  --based on number of minutes established per encounter as of 11/20/2020 --may need to update regularly
		WHEN sub2.BUILDING_CC = '10803042065' THEN (sum(sub2.QTY) * 56)/15  --based on number of minutes established per encounter as of October 2021 --may need to update regularly
		WHEN sub2.BUILDING_CC = '10133042065' THEN (sum(sub2.QTY) * 120)/15  --based on number of minutes established per encounter as of 11/20/2020 --may need to update regularly
	END AS TOTAL_AMOUNT
FROM
(
	SELECT 
		cc.BUILDING_CC AS BUILDING_CC
		, SUM(ucl.QUANTITY) AS QTY
	FROM Source_UWHealth.EPIC_CLARITY_UCL_CUR ucl
	LEFT JOIN Source_UWHealth.EPIC_CLARITY_EAP_CUR eap ON ucl.PROCEDURE_ID = eap.PROC_ID
	INNER JOIN Source_UWHealth.UDD_EA_CLIN_NUTR_MAP_V2 cc ON ucl.DEPARTMENT_ID = cc.HL_DEPT
	WHERE 
		eap.PROC_CODE = 'HBZ1060'
		AND ucl.SERVICE_DATE_DT BETWEEN @BeginDate AND @EndDate
	GROUP BY
		cc.BUILDING_CC
 
	UNION ALL
 
	SELECT
		'10813042065' AS BUILDING_CC
		, SUM(sub.WORKLOAD_MIN)/78 AS QTY
	FROM
	(
		SELECT
			SUM(hsp.QUANTITY)*5 AS WORKLOAD_MIN
		FROM Source_UWHealth.EPIC_HSP_TRANSACTIONS_CUR hsp
		LEFT JOIN Source_UWHealth.EPIC_CLARITY_EAP_CUR eap ON hsp.PROC_ID = eap.PROC_ID
		WHERE 
			SUBSTRING(hsp.GL_CREDIT_NUM,4,4) = '1081' 
			AND SUBSTRING(hsp.GL_CREDIT_NUM,14,7) = '3042065'
			AND hsp.SERVICE_DATE BETWEEN @BeginDate AND @EndDate
			AND eap.PROC_CODE IN ('HBZ1120')
 
		UNION ALL
 
		SELECT
			SUM(hsp.QUANTITY)*15 WORKLOAD_MIN
		FROM Source_UWHealth.EPIC_HSP_TRANSACTIONS_CUR hsp
		LEFT JOIN Source_UWHealth.EPIC_CLARITY_EAP_CUR eap ON hsp.PROC_ID = eap.PROC_ID
		WHERE 
			SUBSTRING(hsp.GL_CREDIT_NUM,4,4)= '1081' 
			AND SUBSTRING(hsp.GL_CREDIT_NUM,14,7) = '3042065'
			AND hsp.SERVICE_DATE BETWEEN @BeginDate AND @EndDate
			AND eap.PROC_CODE IN ('HBZ1117')
 
		UNION ALL
 
		SELECT
			SUM(hsp.QUANTITY)*15 AS WORKKLOAD_MIN
		FROM Source_UWHealth.EPIC_HSP_TRANSACTIONS_CUR hsp
		LEFT JOIN Source_UWHealth.EPIC_CLARITY_EAP_CUR eap ON hsp.PROC_ID = eap.PROC_ID
		WHERE 
			SUBSTRING(hsp.GL_CREDIT_NUM,4,4)= '1081' 
			AND SUBSTRING(hsp.GL_CREDIT_NUM,14,7) = '3042065'
			AND hsp.SERVICE_DATE BETWEEN @BeginDate AND @EndDate
			AND eap.PROC_CODE in ('HBZ1118')
 
		UNION ALL
 
		SELECT
			SUM(hsp.QUANTITY)*10 AS WORKLOAD_MIN
		FROM Source_UWHealth.EPIC_HSP_TRANSACTIONS_CUR hsp
		LEFT JOIN Source_UWHealth.EPIC_CLARITY_EAP_CUR eap ON hsp.PROC_ID = eap.PROC_ID
		WHERE 
			SUBSTRING(hsp.GL_CREDIT_NUM,4,4)= '1081' 
			AND SUBSTRING(hsp.GL_CREDIT_NUM,14,7) = '3042065'
			AND hsp.SERVICE_DATE BETWEEN @BeginDate AND @EndDate
			AND eap.PROC_CODE in ('HBZ1119')
	)sub
)sub2
GROUP BY
	sub2.BUILDING_CC