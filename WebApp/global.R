library(shiny)
library(shinydashboard)
library(ggplot2)
library(dplyr)
library(leaflet)
library(rworldmap)
library(wordcloud)
library(networkD3)
library(DT)
library(plotly)

# load the web app data
load(file = "Webapp_data.RData")

# select all distinct seasons, and store them as factor
seasons <- as.factor(freq_itemsets_local %>%
                       select(Season) %>%
                       distinct() %>%
                       pull(Season))

# select all distinct CustomerIDs from the recommendations, and store them as a factor
customerIDs <- as.factor(purchase_history_local %>%
            select(CustomerID) %>%
            distinct() %>%
            pull(CustomerID))


