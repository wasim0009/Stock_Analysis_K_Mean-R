# Load necessary libraries
if (!requireNamespace("quantmod", quietly = TRUE)) {
  install.packages("quantmod")
}
if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  install.packages("ggplot2")
}
if (!requireNamespace("factoextra", quietly = TRUE)) {
  install.packages("factoextra")
}
if (!requireNamespace("corrplot", quietly = TRUE)) {
  install.packages("corrplot")
}
if (!requireNamespace("shiny", quietly = TRUE)) {
  install.packages("shiny")
}
if (!requireNamespace("shiny.semantic", quietly = TRUE)) {
  install.packages("shiny.semantic")
}

library(shiny)
library(quantmod)
library(dplyr)
library(ggplot2)
library(factoextra)
library(corrplot)
library(shiny.semantic)

# Define UI with Semantic UI
ui <- semanticPage(
  title = "K-Means Clustering of Stock Data",
  
  # Sidebar for inputs
  sidebar_layout(
    sidebar_panel(
      h3("Stock Analysis Parameters"),
      
      # Dropdown for company selection
      selectInput("companies", "Select Companies:", 
                  choices = c("AMZN", "AAPL", "WBA", "NOC", "BA", "LMT", "MCD", "INTC", "IBM", "TXN", 
                              "MA", "MSFT", "GE", "AXP", "PEP", "KO", "JNJ", "TM", "HMC", "XOM", 
                              "CVX", "VLO", "F", "BAC", "JPM", "WFC", "V"),
                  selected = "AAPL", multiple = TRUE),
      
      # Date range input
      dateRangeInput("dateRange", "Select Date Range:",
                     start = "2010-01-01", end = Sys.Date()),
      
      # Numeric input for number of clusters
      numericInput("clusters", "Number of Clusters:", value = 5, min = 1, max = 15),
      
      # Run analysis button
      actionButton("run", "Run Analysis", class = "ui button blue"),
      br(),
      br(),
      
      # Help text
      helpText("Select the desired companies, date range, and number of clusters for K-means analysis.")
    ),
    
    main_panel(
      h3("Analysis Results"),
      h3("Cluster Plot"),
      plotOutput("clusterPlot"),
      br(),
      h3("Scree Plot"),
      plotOutput("screePlot"),
      br(),
      h3("Cluster Size Plot"),
      plotOutput("clusterSizePlot"),
      br(),
      h3("Adjusted Close Prices"),
      plotOutput("pricePlot"),
      br(),
      h3("Cumulative Returns"),
      plotOutput("cumulativePlot"),
      br(),
      h3("Correlation Heatmap"),
      plotOutput("correlationPlot"),
      br(),
      h3("PCA Biplot"),
      plotOutput("biplot")
    )
  )
)

# Define server logic
server <- function(input, output) {
  
  analysis_results <- eventReactive(input$run, {
    companies <- input$companies
    date_range <- input$dateRange
    n_clusters <- input$clusters
    
    available_data <- list()
    
    # Fetch stock data and filter out unavailable stocks
    for (symbol in companies) {
      tryCatch({
        stock_data <- getSymbols(symbol, from = date_range[1], to = date_range[2], auto.assign = FALSE)
        available_data[[symbol]] <- Ad(stock_data)  # Adjusted close prices
      }, error = function(e) {
        message(paste("Warning: Unable to import", symbol, "-", e$message))
      })
    }
    
    if (length(available_data) > 0) {
      stock_data <- do.call(merge, available_data)
      movements <- diff(log(stock_data)) * 100
      movements <- na.omit(movements)
      norm_movements <- scale(movements)
      
      # Perform PCA
      pca_result <- prcomp(norm_movements)
      reduced_data <- pca_result$x[, 1:2]  # Take the first two principal components
      
      # K-Means Clustering
      set.seed(123)
      kmeans_result <- kmeans(reduced_data, centers = n_clusters, nstart = 50)
      
      # Create a data frame for results
      clustered_data <- data.frame(x = reduced_data[, 1], y = reduced_data[, 2], labels = kmeans_result$cluster)
      
      return(list(data = clustered_data, pca = pca_result, kmeans = kmeans_result, stock_data = stock_data, movements = movements))
    } else {
      return(NULL)
    }
  })
  
  # Plotting clusters
  output$clusterPlot <- renderPlot({
    req(analysis_results())
    fviz_cluster(analysis_results()$kmeans, data = analysis_results()$data[, c("x", "y")],
                 geom = "point", stand = FALSE, 
                 ellipse.type = "convex") + 
      ggtitle("K-Means Clustering of Stock Movements (PCA Reduced)")
  })
  
  # Scree Plot
  output$screePlot <- renderPlot({
    req(analysis_results())
    fviz_eig(analysis_results()$pca) +  # Corrected to `fviz_eig`
      ggtitle("Scree Plot")
  })
  
  # Cluster Size Plot
  output$clusterSizePlot <- renderPlot({
    req(analysis_results())
    cluster_sizes <- table(analysis_results()$kmeans$cluster)
    barplot(cluster_sizes, main = "Cluster Sizes", xlab = "Clusters", ylab = "Number of Companies",
            col = rainbow(length(cluster_sizes)))
  })
  
  # Adjusted Close Prices Plot
  output$pricePlot <- renderPlot({
    req(analysis_results())
    stock_data <- analysis_results()$stock_data
    matplot(index(stock_data), stock_data, type = "l", lty = 1, col = rainbow(ncol(stock_data)),
            xlab = "Date", ylab = "Adjusted Close Price", main = "Adjusted Close Prices of Selected Stocks")
    legend("topright", legend = colnames(stock_data), col = rainbow(ncol(stock_data)), lty = 1)
  })
  
  # Cumulative Returns Plot
  output$cumulativePlot <- renderPlot({
    req(analysis_results())
    movements <- analysis_results()$movements
    cumulative_returns <- cumprod(1 + movements / 100) - 1  # Calculate cumulative returns
    matplot(index(cumulative_returns), cumulative_returns, type = "l", lty = 1, col = rainbow(ncol(cumulative_returns)),
            xlab = "Date", ylab = "Cumulative Returns", main = "Cumulative Returns of Selected Stocks")
    legend("topright", legend = colnames(cumulative_returns), col = rainbow(ncol(cumulative_returns)), lty = 1)
  })
  
  # Correlation Heatmap
  output$correlationPlot <- renderPlot({
    req(analysis_results())
    movements <- analysis_results()$movements
    corr_matrix <- cor(movements, use = "complete.obs")  # Compute the correlation matrix
    corrplot(corr_matrix, method = "color", addCoef.col = "black", tl.col = "black", tl.srt = 45,
             main = "Correlation Heatmap of Stock Movements")
  })
  
  output$biplot <- renderPlot({
    req(analysis_results())
    pca_result <- analysis_results()$pca
    fviz_pca_biplot(pca_result, repel = TRUE, 
                    col.ind = as.factor(analysis_results()$kmeans$cluster),
                    palette = "jco", 
                    addEllipses = TRUE, 
                    label = "var") + 
      ggtitle("PCA Biplot")
  })

}

# Run the application
shinyApp(ui = ui, server = server)
