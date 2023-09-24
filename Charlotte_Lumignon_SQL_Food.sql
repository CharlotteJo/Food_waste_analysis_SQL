--Progetto SQL - Food

--Introduction
--Food waste is a problem that affects every country in the world, especially the more developed ones,
--and that make even more unacceptable the malnutrition and the food insecurity that million of people have to face everyday.

--In this project I want to know which countries waste the most, what type of food is often loss and if over the years the situation got better.
--I will use the FAO dataset to try to answer to the following questions:
--1. Which are the countries that waste the most?
--2. Which are the 10 countries with the lowest average food loss percentage?
--3. What type of food is wasted in the biggest quantities? Let's see the top 10
--4. Did the quantity of wasted food change over the years?
--5. What about the supply chain? Which stage generates the biggest food loss?


--LOADING DATA
SELECT * FROM "food_loss"
LIMIT 10

--Every row is a record of a case of food loss, it's important to understand the meaning of every column:

--"m49_code" is a code that identify every country
--"country" tell us the name of the country where there has been a case of food loss
--"region" specify the region of the country 
--"cpc_code" is a code that identify the type of food that has been wasted
--"commodity" tell us the type of food
--"year" identify the year of the record. The dataset contains the records between 1966 and 2021
--"loss percentage" refers to the percentage of food loss indicated only with numbers 
--"loss_percentage_original" is the original data, including the percentage symbol
--"loss_quantity" indicates the quantity of food that has been wasted
--"activity" specify which activity generated a food loss
--"food_supply_stage" is the phase of the process that causes food waste
--"treatment" tell us details about the treatment used on the food
--"cause_of_loss" indicates the cause of the food loss
--"sample_size" tell us some characteristics of the choosen sample
--"method_data_collection" specify the method used to collect the data
--"refrence" indicates the reference source
--"url" is a link that show us more details about the data
--"notes" can contains notes about the record.


--DATA CLEANING 

--Question: Is the column region useful in my analysis?
SELECT region, COUNT(*)
FROM "food_loss"
GROUP BY region
ORDER BY COUNT(*) DESC
--I will not keep this column because there are too many null values and it will not be useful in my analysis.

--Question: Is the column cause_of_loss useful in my analysis?
SELECT cause_of_loss, COUNT(*)
FROM "food_loss"
GROUP BY cause_of_loss
HAVING COUNT(*)>2
ORDER BY COUNT(*) DESC;
--98% of the records are null values, and the main causes of loss are not well categorized so I will not keep this column.

--Question: Is the column loss_quantity useful in my analysis?
SELECT loss_quantity, COUNT(*)
FROM "food_loss"
GROUP BY loss_quantity
ORDER BY COUNT(*) DESC
--I will not keep this column because of the high number of null values and because the unit of measurement are not specified
--so it's not possible to compare different records.

--Question: Is the column treatment useful in my analysis?
SELECT treatment, COUNT(*)
FROM "food_loss"
GROUP BY treatment
ORDER BY COUNT(*) DESC
--I will delete this column because almost 99% of the values are null values.

--Question: Is the column sample_size useful in my analisys?
SELECT sample_size, COUNT(*)
FROM "food_loss"
GROUP BY sample_size
ORDER BY COUNT(*) DESC
--I will remove it because of the high number of null values and because the non null values are heterogeneous.

--I will also delete other columns that I consider useless:

ALTER TABLE "food_loss"
DROP COLUMN m49_code,
DROP COLUMN region,
DROP COLUMN cpc_code,
DROP COLUMN loss_quantity,
DROP COLUMN treatment,
DROP COLUMN cause_of_loss,
DROP COLUMN sample_size,
DROP COLUMN method_data_collection,
DROP COLUMN reference,
DROP COLUMN url,
DROP COLUMN notes

--Let's find and delete duplicate rows.
--To do this I need to be able to uniquely identify each record, so I will create a new column called "id" that contains the indexes of each record.
--I will import a column created in Excel with the list of integers from 1 to 32947.

ALTER TABLE IF EXISTS public.food_loss
    ADD COLUMN id integer;

WITH CTE AS (SELECT id,
		ROW_NUMBER() OVER(PARTITION BY country,
										commodity, year,
										loss_percentage,
										activity,
										food_supply_stage, ORDER BY id) AS duplicate_count
		FROM "food_loss")

