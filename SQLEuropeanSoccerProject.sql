select * from match
-- at first glance at the match table, we see 4 columns: api IDs of the home and away teams
-- as well as how many goals they scored at that match
-- for display purposes we'll make a temp table having the short names of teams and the results
-- like u would see them on TV

Drop table if exists #match_results
select match_api_id, home_team_api_id, away_team_api_id, cast(home_team_goal as varchar) + ' - ' + cast(away_team_goal as varchar) as end_score into #match_results
from Match

ALTER TABLE #match_results
ADD home_team_short_name nvarchar(50), away_team_short_name nvarchar(50)
							
UPDATE #match_results
SET home_team_short_name = team_short_name
FROM #match_results
JOIN Team ON home_team_api_id = team_api_id

UPDATE #match_results
SET away_team_short_name = team_short_name
FROM #match_results
JOIN Team ON away_team_api_id = team_api_id

Drop table if exists #match_results_final
select match_api_id, home_team_api_id, home_team_short_name, away_team_api_id, away_team_short_name, home_team_short_name + ' - ' + away_team_short_name as teams, end_score into #match_results_final
from #match_results

select * from #match_results_final
-- now that we have this table we can go into more data exploration
-- first we'll try to see how every team performed (wins, losses, draws chronologically)
-- we'll try to test with one id, example: id = 10000

with performance as (
select match.match_api_id, #match_results_final.teams, #match_results_final.end_score
from Match join #match_results_final
on match.match_api_id = #match_results_final.match_api_id
where Match.home_team_api_id = 10000 or Match.away_team_api_id = 10000
)

select match.match_api_id, convert(date,match.date) match_date,  teams, end_score,
case
	when match.home_team_api_id = 10000 and SUBSTRING(performance.end_score,1,1) > SUBSTRING(performance.end_score,5,1) then 'Win'
	when match.home_team_api_id = 10000 and SUBSTRING(performance.end_score,1,1) < SUBSTRING(performance.end_score,5,1) then 'Loss'
	when match.away_team_api_id = 10000 and SUBSTRING(performance.end_score,1,1) > SUBSTRING(performance.end_score,5,1) then 'Loss'
	when match.away_team_api_id = 10000 and SUBSTRING(performance.end_score,1,1) < SUBSTRING(performance.end_score,5,1) then 'Win'
	else 'Draw'
end as conclusion
from performance join Match
on performance.match_api_id = match.match_api_id
order by match.date

-- let's use this to make a performance overview for all the teams (wins/losses/draws)
-- to do so, what we just did with the example id needs to become a procedure we can call for any id

create procedure performance_overview
@id nvarchar(50)
as
drop table if exists team_data;
with performance as (
select match.match_api_id, #match_results_final.teams, #match_results_final.end_score
from Match join #match_results_final
on match.match_api_id = #match_results_final.match_api_id
where Match.home_team_api_id = @id or Match.away_team_api_id = @id
)


select match.match_api_id, @id team_api_id, convert(date,match.date) match_date,  teams, end_score,
case
	when match.home_team_api_id = @id and SUBSTRING(performance.end_score,1,1) > SUBSTRING(performance.end_score,5,1) then 'Win'
	when match.home_team_api_id = @id and SUBSTRING(performance.end_score,1,1) < SUBSTRING(performance.end_score,5,1) then 'Loss'
	when match.away_team_api_id = @id and SUBSTRING(performance.end_score,1,1) > SUBSTRING(performance.end_score,5,1) then 'Loss'
	when match.away_team_api_id = @id and SUBSTRING(performance.end_score,1,1) < SUBSTRING(performance.end_score,5,1) then 'Win'
	else 'Draw'
end as conclusion into specific_disposable_team_data -- this table will keep changing
-- it's just a tool to query from, the only reason it's not made as temp table
-- is because we need to call it later into a function and temp tables can't be called into functions
from performance join Match
on performance.match_api_id = match.match_api_id
order by match.date

-- now if we wanna see the chronological performance of a certain team
-- all we'd need is the team's api ID
drop table if exists specific_disposable_team_data
exec performance_overview @id = 8571 --for example
select * from specific_disposable_team_data

-- and with that data being callable for any team id we want
-- we can integrate that into a function that will give us an overview of each team
create function team_overview
(@id2 nvarchar(50))
returns table
as
return
select team.team_api_id, team.team_long_name, team.team_short_name,
       cast(sum(case when specific_disposable_team_data.conclusion = 'Win' then 1 else 0 end) as varchar) + '_' +
       cast(sum(case when specific_disposable_team_data.conclusion = 'Loss' then 1 else 0 end) as varchar) + '_' +
       cast(sum(case when specific_disposable_team_data.conclusion = 'Draw' then 1 else 0 end) as varchar) Wins_Losses_Draws
from specific_disposable_team_data join Team
on team.team_api_id = specific_disposable_team_data.team_api_id
where team.team_api_id = @id2
group by team.team_api_id,team.team_long_name, team.team_short_name


-- then we can make a table and insert the individual team stats into it with a loop
drop table if exists all_teams_overview
create table all_teams_overview
(
team_api_id int,
team_long_name nvarchar(50),
team_short_name nvarchar(50),
Wins_Losses_Draws nvarchar(50)
)


declare @rowcount int = (select count(*) from Team), @x int
WHILE @rowcount > 0
BEGIN
select @x=team_api_id from team
ORDER BY team_api_id desc offset @rowcount - 1 ROWS FETCH NEXT 1 ROWS ONLY
drop table if exists specific_disposable_team_data
exec performance_overview @id = @x
insert into all_teams_overview
select * from team_overview(@x)
set @rowcount = @rowcount - 1
end


-- Then we can call our results while exclusding the teams that haven't participated
select * from all_teams_overview
where Wins_Losses_Draws <> '0_0_0'