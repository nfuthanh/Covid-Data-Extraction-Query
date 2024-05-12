USE PortfolioProject
GO

-- DATA EXPLORATION
SELECT * 
FROM PortfolioProject.dbo.CovidDeaths
order by 3,4
GO

SELECT * 
FROM PortfolioProject.dbo.CovidVaccination
order by 3,4
GO

-- 1. TOTAL CASES VS POPULATION
---- Total percentage in Vietnam
SELECT	location, 
		date, 
		total_cases, 
		population,
		ROUND((cast(total_cases as float)/(cast(population as float)))*100,5) as Infected_rate
FROM PortfolioProject.dbo.CovidDeaths
WHERE location like '%viet%'
ORDER BY 1,2
GO

-- 2. TOTAL CASES VS TOTAL DEATHS
---- Daily death rate in Vietnam
SELECT location, date, 
	   CASE
			WHEN SUM(CAST(total_cases AS INT)) IS NULL THEN 0
			ELSE SUM(CAST(total_cases AS INT)) 
	   END AS total_cases,
	   CASE
			WHEN SUM(CAST(total_deaths AS INT)) IS NULL THEN 0
			ELSE SUM(CAST(total_deaths AS INT))
	   END AS total_deaths,
	   CASE 
			WHEN SUM(CAST(total_deaths AS FLOAT)) IS NULL THEN 0
			ELSE ROUND(SUM(CAST(total_deaths AS FLOAT))/SUM(CAST(total_cases AS FLOAT)),5)*100
	   END AS death_rate
FROM PortfolioProject.dbo.CovidDeaths
WHERE location like '%viet%'
GROUP BY location, date
ORDER BY 1,2
GO


-- 3. RANKINGS
---- TOP 10 countries with highest infection rate compared to population before 2021-04-30
SELECT TOP(10)	location,
				Population, 
				MAX(CAST(total_cases AS float)) AS HighestInfectionCount, 
				ROUND(MAX(CAST(total_cases AS float))/CAST(population as float),4)*100 AS InfectionRate
FROM PortfolioProject.dbo.CovidDeaths
WHERE date < '2021-04-30'
GROUP BY location, population
ORDER BY InfectionRate DESC
GO


-- 4. MEDIAN DEATH COUNTS 
---- Find the max death count median over the world (final input)
WITH total_death AS(
	SELECT	continent, 
			location, 
			MAX(CAST(total_deaths AS float)) as final_death_count 
	FROM PortfolioProject.dbo.CovidDeaths
	WHERE continent IS NOT NULL AND total_deaths IS NOT NULL
	GROUP BY continent, location
)

SELECT CAST(
	(SELECT MIN(final_death_count) FROM (SELECT TOP(50) PERCENT final_death_count FROM total_death ORDER BY final_death_count DESC) as Upperlim)+
	(SELECT MAX(final_death_count) FROM (SELECT TOP(50) PERCENT final_death_count FROM total_death ORDER BY final_death_count ASC) as Lowerlim) AS FLOAT) AS MEDIAN_DEATH_COUNTS
GO

-- 5. VACCINATION ROLLING COUNTS
SELECT	D.continent, 
		D.location, 
		D.date, 
		D.population, 
		V.new_vaccinations,
		SUM(CAST(V.new_vaccinations AS BIGINT)) OVER (PARTITION BY D.location ORDER BY D.date) AS VaccinationRollingCounts,
		ROUND(SUM(CAST(V.new_vaccinations AS BIGINT)) OVER (PARTITION BY D.location ORDER BY D.date)/CAST(D.population AS FLOAT)*100,3) AS VaccinatedRate
FROM CovidDeaths D
LEFT JOIN CovidVaccination V ON D.location = V.location AND D.date = V.date
WHERE V.new_vaccinations IS NOT NULL AND D.continent IS NOT NULL
GO


-- 6. Vacinated Rate and Infected Rate in 1 month after the national outbreak
DROP TABLE IF EXISTS VacinatedRate 
CREATE TABLE VacinatedRate
(
	Continent VARCHAR(255),
	Country VARCHAR(255),
	Date DATE,
	Population BIGINT,
	new_cases INT,
	Vaccinated_rate FLOAT
)

INSERT INTO VacinatedRate
SELECT	D.continent, 
		D.location, 
		D.date, 
		CAST(D.population AS BIGINT),
		CAST(D.new_cases AS INT),
		ROUND(SUM(CAST(V.new_vaccinations AS BIGINT)) OVER (PARTITION BY D.location ORDER BY D.date)/CAST(D.population AS FLOAT)*100,3)
FROM CovidDeaths D
LEFT JOIN CovidVaccination V ON D.location = V.location AND D.date = V.date
WHERE V.new_vaccinations IS NOT NULL AND D.continent IS NOT NULL
GO

WITH Final_date AS
(
		SELECT	Country,
				DATEADD(day,30,MIN(Date)) AS Last_date
		FROM VacinatedRate
		GROUP BY Country
)

SELECT	V.Country, 
		V.Population, 
		SUM(V.new_cases) AS total_cases_in_first_month,
		MIN(V.Date) AS Outbreak_startdate, 
		MAX(V.Date) AS LastVaccination_date,
		COUNT(*) AS Total_Vaccine_Injection_dates,
		MAX(V.Vaccinated_rate) as VaccinatedPopulation_Rate,
		ROUND(SUM(V.new_cases)/CAST(V.Population AS FLOAT)*100,3) AS InfectedRate
FROM VacinatedRate V
INNER JOIN Final_date F ON V.Date < F.Last_date AND V.Country = F.Country
GROUP BY V.Country, V.Population
HAVING COUNT(*)>1
ORDER BY V.Country

GO

-- 7. Save the last query into a view for further visualization
CREATE VIEW First30Days AS
WITH Final_date AS
(
		SELECT	Country,
				DATEADD(day,30,MIN(Date)) AS Last_date
		FROM VacinatedRate
		GROUP BY Country
)

SELECT	V.Country, 
		V.Population, 
		SUM(V.new_cases) AS total_cases_in_first_month,
		MIN(V.Date) AS Outbreak_startdate, 
		MAX(V.Date) AS LastVaccination_date,
		COUNT(*) AS Total_Vaccine_Injection_dates,
		MAX(V.Vaccinated_rate) as VaccinatedPopulation_Rate,
		ROUND(SUM(V.new_cases)/CAST(V.Population AS FLOAT)*100,3) AS InfectedRate
FROM VacinatedRate V
INNER JOIN Final_date F ON V.Date < F.Last_date AND V.Country = F.Country
GROUP BY V.Country, V.Population
HAVING COUNT(*)>1
