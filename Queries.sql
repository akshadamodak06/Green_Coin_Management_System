SET SEARCH_PATH TO GREENCOIN;
SELECT * FROM BRANCH;
SELECT * FROM "Transaction";
SELECT * FROM COMPANY;
SELECT * FROM COMPANYCONDITIONS;
SELECT * FROM COMPANYEMAIL;
SELECT * FROM COMPANYEMISSION;
SELECT * FROM COMPANYTYPE;
SELECT * FROM COMPANYTYPEGASMAPPING;
SELECT * FROM CONDITIONS;
SELECT * FROM CREDIT;
SELECT * FROM GOVERNMENTPOLICY;
SELECT * FROM GREENHOUSEGASES;
SELECT * FROM NGOCOLLABORATIONS;
SELECT * FROM NGOS;
SELECT * FROM PENALTY;
SELECT * FROM POCEMAIL;
SELECT * FROM POCS;
SELECT * FROM PROJECT;
SELECT * FROM REGULATION;
SELECT * FROM REGULATOR;
SELECT * FROM REWARD;


--1 View All Transactions Involving a Particular Company
SELECT * FROM "Transaction"
	WHERE BuyerRegNo = 1000000002 OR SellerRegNo = 1000000002
	ORDER BY tdate DESC;

--2 Companies that Paid Penalties in a Specific Year (e.g., 2023)
SELECT  P.PenaltyID, P.Amount, C.RegNo, C.CompanyName, C.CType
	FROM Company C JOIN Penalty P ON C.RegNo = P.RegNo
		WHERE P.CreditAllocatedYear = 2023;

--3 Companies rewarded for fulfilling all conditions of a reward
SELECT DISTINCT C.CompanyName, CC."Year", R.RewardID, R.RewardType, R.rewarddescription
FROM Company C
JOIN CompanyConditions CC ON C.RegNo = CC.RegNo
JOIN Conditions Cond ON CC.ConditionID = Cond.ConditionID
JOIN Reward R ON Cond.RewardID = R.RewardID
WHERE NOT EXISTS (
    SELECT 1 FROM Conditions Cond2
    WHERE Cond2.RewardID = R.RewardID
    AND NOT EXISTS (
        SELECT 1 FROM CompanyConditions CC2
        WHERE CC2.RegNo = C.RegNo AND CC2.ConditionID = Cond2.ConditionID
    )
);

--4 Top 5 Active Companies by Trading Activity in a given year(2019)
WITH TradingActivity AS (
  SELECT c.RegNo, c.CompanyName, SUM(COALESCE(cr.CBuy, 0) + COALESCE(cr.CSell, 0)) AS TotalTrade 
  FROM Company c JOIN Credit cr ON c.RegNo = cr.RegNo
  	WHERE cr.CreditAllocatedYear = 2019
  	GROUP BY c.RegNo, c.CompanyName
)
SELECT RegNo, CompanyName, TotalTrade 
FROM TradingActivity
ORDER BY TotalTrade DESC 
LIMIT 5;

--5 Companies Exceeding Allocated Credits with Associated Penalties
SELECT c.RegNo, c.CompanyName, cr.CAllocated, cr.CProduced, p.PenaltyID, p.Amount, p.PayDate FROM 
	(Company c JOIN Credit cr ON c.RegNo = cr.RegNo) JOIN Penalty p ON (c.RegNo = p.RegNo AND cr.CreditAllocatedYear = p.CreditAllocatedYear)
	WHERE cr.CProduced > cr.CAllocated;

--6 Impact of NGO Collaborations on Company Credits

SELECT nc.CreditAllocatedYear, c.RegNo, c.CompanyName,SUM(n.CreditReduced) AS TotalNGOCreditReduced
	FROM NGOCollabrations nc 
	JOIN NGOs n ON (nc.NGORegNo = n.NGORegNo AND nc.NGOProjectID = n.NGOProjectID)
	JOIN Company c ON nc.RegNo = c.RegNo
	GROUP BY nc.CreditAllocatedYear, c.RegNo, c.CompanyName
	ORDER BY TotalNGOCreditReduced DESC;

--7 aggregation of Company Emissions by Gas Type
SELECT ce.RegNo, c.CompanyName, ce.GasName, ce.CompanyType, SUM(ce.EquivalentTonnes) AS TotalEquivalentTonnes
	FROM CompanyEmission ce
	JOIN Company c ON ce.RegNo = c.RegNo
	WHERE ce.EmissionYear = 2023
	GROUP BY ce.RegNo, c.CompanyName, ce.GasName, ce.CompanyType
	ORDER BY TotalEquivalentTonnes DESC;


