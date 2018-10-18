
server <- function(input, output) {
  
  # render the monthly sales chart
  output$monthly_sales <- renderPlotly({
    # order the data by group and axis order to plot correctly
    monthly_sales_local <- monthly_sales_local %>%
      arrange(CustomerGroup, SalesMonth)
    
    # plot the line chart with plotly
    plot_ly(monthly_sales_local,
            x = ~SalesMonth,
      y = ~SalesAmount,
      type = 'scatter',
      mode = 'lines',
      color = ~CustomerGroup) %>%
      layout(xaxis = list(title = 'Sales month'),
             yaxis = list (title = 'Sales amount (GBP)'))
  })
  
  # render the top 10 wholesale products chart
  output$top_10_products_wholesale <- renderPlotly({
    
    # keep only the wholesale data, order descending by sales amount for plotting
    top_10_products_ws <- top_10_products_local %>%
      filter(CustomerGroup == "Wholesale") %>%
      arrange(desc(SalesAmount))
    
    # plot the horizontal bar chart using plotly
    plot_ly(top_10_products_ws,
            x = ~SalesAmount,
            y = ~reorder(factor(Description), SalesAmount),
            type = 'bar',
            orientation = 'h') %>%
      layout(xaxis = list(title = 'Sales amount (GBP)'),
             yaxis = list(title = ''),
             margin = list(l = 250))
  })
  
  # render the top 10 retail products chart
  output$top_10_products_retail <- renderPlotly({
    
    # keep only the retail data, order descending by sales amount for plotting
    top_10_products_rt <- top_10_products_local %>%
      filter(CustomerGroup == "Retail") %>%
      arrange(desc(SalesAmount))
    
    # plot the horizontal bar chart using plotly
    plot_ly(top_10_products_rt,
            x = ~SalesAmount,
            y = ~reorder(factor(Description), SalesAmount),
            type = 'bar',
            orientation = 'h') %>%
      layout(xaxis = list(title = 'Sales amount (GBP)'),
             yaxis = list(title = ''),
             margin = list(l = 250))
  })
  
  # render the top 10 wholesale customers table
  output$top_10_wholesale_customers <- DT::renderDataTable({
    displayData <- top_10_wholesale_customers_local %>%
      select(CustomerID, AmountSpent, NumPurchases) %>%
      filter(rank(desc(AmountSpent)) <= 5)
    
    # display the table, 10 rows per page
    DT::datatable(displayData, 
                  rownames = FALSE, 
                  colnames = c("Customer ID" = "CustomerID", 
                               "Amount spent" = "AmountSpent",
                               "Purchases" = "NumPurchases"), 
                  options = list(pageLength = 10, autoHideNavigation = TRUE))
  })
  
  # render the revenue by country map
  output$map <- renderLeaflet({
    
    # join the countries in revenue to countries in the world map
    sPDF <- joinCountryData2Map(sales_by_country_local
                                ,joinCode = "NAME"
                                ,nameJoinColumn = "Country", verbose = TRUE)
    
    # single out world countries with revenue (revenue did not come from all world countries)
    existing_countries <- subset(sPDF, !is.na(Amount))
    
    # create bins for revenue amounts, for coloring
    bins <- c(0, 50000, 100000, 150000, 200000, 250000, 300000, Inf)
    pal <- colorBin("YlOrRd", domain = existing_countries$Amount, bins = bins)
    
    # create popup labels with exact revenue amount for every country
    labels <- paste0("<strong>", existing_countries$Country, "</strong><br/>", 
                     format(existing_countries$Amount, digits = 0, big.mark = ".", decimal.mark = ",", scientific = FALSE),
                     " GBP") %>% lapply(htmltools::HTML)
    
    # draw the world map with overlayed revenue per country
    leaflet(existing_countries) %>%
      addTiles() %>%  # Add default OpenStreetMap map tiles
      addPolygons(
        fillColor = ~pal(Amount),
        weight = 1,
        opacity = 1,
        color = "white",
        dashArray = "3",
        fillOpacity = 0.7,
        highlight = highlightOptions(
          weight = 2,
          color = "#666",
          dashArray = "",
          fillOpacity = 0.7,
          bringToFront = TRUE),
        label = labels,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto")) %>% 
      addLegend(pal = pal, values = ~Amount, opacity = 0.7, title = NULL, position = "topright") %>%
      setView(17,34,3)
  })
  
  # Make the wordcloud drawing predictable during a session
  wordcloud_rep <- repeatable(wordcloud)

  # render the frequent itemsets wordcloud
  output$wordcloud_plot <- renderPlot({
  
     # keep only the combinations from the selected season
     selected_itemset <- freq_itemsets_local %>%
       filter(Season == input$selection)
  
     # create the wordcloud
     wordcloud(selected_itemset$itemset, selected_itemset$freq, max.words = input$max, scale=c(2,0.05),rot.per = 0,
               colors=brewer.pal(8, "Dark2"), random.order = FALSE, random.color = FALSE, fixed.asp = FALSE)
  })
  
  # render the association network
  output$network_plot <- renderForceNetwork({
    
    # keep only associations from the selected season and above the selected confidence
    selected_assoc_rules <- assoc_rules_local %>%
      filter(season == input$selection_network & confidence >= input$confidence) %>%
      select(-season)
    
    # select all antecedent nodes
    ante <- selected_assoc_rules %>%
      distinct(antecedent) %>%
      transmute(name = antecedent)
    
    # combine distinct antecedent and consequent nodes to create a unique list of nodes and generate their IDs
    nodes <- selected_assoc_rules %>%
      distinct(consequent) %>%
      transmute(name = consequent) %>%
      bind_rows(ante) %>%
      distinct() %>%
      mutate(group = "1") %>%
      mutate(row_id = seq(from = 0, length.out = length(name)), size = 20)
    
    # create the links from association rules, use node IDs
    links <- selected_assoc_rules %>%
      left_join(nodes, by = c("antecedent" = "name")) %>%
      mutate(antecedent_row_id = row_id) %>%
      select(-row_id) %>%
      left_join(nodes, by = c("consequent" = "name")) %>%
      mutate(consequent_row_id = row_id) %>%
      select(-row_id,-group.x,-group.y)
    
    # create the network plot
    forceNetwork(Links = as.data.frame(links), Nodes = as.data.frame(nodes), Source = "antecedent_row_id",
                 Target = "consequent_row_id", Value = "confidence", NodeID = "name",
                 Group = "group", opacity = 0.9, arrows = TRUE, linkWidth = JS("function(d) { return d.value * 4; }"),
                 Nodesize = "size", fontSize = 15, fontFamily = "arial", linkDistance = 100, charge = -30, bounded = TRUE,
                 opacityNoHover = 0.5)
  })
  
  # render the data table showing purchase history
  output$recomm_purchase_history <- DT::renderDataTable(
    # create the data table, keep only the currently selected customer purchase history data
    DT::datatable(filter(purchase_history_local, CustomerID == input$selection_customer), options = list(pageLength = 10))
  )
  
  # render the data table showing top recommendations
  output$recomm_recommendations <- DT::renderDataTable(
    # create the data table, keep only the currently selected customer recomendations, top N selected
    DT::datatable(filter(top_10_recommended_products_local, CustomerID == input$selection_customer) %>%
                         filter(rank(desc(rating)) <= input$topnrecommendations), options = list(pageLength = 10))
  )
}



