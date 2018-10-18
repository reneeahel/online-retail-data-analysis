# IMPORTANT - execute this script with R under admin privileges ("sudo R")

# create a list of the required packages
required_packages <- c("tidyverse",
"sparklyr",
"readxl",
"leaflet",
"rworldmap",
"wordcloud",
"networkD3",
"shiny",
"shinydashboard",
"DT",
"plotly")

# compare installed packages to the required packages
packages_to_install <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

# install the missing packages
if(length(packages_to_install)) install.packages(packages_to_install)

# install Spark locally using sparklyr utils, if not already installed
if(nrow(sparklyr::spark_installed_versions()) == 0) sparklyr::spark_install(version = "2.3.1", hadoop_version = "2.7")

# download the dataset to Data subdirectory
utils::download.file(url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00352/Online%20Retail.xlsx",
                     destfile = "Data/Online Retail.xlsx")