DELETE FROM "food_loss"
WHERE id IN(SELECT id FROM CTE WHERE duplicate_count > 1)


SELECT DISTINCT country FROM "food_loss";
--Looking to the list of the different countries I can see that there are aggregations
--and also some continents. I choose to remove these aggregations to prevent inaccuracies.

DELETE FROM "food_loss"
WHERE country IN ('Africa', 'Australia and New Zealand', 'Central Asia', 'China,Taiwan',
				  'Europe', 'Latin America and the Caribbean', 'Northern Africa', 
				  'Northern America', 'South-Eastern Asia', 'Southern Asia',
				  'Sub-Saharan Africa', 'Western Africa', 'Western Asia')


--Let's explore the loss_percentage column. I want to know the average loss percentage, the minimum and the maximum:
SELECT AVG(loss_percentage),
MIN(loss_percentage),
MAX (loss_percentage)
FROM "food_loss";
--I can see that there is a problem with the max of the loss percentage.

SELECT loss_percentage, loss_percentage_original FROM "food_loss"
ORDER BY loss_percentage DESC;

--The highest 8 values in the loss_percentage column are higher than 100, 
--but the column loss_percentage_original indicates a percentage lower than 100%
--that suggest that there has been a transcription mistake.
--I will then replace these 8 values:
UPDATE "food_loss" SET loss_percentage = 0.995 WHERE loss_percentage = 995;
UPDATE "food_loss" SET loss_percentage = 0.875 WHERE loss_percentage = 875;
UPDATE "food_loss" SET loss_percentage = 61.5 WHERE loss_percentage = 615;
UPDATE "food_loss" SET loss_percentage = 0.495 WHERE loss_percentage = 495;
UPDATE "food_loss" SET loss_percentage = 39.5 WHERE loss_percentage = 395;
UPDATE "food_loss" SET loss_percentage = 0.135 WHERE loss_percentage = 135;
UPDATE "food_loss" SET loss_percentage = 0.105 WHERE loss_percentage = 105;

--I can not find the correct percentage for the 179 value from loss_percentage_original column,
--I choose to replace 179 with a null value to prevent errors in future analysis.
UPDATE "food_loss" SET loss_percentage = NULL WHERE loss_percentage = 179;

--Now the average value is 5.13%, the minimum is 0.009% and the maximum is 65%.


--DATA ANALYSIS

--1. Question: Which are the countries that waste the most?
--I want to know the top 10 of the countries with the highest average percentage of food loss.
SELECT country, ROUND(AVG(loss_percentage),2) AS "avg_loss"
FROM "food_loss"
GROUP BY country
ORDER BY avg_loss DESC
LIMIT 10;

--At the first place we find Haiti, let's find out what type of food is the one wasted
--and in which years.
SELECT country, commodity, year, loss_percentage
FROM "food_loss"
WHERE country = 'Haiti'

--There are only 3 records about food loss in Haiti, it's pretty unlikely that in the last 55 years
--in the entire island food has been wasted only 3 times, and every time it was mangoes, guavas and mangosteens.
--I suppose that some records are missing, maybe due to the political instability or a lack of interest for food waste. 
--I choose then to consider only the countries that have a significant number of records across the years, let's say at least 100 records.

SELECT country, ROUND(AVG(loss_percentage),2) AS "avg_loss", COUNT(*)
FROM "food_loss"
GROUP BY country
HAVING COUNT(*)>=100
ORDER BY avg_loss DESC;

SELECT country, commodity, year, loss_percentage
FROM "food_loss"
WHERE country = 'Peru';

--Now in the case of Peru there are 767 records about food loss, and different categories of food, so I consider this data more reliable.
--Anyway, I suppose that there are other countries with missing records, due to wars, political situation, lack of communication with the rest of the world etc
--I should therefore prefer to analyze the food loss situation in each continent to have a more representive result.
--I will use the ISTAT dataset to know to which continent belongs each country.

--Dataset exploration
SELECT * FROM "continents"
LIMIT 5;

