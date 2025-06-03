library(shiny)
library(leaflet)
library(plotly)
library(dplyr)
library(ggplot2)
library(sf)
library(RColorBrewer)

# Load preprocessed data (change these paths for the selected country)
ess_data <- readRDS("data/ess_bg.rds")
country_map <- readRDS("data/bg_map.rds")

# === VARIABLE DEFINITIONS ===
variable_choices <- c(
  "Happiness"             = "happy",
  "Life Satisfaction"     = "stflife",
  "Trust in Politicians"  = "trstplt",
  "Trust in Parliament"   = "trstprl",
  "Trust in Legal System" = "trstlgl"
)

rev_labels <- setNames(names(variable_choices), variable_choices)

var_descriptions <- list(
  happy   = "How happy are you? (0–10)",
  stflife = "Satisfaction with life as a whole (0–10)",
  trstplt = "Trust in politicians (0–10)",
  trstprl = "Trust in the country's parliament (0–10)",
  trstlgl = "Trust in the legal system (0–10)"
)

# === UI ===
ui <- fluidPage(
  titlePanel("European Social Survey 2018 – Bulgaria – Interactive Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("var1", "Variable for map and X-axis:",
                  choices = variable_choices, selected = "happy"),
      selectInput("var2", "Variable for Y-axis:",
                  choices = variable_choices, selected = "trstprl"),
      actionButton("reset", "Clear Selection"),
      hr(),
      helpText("- Click a region on the map to filter the scatterplot"),
      helpText("- Click again to deselect"),
      helpText("- Select points in the scatterplot to highlight regions on the map"),
      hr(),
      h4("Variable Descriptions"),
      tags$ul(
        lapply(names(variable_choices), function(label) {
          code <- variable_choices[[label]]
          tags$li(strong(label, ": "), var_descriptions[[code]])
        })
      )
    ),
    mainPanel(
      splitLayout(
        cellWidths = c("50%", "50%"),
        leafletOutput("mapPlot",    height = 500),
        plotlyOutput("scatterPlot", height = 500)
      ),
      hr(),
      h4("Region Information"),
      uiOutput("region_info"),
      tags$div(
        style = "margin-top:20px; font-size:80%; color: #666; text-align: center;",
        "This app was developed as part of the Data Visualization course at the Faculty of Social Sciences, University of Ljubljana (mentors: Alež Žiberna & Marjan Cugmas). ",
        "Data retrieved from the European Social Survey (ESS) 2018. ",
        "ChatGPT was used to assist with code development."
      )
    )
  )
)

