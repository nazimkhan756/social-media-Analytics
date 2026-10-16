use fedex_logistics;
-- Task 1 Data cleaning & Preparation

-- Find the Duplicate order IDs --
select order_id, count(*) from orders group by order_id having count(*) > 1;

-- Find the Duplicat Shipment IDs --
select Shipment_id, count(*) from Shipments group by Shipment_id having count(*) > 1;

-- Find the Null Delay_Hours --
select * from Shipments where Delay_Hours is null;

-- Replace the Null Delay_Hours with Average Delay --

UPDATE Shipments s
JOIN (
    SELECT Route_ID,
           AVG(Delay_Hours) AS Avg_Delay
    FROM Shipments
    WHERE Delay_Hours IS NOT NULL
    GROUP BY Route_ID
) r
ON s.Route_ID = r.Route_ID
SET s.Delay_Hours = r.Avg_Delay
WHERE s.Delay_Hours IS NULL;

-- Format the order date --
SELECT DATE_FORMAT(Order_Date,'%Y-%m-%d %H:%i:%s') FROM Orders;

-- Format pickup and Delivery Dates--

select Date_Format(Pickup_Date,'%Y-%m-%d %H:%i:%s'), Date_Format(Delivery_Date, '%Y-%m-%d %H:%i:%s') from Shipments;

-- Check the Invalid Dates --

select * from shipments where Delivery_Date < Pickup_Date;


-- Check the missing Routs IDs --

select * from Orders where Route_id not in ( select Route_id from Routes );

-- Check the missing Warehouse IDs --

select * from orders where warehouse_id not in ( select warehouse_id from warehouses );

-- TASK 2  Delivery Delay Analysis --

-- 1. Calculate Delivery Delay (Hours) for each Shipment --

select Shipment_ID, TIMESTAMPDIFF(Hour, Pickup_date, Delivery_Date) as Delay_housr from Shipments;

-- Find the Top 10 delayed routes based on average delay hours --


SELECT Route_ID, AVG(Delay_Hours) AS Avg_Delay_Hours FROM Shipments  GROUP BY Route_ID ORDER BY Avg_Delay_Hours DESC Limit 10;

-- Rank shipment by delay within each Warehouse_ID --

SELECT Shipment_ID, Warehouse_ID,  Delay_Hours, RANK() OVER ( PARTITION BY Warehouse_ID ORDER BY Delay_Hours DESC )
 AS Delay_Rank FROM Shipments;
 
 -- Average delay per Delivery Type (Express/Standard) --
 
 select o.Delivery_Type, Avg(s.Delay_hours) as Avg_Delay_Hours from orders o join Shipments s on o.Order_Id = s.Order_id group by o.Delivery_Type;
 
 -- TASK 3 Route Optimization Insights --
 
 -- Average transit time (in hours) across all Shipments for each route --
 
 SELECT Route_ID,
       AVG(TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date)) AS Avg_Transit_Time_Hours
FROM Shipments
GROUP BY Route_ID;

-- Average delay (in hours) per route --

SELECT Route_ID,
       AVG(Delay_Hours) AS Avg_Delay_Hours
FROM Shipments
GROUP BY Route_ID;

-- Distance-to-Time Efficiency Ratio --

SELECT Route_ID,
       Distance_KM,
       Avg_Transit_Time_Hours,
       ROUND(Distance_KM / Avg_Transit_Time_Hours, 2) AS Efficiency_Ratio
FROM Routes;

-- Identify 3 routes with the worst efficiency ratio --

SELECT Route_ID,
       Distance_KM,
       Avg_Transit_Time_Hours,
       ROUND(Distance_KM / Avg_Transit_Time_Hours, 2) AS Efficiency_Ratio
FROM Routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