--8 Industry Credit Performance Overview
WITH IndustryPerformance AS (
  SELECT 
    c.IndustryType, 
    TRUNC(AVG(cr.CProduced),2) AS AvgProduced, 
    TRUNC(AVG(cr.CAllocated),2) AS AvgAllocated,
    TRUNC(AVG(cr.CAllocated)::decimal(10,2) / NULLIF(AVG(cr.CProduced), 0),2) AS ProducedToAllocatedRatio
  FROM Company c
  JOIN Credit cr ON c.RegNo = cr.RegNo AND cr.CreditAllocatedYear=2019
  GROUP BY c.IndustryType
)
SELECT *
FROM IndustryPerformance
ORDER BY ProducedToAllocatedRatio DESC;

--9 Companies Without Any NGO Collaborations

SELECT 
  c.RegNo, 
  c.CompanyName
FROM Company c
LEFT JOIN NGOCollabrations nc ON c.RegNo = nc.RegNo
WHERE nc.RegNo IS NULL;


--10 Comprehensive Company Performance Dashboard

SELECT 
  c.RegNo,
  c.CompanyName,
  cr.CreditAllocatedYear,
  cr.CAllocated,
  cr.CProduced,
  cr.CNgo,
  COALESCE(cr.CBuy, 0) + COALESCE(cr.CSell, 0) AS TotalTransactions,
  (SELECT COALESCE(SUM(p.Amount), 0) FROM Penalty p 
   		WHERE p.RegNo = c.RegNo AND p.CreditAllocatedYear = cr.CreditAllocatedYear) AS TotalPenaltyAmount,
  -- Active projects count per company for that year
  (SELECT COUNT(*)
   FROM Project p
   WHERE p.RegNo = c.RegNo 
     AND p."Year" = cr.CreditAllocatedYear
     AND p."Status" = 'Active') AS ActiveProjects
FROM Company c
JOIN Credit cr ON c.RegNo = cr.RegNo
ORDER BY c.CompanyName, cr.CreditAllocatedYear;

--11 Rank States Based on Total Branch Credits for a Given Year (e.g., 2019)
WITH StateCredits AS (
  SELECT 
    b."State", 
    SUM(b.BranchCredits) AS TotalStateCredits
  FROM Branch b
  WHERE b."Year" = 2023
  GROUP BY b."State"
)
SELECT 
  "State", 
  TotalStateCredits,
  RANK() OVER (ORDER BY TotalStateCredits DESC) AS StateRank
FROM StateCredits;


--12 Regulator Penalty Aggregation for a Specific Year

SELECT 
  r.RegulatorID, 
  r.RegulatorName, 
  COUNT(p.PenaltyID) AS PenaltyCount,
  SUM(p.Amount) AS TotalPenalties
FROM Regulator r
JOIN Penalty p ON r.RegulatorID = p.RegulatorID
WHERE EXTRACT(YEAR FROM p.StartDate) = 2020
GROUP BY r.RegulatorID, r.RegulatorName
ORDER BY TotalPenalties DESC;

--13 total gases and carbon equivalent for certain industry type in 5year
SELECT 
    c.IndustryType,
    ce.GasName,
    SUM(ce.EquivalentTonnes) AS TotalCarbonEquivalent
FROM CompanyEmission ce
JOIN Company c ON ce.RegNo = c.RegNo
JOIN GreenhouseGases g ON ce.GasName = g.GasName
WHERE c.IndustryType = 'Energy Industry'
  AND ce.EmissionYear BETWEEN EXTRACT(YEAR FROM CURRENT_DATE)::INT - 4 AND EXTRACT(YEAR FROM CURRENT_DATE)::INT
GROUP BY c.IndustryType, ce.GasName
ORDER BY TotalCarbonEquivalent DESC;


--14 to see what companyType has received the most rewards and what rewards it got
SELECT 
  c.cType,
  r.RewardID,
  r.RewardType,
  r.RewardDescription,
  r.RewardIssueDate,
  COUNT(*) AS RewardCount
FROM Company c
JOIN CompanyConditions cc ON c.RegNo = cc.RegNo
JOIN Conditions co ON cc.ConditionID = co.ConditionID
JOIN Reward r ON co.RewardID = r.RewardID
WHERE cc."Year" BETWEEN EXTRACT(YEAR FROM CURRENT_DATE)::INT - 4 
                     AND EXTRACT(YEAR FROM CURRENT_DATE)::INT
GROUP BY c.cType, r.RewardID, r.RewardType, r.RewardDescription, r.RewardIssueDate
ORDER BY c.cType, RewardCount DESC;