# === SERVER ===
server <- function(input, output, session) {
  selected_region <- reactiveVal(NULL)
  selected_points <- reactiveVal(NULL)
  
  avg_data <- reactive({
    ess_data %>%
      group_by(region_name) %>%
      summarise(
        avg_value = mean(.data[[input$var1]], na.rm = TRUE),
        count     = n(),
        .groups   = "drop"
      )
  })
  
  map_data <- reactive({
    country_map %>% left_join(avg_data(), by = c("NAME_LATN" = "region_name"))
  })
  
  observeEvent(input$reset, {
    selected_region(NULL)
    selected_points(NULL)
  })
  
  observeEvent(input$mapPlot_shape_click, {
    clicked <- input$mapPlot_shape_click$id
    regs <- selected_region()
    if (is.null(regs)) {
      selected_region(clicked)
    } else if (clicked %in% regs) {
      new <- setdiff(regs, clicked)
      selected_region(if (length(new)) new else NULL)
    } else {
      selected_region(c(regs, clicked))
    }
    selected_points(NULL)
  })
  
  observeEvent(event_data("plotly_selected", source = "scatter"), {
    sel <- event_data("plotly_selected")
    if (!is.null(sel)) {
      selected_points(sel$pointNumber)
      regs <- unique(ess_data$region_name[sel$pointNumber + 1])
      selected_region(regs)
    } else {
      selected_points(NULL)
      selected_region(NULL)
    }
  })
  
  observeEvent(event_data("plotly_click", source = "scatter"), {
    click <- event_data("plotly_click", source = "scatter")
    if (!is.null(click)) {
      df <- filtered_data()
      idx <- click$pointNumber + 1
      if (idx <= nrow(df)) {
        clicked_region <- df$region_name[idx]
        selected_region(clicked_region)
        selected_points(NULL)
      }
    }
  })
  
  filtered_data <- reactive({
    regs <- selected_region()
    if (is.null(regs)) ess_data else ess_data %>% filter(region_name %in% regs)
  })
  
  output$mapPlot <- renderLeaflet({
    df <- map_data()
    lbl <- rev_labels[[input$var1]]
    pal <- colorNumeric("YlOrRd", domain = df$avg_value)
    
    leaflet(df) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        layerId     = ~NAME_LATN,
        fillColor   = ~pal(avg_value),
        color       = "white",
        weight      = 1,
        fillOpacity = 0.8,
        label       = sprintf(
          "<strong>%s</strong><br/>Avg %s: <strong>%.2f</strong><br/>n=%d",
          df$NAME_LATN, lbl, df$avg_value, df$count
        ) %>% lapply(htmltools::HTML),
        highlight   = highlightOptions(weight = 3, color = "#666", fillOpacity = 0.9)
      ) %>%
      addLegend(
        pal       = pal,
        values    = df$avg_value,
        title     = lbl,
        labFormat = labelFormat(digits = 2),
        opacity   = 0.8
      )
  })
  
  observe({
    regs <- selected_region()
    proxy <- leafletProxy("mapPlot")
    proxy %>% clearGroup("highlight")
    if (!is.null(regs)) {
      proxy %>% addPolylines(
        data = country_map %>% filter(NAME_LATN %in% regs),
        group = "highlight",
        color = "red",
        weight = 3
      )
    }
  })
  
  output$scatterPlot <- renderPlotly({
    set.seed(123)
    df <- filtered_data()
    
    all_regions <- sort(unique(ess_data$region_name))
    region_colors <- colorRampPalette(RColorBrewer::brewer.pal(8, "Dark2"))(length(all_regions))
    color_map <- setNames(region_colors, all_regions)
    cols <- color_map[df$region_name]
    
    hover <- paste0(
      "Region: ", df$region_name, "<br>",
      rev_labels[[input$var1]], ": ", df[[input$var1]], "<br>",
      rev_labels[[input$var2]], ": ", df[[input$var2]]
    )
    
    p <- ggplot(df, aes(x = .data[[input$var1]], y = .data[[input$var2]])) +
      geom_jitter(aes(text = hover), width = 0.3, height = 0.3,
                  color = cols, alpha = 0.6) +
      labs(
        title = if (is.null(selected_region()))
          "Scatterplot – All Regions"
        else
          paste("Scatterplot –", paste(selected_region(), collapse = ", ")),
        x = rev_labels[[input$var1]],
        y = rev_labels[[input$var2]]
      ) +
      theme_minimal()
    
    ggplotly(p, tooltip = "text", source = "scatter") %>%
      layout(dragmode = "select")
  })
  
  output$region_info <- renderUI({
    regs <- selected_region()
    if (is.null(regs)) {
      p("No region selected. Click or brush to view details.")
    } else if (length(regs) == 1) {
      rd <- avg_data() %>% filter(region_name == regs)
      tagList(
        tags$h5(regs),
        tags$ul(
          tags$li(paste0("Average ", rev_labels[[input$var1]], ": ", round(rd$avg_value, 2))),
          tags$li(paste0("Respondents: ", rd$count))
        )
      )
    } else {
      sel_df <- ess_data %>% filter(region_name %in% regs)
      combined_avg <- mean(sel_df[[input$var1]], na.rm = TRUE)
      total_resp <- nrow(sel_df)
      tagList(
        tags$h5(paste(regs, collapse = " + ")),
        tags$ul(
          tags$li(paste0("Combined average ", rev_labels[[input$var1]], ": ", round(combined_avg, 2))),
          tags$li(paste0("Total respondents: ", total_resp))
        )
      )
    }
  })
}

shinyApp(ui, server)
