library(shiny)
library(shinyWidgets)
library(ctmm)
library(sf)
library(glue)
library(dplyr)
library(purrr)
library(mapview)
library(leaflet)
library(zip)
library(shinycssloaders)
library(leafem)


shinyModuleUserInterface <- function(id, label) {
  ns <- NS(id) ## all IDs of UI functions need to be wrapped in ns()
  tagList(
    titlePanel("Autocorrelated Kernel Density Estimate"),
    fluidRow(
      column(4,
             sliderInput(
               ns("isopleth_levels"),
               "Isopleth level:",
               min = 0.01, max = .99, value = .95
             ),
      ), 
      column(4, 
             selectizeInput(ns("what"), "What do you want to see?", c("Lower CI" = "low", "Estimate" = "est", "Upper CI" = "high"), multiple = TRUE, selected = "est")
      ),
      column(4, 
             sliderInput(ns("opacity"), "Opacity", min = 0, max = 1, value = 0.5), 
             actionButton(ns("clear"), label = "Remove all animals from map")
      ) 
    ),
    hr(),
    shinycssloaders::withSpinner(leafletOutput(ns("map"), height = "600"))
  )
}

shinyModule <- function(input, output, session, data){ ## The parameter "data" is reserved for the data object passed on from the previous app
  ns <- session$ns ## all IDs of UI functions need to be wrapped in ns()
  
  hr <- akde(data[[2]], data[[1]])
  bbx <- map(hr, ~ st_as_sf(ctmm::SpatialPolygonsDataFrame.UD(.x, level.UD = 0.97)) |> 
               st_transform(4326)) |> 
    map(st_bbox)
  bbx <- do.call(rbind, bbx)
  
  hr.iso <- reactive({
    req(input$isopleth_levels)
    akde_sf <- map(hr, ~ sf::st_as_sf(ctmm::SpatialPolygonsDataFrame.UD(.x, level.UD = input$isopleth_levels))) |> bind_rows()
    
    # export as geopackage
    akde_sf |> 
      sf::st_write(appArtifactPath(glue::glue("homerange.gpkg")), append = FALSE)
    
    akde_sf
  })
  
  
  hr.leaflet <- reactive({
    akde_sf <- hr.iso() |> 
      mutate(ID = sub("[0-9]{1,2}%.*$", "", name),
             what = purrr::map_chr(stringr::str_split(name, " "), ~ tail(.x,1))) %>% 
      mutate(what = as.factor(what)) 
    akde_sf$what <- factor(akde_sf$what, levels = c("low", "est", "high"))
    akde_sf <- akde_sf %>%  
      arrange(desc(what)) %>% 
      st_transform(4326) |> 
      group_split(ID)
    names(akde_sf) <- names(hr)
    akde_sf
  })
  
  output$map <- renderLeaflet({
    
    
    leaflet() |> 
      addTiles(group = "OSM") |> 
      addProviderTiles(providers$Esri.WorldImagery,
                       options = providerTileOptions(noWrap = TRUE), group = "World Imagery") |>
      fitBounds(min(bbx[, 1]), min(bbx[, 2]), max(bbx[, 3]), max(bbx[, 4])) |> 
      addHomeButton(
        ext = c(min(bbx[, 1]), min(bbx[, 2]), max(bbx[, 3]), max(bbx[, 4])), 
        group = "Full extent", position = "bottomleft")
    
  })
  
  cols <- rainbow(length(hr))
  
  observe({
    # Wait for the opacity slider before drawing. Don't wait for input$what
    # as the user may deselect all options and the map still needs to update
    req(input$opacity)
    m <- leafletProxy("map") |>
      clearShapes() |> 
      clearControls()
    for (i in 1:length(hr.leaflet())) {
      if ("est" %in% input$what) {
        m <- m |> addPolygons(data = hr.leaflet()[[i]] |> 
                                filter(what == "est"), 
                              group = names(hr.leaflet())[i], 
                              color = cols[i],
                              fillColor = cols[i],
                              fillOpacity = input$opacity)
      }
      
      if ("low" %in% input$what) {
        m <- m |> addPolygons(data = hr.leaflet()[[i]] |> 
                                filter(what == "low"), 
                              group = names(hr.leaflet())[i], 
                              dashArray = "3", weight = 1,
                              opacity = 1,
                              color = "white",
                              fill = FALSE)
        
      } 
      
      if ("high" %in% input$what) {
        m <- m |> addPolygons(data = hr.leaflet()[[i]] |> 
                                filter(what == "high"), 
                              group = names(hr.leaflet())[i], 
                              dashArray = "3", weight = 1,
                              color = "white",
                              opacity = 1,
                              fill = FALSE)
        
      }
    }
    m |> 
      addLayersControl(
        baseGroups = c("OSM", "World Imagery"),
        overlayGroups = names(hr.leaflet()),
        options = layersControlOptions(collapsed = TRUE)
      ) |> 
      addLegend(
        position = "bottomright",
        colors = cols,
        labels  = names(hr)) 
    
  })
  observeEvent(input$clear, {
    leafletProxy("map") |> 
      hideGroup(names(hr.leaflet()))
  })
  
  
  # Artefact: summary
  observe({
    req(input$isopleth_levels)
    xx <- map(hr, ~ summary(.x, level.UD = input$isopleth_levels)$CI)
    xx <- do.call(rbind, xx)
    xx |> as_tibble() |> 
      mutate(id = names(hr), unit = rownames(xx), level = input$isopleth_levels) |> 
      select(id, level, unit, low, est, high) |> 
      write.csv(appArtifactPath(glue::glue("akde_summary.csv")))
  })
  
  # Artefact: tifs
  targetDirUDs <- tempfile("uds")
  dir.create(targetDirUDs)
  
  r <- lapply(names(hr), function(x) 
    writeRaster(hr[[x]], file.path(targetDirUDs, paste0(x, ".tif")), overwrite = TRUE))
  
  zip::zip(
    zipfile = appArtifactPath("uds.zip"),
    files = list.files(targetDirUDs, full.names = TRUE, pattern = "tif$"),
    mode = "cherry-pick"
  )
  
  return(reactive({ 
    list(data[[1]], hr, data[[2]])
  })) ## if data are not modified, the unmodified input data must be returned
}
