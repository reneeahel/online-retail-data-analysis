library(tidyverse)
library(sparklyr)
library(lubridate)


# Spark initialization & data load ----------------------------------------

# connect to Spark
sc <- spark_connect(master = "local",spark_home = "~/spark/spark-2.3.1-bin-hadoop2.7", app_name = "Webapp_data_preparation")

# read the transactions, invoices, products and wholesale customers tables from Parquet file(s)
# paths are relative to working directory - the one where R project is defined
sales_transactions_tbl <- spark_read_parquet(sc, "sales_transactions", str_c("file:", getwd(), "/Data/spark-warehouse/sales-transactions"), mode = "overwrite")
invoices_tbl <- spark_read_parquet(sc, "invoices", str_c("file:", getwd(), "/Data/spark-warehouse/invoices"), mode = "overwrite")
products_tbl <- spark_read_parquet(sc, "products", str_c("file:", getwd(), "/Data/spark-warehouse/products"), mode = "overwrite")
wholesale_customers_tbl <- spark_read_parquet(sc, "wholesale_customers", str_c("file:", getwd(), "/Data/spark-warehouse/wholesale_customers"), mode = "overwrite")

# prepare sales transactions - clean product descriptions, create month, monthday and CustomerGroup columns, remove cancelled invoices & cancellations, 
# remove non-product line items like postage fees, Amazon fee
sales_transactions_tbl <- sales_transactions_tbl %>%
  select(-Description) %>%
  inner_join(products_tbl, by = "StockCode") %>%
  mutate(SalesMonth = as.character(as.integer(year(InvoiceDate) * 100 + month(InvoiceDate))), 
         Amount = UnitPrice * Quantity,
         MonthDay = as.integer(month(InvoiceDate) * 100 + day(InvoiceDate)),
         CustomerGroup = ifelse(is.na(CustomerID), "Retail", "Wholesale")) %>%
  filter(!StockCode %in% c("DOT", "POST", "M", "AMAZONFEE") & 
           !is.na(SalesMonth) &
           is.na(InvoiceStatus) &
           is.na(InvoicePrefix))

# Basic data preparation --------------------------------------------------

monthly_sales_local <- sales_transactions_tbl %>%
  group_by(CustomerGroup, SalesMonth) %>%
  summarise(SalesAmount = sum(Amount, na.rm = TRUE)) %>%
  filter(!is.na(SalesMonth) & SalesMonth != 201112) %>%
  collect