--15 This query provides a descending order based on the average late penalty paid by each company across all years, with companies that have not paid any late penalties showing an average of 0 at the bottom.
WITH YearRange AS (
  -- Generate years from 2016 to the current year
  SELECT generate_series(2016, EXTRACT(YEAR FROM CURRENT_DATE)::INT) AS yr
),
CompanyYear AS (
  -- Create a record for each company for each year in the range
  SELECT 
    c.RegNo, 
    c.CompanyName, 
    yr.yr AS "Year"
  FROM Company c
  CROSS JOIN YearRange yr
)
SELECT 
  cy.RegNo,
  cy.CompanyName,
  cy."Year",
  COALESCE(SUM(CASE WHEN p.PayDate > p.StartDate THEN p.Amount ELSE 0 END), 0) AS TotalLatePenalty,
  COALESCE(AVG(CASE WHEN p.PayDate > p.StartDate THEN (p.PayDate - p.StartDate) END), 0) AS AverageDelay
FROM CompanyYear cy
JOIN Penalty p 
  ON cy.RegNo = p.RegNo 
  AND EXTRACT(YEAR FROM p.StartDate)::INT = cy."Year"
GROUP BY cy.RegNo, cy.CompanyName, cy."Year"
ORDER BY 
  CASE WHEN COALESCE(SUM(CASE WHEN p.PayDate > p.StartDate THEN p.Amount ELSE 0 END), 0) = 0 THEN 1 ELSE 0 END,
  COALESCE(SUM(CASE WHEN p.PayDate > p.StartDate THEN p.Amount ELSE 0 END), 0) DESC,
  cy.CompanyName;



-- 16. Find the average credits allocated per company type for the last 3 years.  
SELECT CT.CompanyType, TRUNC(AVG(CR.CAllocated),2) AS AverageCreditsAllocated  
FROM CompanyType CT  
JOIN Company C ON CT.CompanyType = C.CType  
JOIN Credit CR ON C.RegNo = CR.RegNo  
WHERE CR.CreditAllocatedYear BETWEEN EXTRACT(YEAR FROM CURRENT_DATE) - 3 AND EXTRACT(YEAR FROM CURRENT_DATE)  
GROUP BY CT.CompanyType;  

-- 17. Find the total credits traded per state in the last year.  
SELECT B."State", SUM(T.CreditsTraded) AS TotalCreditsTraded  
FROM "Transaction" T  
JOIN Company C ON T.SellerRegNo = C.RegNo  
JOIN Branch B ON C.RegNo = B.RegNo  
WHERE EXTRACT(YEAR FROM T.TDate) = EXTRACT(YEAR FROM CURRENT_DATE) - 1  
GROUP BY B."State";  

-- 18. Find companies that have the highest number of active projects in the last 3 years.  
WITH ActiveProjects AS (  
    SELECT RegNo, COUNT(ProjectID) AS ActiveProjectCount  
    FROM Project  
    WHERE "Status" = 'Active' AND StartDate >= CURRENT_DATE - INTERVAL '3 years'  
    GROUP BY RegNo  
)  
SELECT C.CompanyName, AP.ActiveProjectCount  
FROM ActiveProjects AP  
JOIN Company C ON AP.RegNo = C.RegNo  
ORDER BY AP.ActiveProjectCount DESC  
LIMIT 5;  

-- 19. Count policies per regulator. 
SELECT R.RegulatorName, COUNT(P.PolicyID) AS PolicyCount  
FROM Regulator R  
LEFT JOIN Regulation P ON R.RegulatorID = P.RegulatorID  
GROUP BY R.RegulatorName;  

-- 20. POCs managing multi-state branches.  
SELECT P.FullName,P.POCID,COUNT(DISTINCT B."State") AS StateCount  
FROM POCs P  
JOIN Branch B ON P.POCID = B.POCID  
GROUP BY (P.FullName,P.POCID)  
HAVING COUNT(DISTINCT B."State") > 1; 


-- 21. All transactions in a particular Year  
SELECT T.TransactionID, C1.CompanyName AS Seller, C2.CompanyName AS Buyer  
FROM "Transaction" T  
JOIN Company C1 ON T.SellerRegNo = C1.RegNo  
JOIN Company C2 ON T.BuyerRegNo = C2.RegNo  
WHERE EXTRACT(YEAR FROM T.TDate) = 2023; 

-- 22. Companies meeting Condition C00001 (2023).  
SELECT 
    CC.ConditionID,
    CC."Year",
    CC.RegNo,
    C.CompanyName,
    C.CType,
    C."Address"