-- Routes with more than 20% shipments delayed beyond expected transit time --

 SELECT s.Route_ID, ROUND(SUM( CASE WHEN TIMESTAMPDIFF(HOUR,s.Pickup_Date,  s.Delivery_Date)> r.Avg_Transit_Time_Hours
     > r.Avg_Transit_Time_Hours  THEN 1 ELSE 0 END ) * 100.0 / COUNT(*), 2 ) AS Delay_Percentage FROM Shipments s JOIN Routes r
     ON s.Route_ID = r.Route_ID GROUP BY s.Route_ID HAVING Delay_Percentage > 20;
     
     -- Routes/Hub Pairs Recommended for Optimization --
     
    SELECT s.Route_ID, AVG(s.Delay_Hours) AS Avg_Delay, ROUND(SUM(  CASE WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)
      > r.Avg_Transit_Time_Hours  THEN 1 ELSE 0 END   ) * 100.0 / COUNT(*), 2 ) AS Delay_Percentage FROM Shipments s JOIN Routes r
      ON s.Route_ID = r.Route_ID GROUP BY s.Route_ID ORDER BY Avg_Delay DESC;
    
    
    -- TASK 4 : Warehouses Performance --
    
    -- Find the Top 3 Warehouses with Highest Average Delay --
    
    select Warehouse_id, Avg(Delay_Hours) as Avg_Delay from Shipments group by Warehouse_id order by Avg_Delay desc Limit 3;
    
    -- Find the total Shipments vs Delayed Shipments for each Warehouse --
    
    select Warehouse_id, count(*) as total_Shipments, sum(case when Delay_Hours > 0 then 1 else 0 end ) as Delayed_Shipments from Shipments
    group by Warehouse_id;
    
    -- Find the warehouses where average delay exceeds global average delay (using CTE) --
    
    with global_avg as (select avg(delay_hours) as global_delay from shipments ) select s.warehouse_id, avg(s.delay_hours) as 
    warehouse_avg_delay from shipments s cross join global_avg g group by s.warehouse_id having avg(s.delay_hours) > g.global_delay;

WITH Global_Avg AS (
    SELECT AVG(Delay_Hours) AS Global_Delay
    FROM Shipments
)
SELECT s.Warehouse_ID,
       AVG(s.Delay_Hours) AS Warehouse_Avg_Delay
