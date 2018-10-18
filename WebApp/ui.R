
# fill width only
ui <- dashboardPage(
  dashboardHeader(title = "Online retail demo by Renee Ahel", titleWidth = "330px"),
  dashboardSidebar(width = "270",
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Sales by country", icon = icon("globe"), tabName = "widgets"),
      menuItem("Frequent product combinations", icon = icon("shopping-basket"), tabName = "itemsets"),
      menuItem("Product associations", icon = icon("shopping-cart"), tabName = "assocrules"),
      menuItem("Product recommendations", icon = icon("cart-plus"), tabName = "recommendations"),
      menuItem("About", icon = icon("info-circle"), tabName = "about")
    )
  ),
  dashboardBody(
    # Boxes need to be put in a row (or column)
    tabItems(
      tabItem(tabName = "dashboard",
        fluidRow(
          column(width = 6,
                 box(title = "Monthly sales", solidHeader = TRUE, width = NULL, status = "primary",
                     plotlyOutput(outputId = "monthly_sales", height = "350px")),
                 
                   box(title = "Top 5 wholesale customers by revenue", solidHeader = TRUE, width = NULL, status = "primary",
                       DT::dataTableOutput(outputId = "top_10_wholesale_customers"))
          ),
          column(width = 6,
                   box(title = "Top 10 sold products - wholesale", solidHeader = TRUE, width = NULL, status = "primary",
                       plotlyOutput(outputId = "top_10_products_wholesale", height = "350px")),
                 
                   box(title = "Top 10 sold products - retail", solidHeader = TRUE, width = NULL, status = "primary",
                                   plotlyOutput(outputId = "top_10_products_retail", height = "350px"))
          )
        )
      ),
      tabItem(tabName = "widgets",
              box(title = "Revenue by country", solidHeader = TRUE, width = NULL, status = "primary",
                  leafletOutput("map", height="800px"))
      ),
      tabItem(tabName = "itemsets",
              box(title = "Product combinations", solidHeader = TRUE, width = NULL, status = "primary",
                  plotOutput(outputId = "wordcloud_plot", height = "550px")),
              hr(),
              selectInput("selection", "Choose a season:",
                          choices = levels(seasons)),
              sliderInput("max",
                          "Show this number of top combinations:",
                          min = 1,  max = 100,  value = 10),
              h4("The word cloud displays most frequent combinations of products in orders from the selected season. Color and size of the text are proportional to the frequency of that combination."),
              h4("The combinations have been derived using the FPGrowth algorithm from the Spark machine learning library MLlib.")
      ),
      tabItem(tabName = "assocrules",
        box(title = "Product association network", solidHeader = TRUE, width = NULL, status = "primary",
        forceNetworkOutput(outputId = "network_plot", height = "550px")),
        hr(),
        selectInput("selection_network", "Choose a season:",
                                   choices = levels(seasons)),
        sliderInput("confidence",
                    "Show top association rules with confidence over:",
                    min = 0.5,  max = 1,  value = 0.6),
        h4("The network displays the strongest associations of products in purchases from the selected season."),
        h4("The rules have been derived using the FPGrowth algorithm from the Spark machine learning library MLlib.")
      ),
      tabItem(tabName = "recommendations",
           fluidRow(
             column(width = 6,
                    box(title = "Purchase history", solidHeader = TRUE, width = NULL, status = "primary",
                        DT::dataTableOutput(outputId = "recomm_purchase_history"))
             ),
             column(width = 6,
                    box(title = "Top recommendations", solidHeader = TRUE, width = NULL, status = "primary",
                        DT::dataTableOutput(outputId = "recomm_recommendations"))
             )
           ),
          hr(),
          selectInput("selection_customer", "Choose a customerID:",
                            choices = levels(customerIDs)),
          sliderInput("topnrecommendations",
                      "Show top N recommended products:",
                      min = 1,  max = 10,  value = 5),
          h4("The tables display the purchase history and the top N recommendations for the same customer."),
          h4("The recommendations have been produced using the ALS recommender from the Spark machine learning library MLlib.")
      ),
      tabItem(tabName = "about",
          h1('Online retail demo data driven app'),
          p("The app is showing some of the insights which can be found by applying data science to real web giftshop purchase data. The giftshop mainly sells unique all-occasion gifts, many customers of the company are wholesalers."), 
          p("The purpose of the app is to demonstrate how the results of a 
          data science project can quickly be shared with a wider audience, in an interactive way. Data is coming from ", 
          a(href = "https://archive.ics.uci.edu/ml/index.php", "UCI machine learning repository"), 
          ", dataset ", a(href = "https://archive.ics.uci.edu/ml/datasets/Online%20Retail", "online retail sales data"), ". This app was created using the ", a(href = "https://shiny.rstudio.com/", "R Shiny web framework"), 
          "and the demo project was done using ", a(href = "https://www.r-project.org/", "R"), ", ", a(href = "https://www.tidyverse.org/", "tidyverse"), ", ", a(href = "https://spark.rstudio.com/", "sparklyr"), " and ", 
          a(href = "https://spark.apache.org/", "Apache Spark"), ". Detailed data science notebook can be found ", 
          a(href = "http://rpubs.com/reneeahel/OnlineRetailAnalysisDemo", "here"), ".")
      )
    )
  )
)