SELECT DISTINCT "Denominazione Continente (IT)" FROM "continents"
--This dataset group all the countries of the world in 5 continents: Africa, Asia, America, Oceania, Europa.
--I choose to separate North America from South America and I will translate the continent's names in English.
ALTER TABLE "continents" RENAME COLUMN "Denominazione Continente (IT)" TO Continent
UPDATE "continents" SET Continent = CASE 
			WHEN "Denominazione Area (IT)" IN ('Europa','Altri paesi europei','Altri Paesi europei','Europa centro orientale', 'Unione europea') THEN 'Europe'
			WHEN "Denominazione Area (IT)" IN ('Africa occidentale', 'Africa centro meridionale', 'Africa settentrionale', 'Africa orientale') THEN 'Africa'
			WHEN "Denominazione Area (IT)" = 'America settentrionale' THEN 'North America'
			WHEN "Denominazione Area (IT)" = 'America centro meridionale' THEN 'South America'
			WHEN "Denominazione Area (IT)" IN ('Asia orientale', 'Asia occidentale', 'Asia centro meridionale') THEN 'Asia'
			WHEN "Denominazione Area (IT)" = 'Oceania' THEN 'Oceania'
END

--Now let's see what is the average food loss percentage in each continent.
SELECT c.continent, ROUND(AVG(f.loss_percentage),2) AS "avg_loss"
FROM "food_loss" AS f JOIN "continents" AS c
ON f.country = c."Denominazione EN"
GROUP BY c.continent
ORDER BY avg_loss DESC

--South America is the continent with the highest percentage (13,19%), while Africa seems to be the one that waste the less, on average.

--2. Question: Which are the 10 countries with the lowest average food loss percentage?
SELECT country, ROUND(AVG(loss_percentage),2) AS "avg_loss"
FROM "food_loss"
GROUP BY country
ORDER BY avg_loss ASC
LIMIT 10;

SELECT country, commodity, year, loss_percentage
FROM "food_loss"
WHERE country = 'Belarus'
ORDER BY loss_percentage DESC;
--Belarus became indipendent from URSS in 1991, I suppose that that's why there are no records of food waste before the 1991.

--3. Question: What type of food is wasted in the biggest quantities? Let's see the top 10
SELECT commodity, ROUND(AVG(loss_percentage),2) AS avg_loss, COUNT(*)
FROM "food_loss"
GROUP BY commodity
ORDER BY avg_loss DESC
LIMIT 10;

--Snails seems to be the type of food that is wasted the most. However, the "count" column tell us that
--throughout the world snails have been wasted only two times over the past 55 years. Therefore I would not consider snails the
--most wasted food, even if it has been wasted in the biggest proportion on average: 50% of the total quantity.
--I should then identify the most frequently wasted food all around the world.

--Question: What is the top 20 of the most frequently wasted foods? What's the average loss percentage?
SELECT commodity, COUNT(*), ROUND(AVG(loss_percentage),2) AS avg_loss
FROM "food_loss"
GROUP BY commodity
ORDER BY COUNT(*) DESC, avg_loss DESC
LIMIT 20;

--It's an interesting result, because even if in small percentages cereals appears to be the most frequently wasted, followed by vegetables and fruits.
--I wonder what category of food is generally the most wasted one.
--I will then group each type of wasted food in ten categories: cereals, vegetables, fruits, legumes, juice, nuts, meat, diary products and eggs, seeds, other.

ALTER TABLE "food_loss"
ADD food_category VARCHAR(50) 

