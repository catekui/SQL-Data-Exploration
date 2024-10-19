--Select data that we are going to be using

Select Location, date, total_cases,new_cases, total_deaths, population
from PORTFOLIO..CovidDeaths
order by 1, 2


--Looking ar Total Cases Vs Total Dealths
--Shows likelihood of dying if you contract COVID in your country
Select Location, date, total_cases,total_deaths,  (CAST(total_deaths AS FLOAT) / NULLIF(CAST(total_cases AS FLOAT), 0)) * 100 AS DeathPercentage
from PORTFOLIO..CovidDeaths
where location like '%kenya%'
order by 1, 2


-- Looking at the total cases Vs Population
Select Location, date, total_cases, population, (CAST(population AS FLOAT) / NULLIF(CAST(total_cases AS FLOAT), 0)) * 100 AS DeathPercentage
from PORTFOLIO..CovidDeaths
where location like '%kenya%'
and continent is not null
order by 1, 2


--Looking at Countries with Highest Infection rate compared to Population
Select Location, population, MAX(total_cases) as HighestInfectionCount, MAX((CAST(total_cases AS FLOAT) / NULLIF(CAST(population AS FLOAT), 0))) * 100 AS PercentPopulationInfected
from PORTFOLIO..CovidDeaths
--where location like '%kenya%'
Group by location, Population
order by PercentPopulationInfected desc


--showing Countries with Highest Death Count per Population
Select Location, MAX(cast(total_deaths as int)) as TotalDeathCount
from PORTFOLIO..CovidDeaths
--where location like '%kenya%'
where continent is not null
Group by location
order by TotalDeathCount desc

--Items by continent
Select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
from PORTFOLIO..CovidDeaths
--where location like '%kenya%'
where continent is not null
Group by continent
order by TotalDeathCount desc

select location, MAX(cast(total_deaths as int)) as TotalDeathCount
from PORTFOLIO..CovidDeaths
--where location like '%kenya%'
where continent is not null
Group by location
order by TotalDeathCount desc


--showing continents with highest death counts
select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
from PORTFOLIO..CovidDeaths
--where location like '%kenya%'
where continent is not null
Group by continent
order by TotalDeathCount desc


--Global Numbers
SELECT 
    SUM(CAST(new_cases AS INT)) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths, 
    (SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(CAST(new_cases AS INT)), 0)) * 100 AS DeathPercentage
FROM Portfolio..CovidDeaths
WHERE continent IS NOT NULL 
ORDER BY total_cases, total_deaths




-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine

Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by 2,3


-- Using CTE to perform Calculation on Partition By in previous query
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        SUM(CAST(vac.new_vaccinations AS BIGINT)) AS New_Vaccinations,
        SUM(SUM(CAST(vac.new_vaccinations AS BIGINT))) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
    FROM 
        Portfolio..CovidDeaths dea
    JOIN 
        Portfolio..CovidVaccinations vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL 
    GROUP BY 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population
)
SELECT 
    Continent,
    Location,
    Date,
    Population,
    New_Vaccinations,
    RollingPeopleVaccinated,
    (CAST(RollingPeopleVaccinated AS FLOAT) / NULLIF(CAST(Population AS FLOAT), 0)) * 100 AS VaccinationPercentage
FROM 
    PopvsVac;



-- Using Temp Table to perform Calculation on Partition By in previous query
-- Drop the temporary table if it exists
DROP TABLE IF EXISTS #PercentPopulationVaccinated

-- Create the temporary table
CREATE TABLE #PercentPopulationVaccinated
(
    Continent nvarchar(255),
    Location nvarchar(255),
    Date datetime,
    Population numeric,
    New_vaccinations numeric,
    RollingPeopleVaccinated numeric
)

-- Insert data into the temporary table
INSERT INTO #PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    TRY_CONVERT(numeric, dea.population), 
    TRY_CONVERT(numeric, vac.new_vaccinations),
    SUM(TRY_CONVERT(numeric, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) as RollingPeopleVaccinated
FROM 
    Portfolio..CovidDeaths dea
JOIN 
    Portfolio..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE TRY_CONVERT(numeric, vac.new_vaccinations) IS NOT NULL
  AND TRY_CONVERT(numeric, dea.population) IS NOT NULL
--AND dea.continent IS NOT NULL 

-- Query the temporary table
SELECT *, 
    CASE 
        WHEN Population > 0 THEN (RollingPeopleVaccinated/Population)*100 
        ELSE NULL 
    END AS PercentVaccinated
FROM #PercentPopulationVaccinated


-- Creating View to store data for later visualizations

ALTER VIEW PercentPopulationVaccinated AS
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) as RollingPeopleVaccinated
FROM 
    Portfolio..CovidDeaths dea
JOIN 
    Portfolio..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;
GO