FROM Shipments s
CROSS JOIN Global_Avg g
GROUP BY s.Warehouse_ID
HAVING AVG(s.Delay_Hours) >
       (SELECT Global_Delay FROM Global_Avg);
       
       -- Find the Rank Warehouses Based on On-Time Delivery Percentage --
       
  SELECT Warehouse_ID,  ROUND( SUM(CASE  WHEN Delay_Hours <= 0 THEN 1  ELSE 0 END) * 100.0 / COUNT(*),  2 ) AS On_Time_Percentage,
   RANK() OVER (  ORDER BY ROUND( SUM(CASE WHEN Delay_Hours <= 0 THEN 1 ELSE 0   END) * 100.0 / COUNT(*),  2 ) DESC ) AS Warehouse_Rank
   FROM Shipments GROUP BY Warehouse_ID; 
   
   -- TASK 5 : Delivery Agent Performance --
   
   -- Find the Rank delivery agents (Per Routes) by on-time delivery percentage --
   
   SELECT
    s.Route_ID,
    s.Agent_ID,
    ROUND(
        SUM(CASE WHEN s.Delay_Hours <= 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS On_Time_Percentage,
    RANK() OVER (
        PARTITION BY s.Route_ID
        ORDER BY
        ROUND(
            SUM(CASE WHEN s.Delay_Hours <= 0 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*), 2
        ) DESC
    ) AS Agent_Rank
FROM Shipments s
GROUP BY s.Route_ID, s.Agent_ID;

-- Find the Agents whose on-time % is bleow 85% --

SELECT
    s.Agent_ID,
    a.Agent_Name,
    ROUND(
        SUM(CASE WHEN s.Delay_Hours <= 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS On_Time_Percentage
FROM Shipments s
JOIN Delivery_Agents a
ON s.Agent_ID = a.Agent_ID
GROUP BY s.Agent_ID, a.Agent_Name
HAVING On_Time_Percentage < 85;


-- Find the Compare average rating & experience of top 5 vs bottom 5 agents --


WITH Agent_Performance AS (
    SELECT
        a.Agent_ID,
        a.Agent_Name,
        a.Avg_Rating,
        a.Experience_Years,
        ROUND(
            SUM(CASE WHEN s.Delay_Hours <= 0 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*), 2
        ) AS On_Time_Percentage
    FROM Delivery_Agents a
    JOIN Shipments s
    ON a.Agent_ID = s.Agent_ID
    GROUP BY a.Agent_ID, a.Agent_Name,
             a.Avg_Rating, a.Experience_Years
)
SELECT 'Top 5 Agents' AS Category,
       AVG(Avg_Rating) AS Avg_Rating,
       AVG(Experience_Years) AS Avg_Experience
FROM (
    SELECT *
    FROM Agent_Performance
    ORDER BY On_Time_Percentage DESC
    LIMIT 5
) t

UNION ALL

SELECT 'Bottom 5 Agents' AS Category,
       AVG(Avg_Rating),
       AVG(Experience_Years)
FROM (
    SELECT *
    FROM Agent_Performance
    ORDER BY On_Time_Percentage ASC
    LIMIT 5
) b;

  -- TASK 6 : Shipments Tracking Analytics --
  
  -- Find the Display the latest status and latest Delivery_Date of each shipment --
  
  select Shipment_id, delivery_status, delivery_date from Shipments;
  
  -- Find the Routes where the majority of shipments are "In Tansit" or "Retuned" --
  
  select route_id, delivery_status, count(*) as total_shipments from shipments where delivery_status in ('In Transit','Returned')
  group by route_id, delivery_status order by total_shipments desc;
  
    -- Find the most frequent delay reasons --
    
    select delay_reason, count(*) as frequency from shipments group by delay_reason order by frequency desc;
    
     -- Find the Order with exceptionly high delay (.120 hours)  --
     
     select shipment_id, order_id, route_id, warehouse_id, agent_id, delay_hours from shipments where delay_hours > 120 
     order by delay_hours desc;   
     
     -- TASK 7 : Advanced KPI Reporting --
     
     -- Average delivery delay per source country --
     
     select r.source_country, Round(avg(s.delay_hours),2) as avg_delivery_delay from shipments s join Routes r On s.Route_id = r.Route_id 
     group by r.source_country order by avg_delivery_delay desc;   
     
     
     -- On-Time Delivery Percentage --
     
     
     SELECT
    COUNT(*) AS Total_Deliveries,
    SUM(CASE
            WHEN Delay_Hours = 0 THEN 1
            ELSE 0
        END) AS On_Time_Deliveries,
    ROUND(
        SUM(CASE
                WHEN Delay_Hours = 0 THEN 1
                ELSE 0
            END) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage
FROM Shipments;


-- Average delay per route_id --

select Route_id, round(avg(delay_hours),2) as Avg_delay_hours from Shipments group by Route_id  order by Avg_delay_hours desc;

-- Warehouse Utilizaton Percentage --

SELECT w.Warehouse_ID, w.City, w.Country, w.Capacity_per_day, COUNT(s.Shipment_ID) AS Shipments_Handled,ROUND(
  COUNT(s.Shipment_ID) * 100.0 /  w.Capacity_per_day,2  ) AS Warehouse_Utilization_Percentage FROM Warehouses w
           LEFT JOIN Shipments s ON w.Warehouse_ID = s.Warehouse_ID GROUP BY w.Warehouse_ID,
                     w.City, w.Country,  w.Capacity_per_day ORDER BY Warehouse_Utilization_Percentage DESC;
					
-- Combined KPI Summary Table --

CREATE TABLE KPI_Summary AS
SELECT
    s.Route_ID,  ROUND(AVG(s.Delay_Hours),2) AS Avg_Delay,  ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2) AS On_Time_Percentage FROM Shipments s  GROUP BY s.Route_ID;
        
        select * from KPI_Summary;
        


     
     
     
     
	
     



           