UPDATE "food_loss" SET food_category = CASE 
		WHEN commodity IN ('Walnuts, in shell','Areca nuts','Groundnuts, excluding shelled','Cashew nuts, in shell','Chestnuts, in shell','Copra','Coconuts, in shell','Hazelnuts, in shell','Other nuts (excluding wild edible nuts and groundnuts), in shell, n.e.','Pistachios, in shell','Almonds, in shell','Groundnuts, shelled','Brazil nuts, in shell') THEN 'Nuts'
		WHEN commodity IN ('Coffee, green','Cottonseed','Linseed','Poppy seed','Seed cotton, unginned','Rape or colza seed','Rapeseed or colza seed','Sunflower seed','Mustard seed','Cocoa beans','Safflower seed','Sesame seed') THEN 'Seeds'
		WHEN commodity IN ('Quinces','Pomelos and grapefruits','Cranberries','Raspberries','Cherries','Papayas','Dates','Other berries and fruits of the genus Vaccinium n.e.','Apricots','Watermelons','Other fruits, n.e.c.','Other citrus fruit, n.e.c.','Other tropical and subtropical fruits, n.e.c.','Other tropical and subtropical fruits, n.e.','Raisins','Bananas','Cantaloupes and other melons','Mangoes, guavas and mangosteens','Peaches and nectarines','Avocados','Strawberries','Grapes','Apples','Plantains and others','Figs','Blueberries','Oranges','Other citrus fruit, n.e.','Lemons and limes','Kiwi fruit','Plums, dried','Plantains and cooking bananas','Sour cherries','Plums and sloes','Pineapples','Pears','Other fruits, n.e.','Currants','Raspeberries','Mangoes, guavas, mangosteens','Other stone fruits','Persimmons','Cranberries and other fruits of the genus Vaccinium','Tangerines, mandarins, clementines') THEN 'Fruits'
		WHEN commodity IN ('Swedes, for forage','Potatoes','Spinach','Canned mushrooms','Cassava, fresh','Maize (corn)','Asparagus','Green corn (maize)','Vegetable products, fresh or dry n.e.c.','Cabbages','Other legumes, for forage','Leeks and other alliaceous vegetables','Other vegetables, fresh n.e.','Chillies and peppers, green (Capsicum spp. and Pimenta spp.)','Onions and shallots, dry (excluding dehydrated)','Eggplants (aubergines)','Onions and shallots, green','Edible roots and tubers with high starch or inulin content, n.e.c., dry','Taro','Cassava, dry','Sweet potatoes','olives preserved','Pumpkins, squash and gourds','Edible roots and tubers with high starch or inulin content, n.e.c., fresh','Edible roots and tubers with high starch or inulin content, n.e., fresh','Mushrooms and truffles','Olives','Chillies and peppers, dry (<i>Capsicum</i> spp., <i>Pimenta</i> spp.), raw','Yams','Tapioca of cassava','Sweet corn, prepared or preserved','Carrots and turnips','Artichokes','Chillies and peppers, green (<i>Capsicum</i> spp. and <i>Pimenta</i> spp.)','Other vegetables, fresh n.e.c.','Cucumbers and gherkins','Sweet corn, frozen','Pepper (<i>Piper</i> spp.), raw','Yautia','Tomatoes','Green garlic','Okra','Sugar beet','Cauliflowers and broccoli','Lettuce and chicory') THEN 'Vegetables'
		WHEN commodity IN ('Pigeon peas, dry','Peas, dry','Pulses n.e.','Cow peas, dry','Broad beans and horse beans, dry','Lupins','Chick peas, dry','Beans, dry','Peas, green','Broad beans and horse beans, green','Lentils, dry','Bambara beans, dry','Other beans, green','Soya beans','Other pulses n.e.c.') THEN 'Legumes'
		WHEN commodity IN ('Grape juice','Juice of lemon','Pineapple juice','Apple juice','Juice of citrus fruit n.e.c.','Grapefruit juice','Orange juice') THEN 'Juice'
		WHEN commodity IN ('Starch of Potatoes','Flour of cassava','Flour of triticale','Flour of buckwheat','Wheat and meslin flour','Flour of Maize','Triticale','Rice','Rice, Milled (Husked)','Mixed grain','Bran of Maize','Millet','Wheat','Rice, Milled','Rice, Broken','Oats','Other cereals n.e.','Barley','Sorghum','Husked rice','Fonio','Buckwheat','Canary seed','Rye','Quinoa','Uncooked pasta, not stuffed or otherwise prepared') THEN 'Cereals and flour'
		WHEN commodity IN ('Hen eggs in shell, fresh','Cheese from whole cow milk','Butter of Cow Milk','Raw milk of cattle','Dairy products n.e.c.','Raw milk of sheep','Cheese from Whole Cow Milk','Raw milk of goats') THEN 'Diary and eggs'
		WHEN commodity IN ('Meat of chickens, fresh or chilled','Edible offal of cattle, fresh, chilled or frozen','Meat of other domestic camelids (fresh)','Cattle','Meat of sheep, fresh or chilled','Pig meat, cuts, salted, dried or smoked (bacon and ham)','Meat of cattle, fresh or chilled','Meat of cattle boneless, fresh or chilled','Cattle fat, unrendered','Meat of pig with the bone, fresh or chilled','Meat of pig boneless (pork), fresh or chilled','Meat of goat, fresh or chilled (indigenous)','Camels','Pig, Butcher Fat','Meat of pig, fresh or chilled','Meat of goat, fresh or chilled','Meat of cattle with the bone, fresh or chilled','Snails, fresh, chilled, frozen, dried, salted or in brine, except sea snails','Edible offal of pigs, fresh, chilled or frozen','Goats','Sheep') THEN 'Meat'
		ELSE 'Other'
	END;
	