FROM CompanyConditions CC
JOIN Company C ON CC.RegNo = C.RegNo
WHERE CC.ConditionID = 'C00008' AND CC."Year" = 2017;


-- 23. Regulators with most rewards + penalties.  
WITH RegulatorActivity AS (  
    SELECT R.RegulatorID, COUNT(DISTINCT W.RewardID) AS TotalRewards, COUNT(DISTINCT P.PenaltyID) AS TotalPenalties,COALESCE(SUM(P.Amount), 0) AS TotalPenaltyAmount 
    FROM Regulator R  
    LEFT JOIN Reward W ON R.RegulatorID = W.RegulatorID  
    LEFT JOIN Penalty P ON R.RegulatorID = P.RegulatorID  
    GROUP BY R.RegulatorID  
)
SELECT R.RegulatorName, RA.TotalRewards, RA.TotalPenalties,RA.TotalPenaltyAmount  
FROM RegulatorActivity RA  
JOIN Regulator R ON RA.RegulatorID = R.RegulatorID  
ORDER BY (RA.TotalRewards + RA.TotalPenalties) DESC;


-- 24. Highest net credit balance (5 years) top 5 companies.  
WITH NetCredits AS (  
    SELECT RegNo, SUM(CProduced - COALESCE(CSell, 0)+COALESCE(CBuy, 0)+COALESCE(CNgo, 0)) AS NetCreditBalance  
    FROM Credit  
    WHERE CreditAllocatedYear BETWEEN EXTRACT(YEAR FROM CURRENT_DATE) - 5 AND EXTRACT(YEAR FROM CURRENT_DATE)  
    GROUP BY RegNo  
)  

SELECT C.CompanyName, C.Ctype,NC.NetCreditBalance  
FROM NetCredits NC  
JOIN Company C ON NC.RegNo = C.RegNo  
ORDER BY NC.NetCreditBalance DESC LIMIT 5;

--25 Ranks Regulator based on their participation
WITH RegulatorActivity AS (
    SELECT 
        R.RegulatorID, 
        COUNT(DISTINCT W.RewardID) AS TotalRewards,
        COUNT(DISTINCT P.PenaltyID) AS TotalPenalties,
        COALESCE(SUM(P.Amount), 0) AS TotalPenaltyAmount
    FROM Regulator R
    LEFT JOIN Reward W ON R.RegulatorID = W.RegulatorID
    LEFT JOIN Penalty P ON R.RegulatorID = P.RegulatorID
    GROUP BY R.RegulatorID
),
RegulatorCredits AS (
    SELECT 
        RegulatorID,
        COUNT(*) AS RegulatorCredits
    FROM Credit
    GROUP BY RegulatorID
),
PenaltyTotals AS (
    SELECT SUM(RA.TotalPenaltyAmount) AS OverallPenaltyAmount
    FROM RegulatorActivity RA
),
RankedRegulators AS (
    SELECT 
        R.RegulatorName,
        RA.TotalRewards,
        RA.TotalPenalties,
        COALESCE(RC.RegulatorCredits, 0) AS RegulatorCredits,
        RA.TotalPenaltyAmount,
        ROUND((RA.TotalPenaltyAmount / NULLIF(PT.OverallPenaltyAmount, 0)) * 100, 2) AS PenaltyContributionPercent,
        
        -- New Activity Metric with Credits included
        (RA.TotalRewards + RA.TotalPenalties + COALESCE(RC.RegulatorCredits, 0)) AS TotalActivity,

        -- Updated ActivityCategory based on new TotalActivity
        CASE
            WHEN (RA.TotalRewards + RA.TotalPenalties + COALESCE(RC.RegulatorCredits, 0)) >= 25 THEN 'Highly Active'
            WHEN (RA.TotalRewards + RA.TotalPenalties + COALESCE(RC.RegulatorCredits, 0)) >= 20 THEN 'Moderate'
            ELSE 'Low'
        END AS ActivityCategory,

        -- Updated Rank based on new TotalActivity
        RANK() OVER (ORDER BY (RA.TotalRewards + RA.TotalPenalties + COALESCE(RC.RegulatorCredits, 0)) DESC) AS ActivityRank

    FROM RegulatorActivity RA
    JOIN Regulator R ON RA.RegulatorID = R.RegulatorID
    LEFT JOIN RegulatorCredits RC ON RA.RegulatorID = RC.RegulatorID
    CROSS JOIN PenaltyTotals PT
)

SELECT *
FROM RankedRegulators
ORDER BY ActivityRank;