top_10_products_local <- sales_transactions_tbl %>%
  group_by(Description, CustomerGroup) %>%
  summarise(SalesAmount = sum(Amount, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(CustomerGroup) %>%
  filter(rank(desc(SalesAmount)) <= 10) %>%
  collect

sales_by_country_local <- sales_transactions_tbl %>%
  group_by(Country) %>%
  summarise(Amount = sum(Amount, na.rm = TRUE)) %>%
  collect

top_10_cust <- wholesale_customers_tbl %>%
  filter(rank(desc(AmountSpent)) <= 10) %>%
  select(CustomerID)

top_10_wholesale_customers_local <- wholesale_customers_tbl %>%
  inner_join(top_10_cust, by = "CustomerID") %>%
  select(CustomerID, AmountSpent, NumPurchases, TenureDays, DaysSinceLastPurchase) %>%
  arrange(desc(AmountSpent)) %>%
  collect



# Market basket analysis - data preparation ------------------------------------


# clean & transform the original table
itemsets_tbl <- sales_transactions_tbl %>%
  mutate(Season = ifelse(between(MonthDay,101,320) | between(MonthDay,1221,1231),"Winter",
                         ifelse(between(MonthDay,321,620),"Spring",
                                ifelse(between(MonthDay,621,923),"Summer",
                                       ifelse(between(MonthDay,924,1220),"Autumn","Unknown"))))) %>%
  select(InvoiceNo, Description, Season, InvoiceDate) %>%
  distinct() %>%
  group_by(InvoiceNo,Season, InvoiceDate) %>% 
  summarise(items = collect_list(Description))


# Market basket analysis - for full year and every season -------------------------------------------

# prepare final itemsets and association rules tables
freq_itemsets_local <- tibble()
assoc_rules_local <- tibble()

for(year_period in c("Whole year", "Winter", "Spring", "Summer", "Autumn")){
  # run the FPGrowth algorithm
  if(year_period == "Whole year"){
    fp_model <- ml_fpgrowth(itemsets_tbl, min_confidence = 0.5, min_support = 0.025)
  } else {
    fp_model <- ml_fpgrowth(filter(itemsets_tbl, Season == year_period), min_confidence = 0.5, min_support = 0.025)
  }
  
  # extract frequent itemsets, label the season
  freq_itemsets <- ml_freq_itemsets(fp_model) %>%
    collect %>%
    mutate(list_length = map_int(items, length)) %>%
    filter(list_length > 1) %>%
    arrange(desc(freq)) %>%
    mutate(itemset = map_chr(items, str_c, sep = "-", collapse = "-")) %>%
    mutate(Season = year_period) %>%
    select(-items, -list_length)
  
  # extract association rules, label the season
  assoc_rules <- ml_association_rules(fp_model) %>%
    collect %>%
    mutate(antecedent = map_chr(antecedent, str_c, sep = " + ", collapse = " + "),
           consequent = map_chr(consequent, str_c, sep = " + ", collapse = " + ")) %>%
    mutate(season = year_period)
  
  # concatenate the results for all seasons
  freq_itemsets_local <- freq_itemsets_local %>%
    bind_rows(freq_itemsets) 
  assoc_rules_local <- assoc_rules_local %>%
    bind_rows(assoc_rules)
}

# convert seasons to factors - important for displaying in a combo box
freq_itemsets_local$Season <- as.factor(freq_itemsets_local$Season)
assoc_rules_local$season <- as.factor(assoc_rules_local$season)

# Recommender engine output -------------------------------------------

# prepare data for recommender input
ratings_tbl <- sales_transactions_tbl %>%
  filter(!is.na(CustomerID)) %>%
  select(CustomerID, StockCode, Description, Quantity) %>%
  group_by(CustomerID, StockCode, Description) %>%
  summarise(Quantity = sum(Quantity, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(CustomerID = as.integer(CustomerID),
         StockID = as.integer(rank(StockCode)))

# create a stock ID and names table - to join it back to recommendations
product_names_tbl <- ratings_tbl %>%
  select(StockID, StockCode, Description) %>%
  distinct()

# train the ALS. I'll set the regularization parameter to 0.1, set implicit preference to true to indicate to ALS that 
# ratings are actually derived from other information, and set the cold start to drop, to get only the results where the recommender returns a recommendation.
als_model <- ml_als(ratings_tbl, rating_col = "Quantity", user_col = "CustomerID",
                    item_col = "StockID", reg_param = 0.1,
                    implicit_prefs = TRUE, alpha = 1, nonnegative = FALSE,
                    max_iter = 10, num_user_blocks = 10, num_item_blocks = 10,
                    checkpoint_interval = 10, cold_start_strategy = "drop")

# extract top 10 recommended products per customer, for selected customers
top_10_recommended_products_local <- ml_recommend(als_model, type = "items", 10) %>%
  inner_join(product_names_tbl, by = "StockID") %>%
  select(-recommendations) %>%
  filter(CustomerID %in% c(12353, 12361, 12367, 12401, 12441)) %>%
  arrange(CustomerID, desc(rating)) %>%
  select(CustomerID, StockCode, Description, rating) %>%
  collect

# extract purchase history, for selected customers
purchase_history_local <- ratings_tbl %>%
  filter(CustomerID %in% c(12353, 12361, 12367, 12401, 12441)) %>%
  arrange(CustomerID, desc(Quantity)) %>%
  select(CustomerID, StockCode, Description, Quantity) %>%
  collect


# Save webapp data -------------------------------------------

# save to RData file, which is then a direct data source for the application
save(monthly_sales_local, top_10_products_local, sales_by_country_local, freq_itemsets_local, assoc_rules_local, top_10_wholesale_customers_local, 
     purchase_history_local, top_10_recommended_products_local,  file = "WebApp/Webapp_data.RData")

# disconnect from Spark
spark_disconnect(sc)
