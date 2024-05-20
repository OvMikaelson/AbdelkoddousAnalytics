--in this project we'll be using the dataset we scraped on a previous project from the international directory of
--supplying companies of bio organic food
select * from companies

--before we even start anything let's delete duplicates from this table as it will compromise our results later
delete sub_com from
(SELECT ROW_NUMBER() OVER (PARTITION BY category, Company_Name, phone order by category) cnt from companies) sub_com
where sub_com.cnt>1

--At first glance we can think of a few insights we can get from this data as well as some functions
--we can build to get specific data using one or 2 delimiters

--But first we need to clean the column City which seems to have some unnecessary string in some rows
update companies
set city = trim(replace(city,'show on map',''))
where city like '%show on map%'

--let's get an overview of how many companies we have for every category before we dive deeper into this data
select category, count(category) num_of_supplying_companies from companies
group by category
order by category

--we'll start with something easy like getting the top 5 supplying cities of bio organic food
select top 5 City, count(city) number_of_supplying_companies
from (select company_name, city from companies group by company_name, city) counting_companies
group by City
order by count(city) desc, city 

--next let's see if there are any multinational companies, operating under the same name but in more than
--one country
select Company_Name, count(company_name) number_of_countries from (
select company_name, country from companies
group by Company_Name,country
) counting_companies
group by Company_Name
having count(company_name) > 1

--now let's dive deeper, let's build some practical procedures to query useful information from later

--we'll start with a procedure that, when provided a category and a country, can return a list of the available
--companies there
create procedure available_within @countryX varchar(50), @categoryX varchar(50) as 
select * from companies
where category = @categoryX
and country = @countryX

Exec available_within @categoryX = 'baby food', @countryX = 'sweden' 

--But what if, a certain category doesn't have any supplying company in a given country...
--we'll build a function that returns a list of ccompanies that have EXPORT in their services
create procedure available_beyond @countryX varchar(50), @categoryX varchar(50) as
select * from companies
where category = @categoryX
	  and country != @countryX
	  and Services like '%export%'

Exec available_beyond @categoryX = 'baby food', @countryX = 'morocco'

--to finish, we'll build a procedure that returns the percentage of companies from a given country in each of
-- the categories
create procedure country_percentage @countryX varchar(50) as
with category_count as
(
select category, count(category) total_companies from companies
group by category
),
country_count as
(
select category, count(country) count_of_companies
from companies
group by category, country
having country = @countryX
)
select category_count.category, round((cast(country_count.count_of_companies as float)/cast(category_count.total_companies as float))*100,2) peercentage_of_X_companies
from country_count full join category_count on country_count.category = category_count.category
order by category_count.category

exec country_percentage @countryX = 'Brazil'