--Question: What is the average loss percentage of every category of food?
SELECT food_category, ROUND(AVG(loss_percentage),2) AS avg_loss, COUNT(*)
FROM "food_loss"
GROUP BY food_category
ORDER BY avg_loss DESC

--The result seems to makes sense: fresh food like fruits, vegetables and meat are actually more exposed to damages
--and they tend to deteriorate faster than other products like cereals and seeds.


--4. Question: Did the quantity of wasted food change over the years?
--In the last 20 years the attention to the environment has increased very much
--and more and more people are becoming aware of the importance of fighting the food waste.
--I wonder if there are consequences of this increasing awarness in the quantity of food loss.
--I will start by verify that there has been records every year between 1966 and 2021.

SELECT DISTINCT year FROM "food_loss";
--Unfortunately there is any case of food loss reported in 1967.

SELECT year, COUNT(*)
FROM "food_loss" WHERE year BETWEEN '1966' AND '1970'
GROUP BY year;
--Before 1970 the number of records is extremely low, maybe because of the global political situation and the lack of interest in food waste .

SELECT year, ROUND(AVG(loss_percentage),2) AS avg_loss, COUNT(*)
FROM "food_loss" WHERE year NOT BETWEEN '1966' AND '1969'
GROUP BY year
ORDER BY avg_loss ASC, COUNT(*) ASC;

--Effectively every year between 2000 and 2022 is in the top 20 of the years with the lowest average loss percentage
--except for 2013 and 2021 that we find in the 21th and 22th position respectively.

--Therefore the data show that in the last 20 years the quantity of food loss has generally decreased and I would say that
--we can hope to see this quantity to reduce even more in the future. 


--5. Question: What about the supply chain? Which stage generates the most food loss?
SELECT food_supply_stage, COUNT(*), ROUND(AVG(loss_percentage),2) AS avg_loss
FROM "food_loss"
WHERE food_supply_stage <> 'NULL'
GROUP BY food_supply_stage
ORDER BY COUNT(*) DESC, avg_loss DESC;
--It seems that food is often wasted in the farm, more than in any other stage of the food supply, but the post harvest, followed just after by households, 
--is the stage where the biggest proportion of food is loss, on average.

SELECT c.continent, f.food_supply_stage, COUNT(*), ROUND(AVG(f.loss_percentage),2) AS "avg_loss"
FROM "food_loss" AS f JOIN "continents" AS c
ON f.country = c."Denominazione EN"
WHERE food_supply_stage <> 'NULL'
GROUP BY c.continent, f.food_supply_stage
HAVING c.continent = 'South America'
ORDER BY COUNT(*) DESC
--In South America, the continent with the highest percentage of food waste, food losses often happened during the storage and the processing, but
--the biggest quantity of food is lost during the post-harvest.

SELECT food_category, food_supply_stage, COUNT(*), ROUND(AVG(loss_percentage),2) AS "avg_loss"
FROM "food_loss"
WHERE food_category IN ('Juice', 'Fruits', 'Meat') AND food_supply_stage <> 'Whole supply chain'
GROUP BY food_category, food_supply_stage
ORDER BY food_category, COUNT(*) DESC, avg_loss DESC;
--Fruits are often wasted in retail, and during the post-harvest and at home a big quantity of them is generally thrown away,
--and juices and meat are also wasted in big proportion at home.


--CONCLUSION

--Thankfully there has already been a reduction of food waste in the last years, but it's possible and it's necessary to improve even more, so that 
--one day every person in the world will, hopefully, have access to food, and hunger will only be a memory.
--This analysis showed some weaknesses, and that's where we can get better.
--For exemple we saw that in South America, the continent with the biggest problem of food loss,
--the biggest waste occur during the post-harvest, the processing and the storage, so these are the phases where it's possible to ameliorate.
--We also saw that juices, fruits and meat are the most wasted aliments, especially during post harvest, retail and at home.
--That's why is really important to continue to create awareness, all around the world, starting in the schools, so that the new generations
--will grow up knowing that their habits count and that is important to reduce food waste at home as much as possible.