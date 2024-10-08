#' Module for sidebar
#'
#' @description Module for sidebar
#'
#' @importFrom shiny NS tagList 
#' 
#' @param id string. namespace the module.
#' @return sets of tags.
#' @examples
#' \dontrun{
#' sidebarUI('input')
#' }
#' @export
sidebarUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("ui_input")),
    hr(),
    checkboxGroupInput(ns("check_nodes"), "0 node(s) Selected:"),
    div(id = "buttons",
    fluidRow(
      column(6,
             div(
               actionButton(
                 inputId = ns("deselect"),
                 label = "Unselect", 
                 icon = icon("undo"),
                 color = "lightgrey"
               ), align = "center")),
      column(6,
             div(
               actionButton(
                 inputId = ns("gobutton"),
                 label = "Submit", 
                 icon = icon("check"),
                 color = "green"
               ), align = "center")))
    )
  )
}

#' Server Module for sidebar
#'
#' @rdname sidebarUI
#'
#' @importFrom shiny NS tagList 
#' 
#' @param id string. Namespace of the module.
#' @param tb_input string. Namespace of the module.
#' @param tname string. table name in db to search.
#' @param db string. name of the database.
#' @param type string. Default DT. DT or reactable.
#' @param selected numeric. Pre-selected rows in table. Default c(1,3).
#' @param init_nodes vector. Default NULL. Initial center nodes.
#' @param server logical. Default TRUE, the data is kept on the server and
#'     the browser requests a page at a time; if FALSE, then the entire 
#'     data frame is sent to the browser at once. Highly recommended for 
#'     medium to large data frames, which can cause browsers to slow down or 
#'     crash. Passed to renderDT().
#' @return vector of center nodes.
#' @examples
#' \dontrun{
#' sidebarServer('input')
#' }
#' @export
sidebarServer <- function(id, tb_input, tname, db, type = 1, selected = c(1, 3),
                          init_nodes = NULL,
                          server = TRUE) {
  moduleServer(id, function(input, output, session) {
    ns <- NS(id)

    output$ui_input <- renderUI({
      if(type == 1){
        tagList(shinycssloaders::withSpinner(
            DT::DTOutput(ns("tbInput")), type = 6))
      } else {
        tagList(
          shinyWidgets::searchInput(
            inputId = ns("searchbox2"),
            label = "Enter your search: ",
            placeholder = "rheumatoid arthritis",
            value = NULL,
            btnSearch = icon("search"),
            width = "100%"
          ),
          shinycssloaders::withSpinner(
            DT::DTOutput(ns("tbInput")), type = 6)
        )
      }
    })
  
    df_search <- function(text, tname, db){
      if("synonyms" %in% RPostgres::dbListTables(con(db))){
        sql <- paste0('SELECT s.id, "term", "synonyms"
        FROM (SELECT "id", "term" FROM "', tname, '") AS s
        LEFT JOIN "synonyms" AS r
        ON (s.id = r.id) WHERE s.id ilike \'%', text, '%\' or "term" ilike \'%', text, '%\' or "synonyms" ilike \'%', text, '%\';')
      } else {
        sql <- paste0('SELECT "id", "term" FROM "', tname, '"
          WHERE "id" ilike \'%', text, '%\' or "term" ilike \'%', text, '%\';')
      }
      df <- readDB(sql, tname, db)
      df <- df[!duplicated(df$id), ]
      
      df$order <- 1
      df$order[tolower(df$term) == text] <- 0
      if("synonyms" %in% colnames(df)){
        df$order[tolower(df$synonyms) == text] <- 0
      }
      df[order(df$order, df$id), 1:(ncol(df)-1)]
    }
    
    tb_input2 <- reactive({
      if(type == 1){
        tb_input
      } else {
        if(isTruthy(input$searchbox2)){
          text <- input$searchbox2
        } else {
          text <- "rheumatoid arthritis"
        }
        # ids <- search(text)
        # tb_input[tb_input$id %in% ids,]
        df_search(text, tname, db)
      }
    })
    
    rows <- reactive({
      if(type == 1 | (!isTruthy(input$searchbox2))){
        selected
      } else {
        NULL
      }
    })
    
    observe({
      output$tbInput <- DT::renderDT(DT::datatable({
        print("-------------------")
        tb_input2()
      }, rownames = FALSE,
      options = list(
        paging = FALSE,
        scrollY = "300px",
        scrollCollapse = TRUE,
        dom = ifelse(type == 1, "Bfrtp", "Brtp")
      ),
      selection = list(mode = 'single', 
                       selected = rows(), 
                       target = 'row'),
      escape = FALSE
      ), server = server)
    })
    
    
    # output$tbInput2 <- DT::renderDT(DT::datatable({
    #   print("tbInput2")
    #   print(nrow(tb_input2()))
    #   tb_input2()
    # }, rownames = FALSE,
    # options = list(
    #   paging = FALSE,
    #   scrollY = "300px",
    #   scrollCollapse = TRUE,
    #   dom = "Brtip"
    # ),
    # selection = list(mode = 'multiple', selected = selected, target = 'row'),
    # escape = FALSE
    # ), server = server)

  ## Update checkboxinput if refreshing=================================
  observeEvent(input$deselect, {

    DT::reloadData(
      DT::dataTableProxy('tbInput'),
      resetPaging = TRUE,
      clearSelection = c("all"))
    
    x <- character(0)
    updateCheckboxGroupInput(session, "check_nodes",
                             "0 node(s) selected",
                             choices = x,
                             selected = x)
    
  })
  
  
  new_selected <- reactive({
      tb_input2()$id[input$tbInput_rows_selected]
  })
  
  selected <- eventReactive(c(input$searchbox2, input$deselect), {
    DT::reloadData(
      DT::dataTableProxy('tbInput'),
      resetPaging = TRUE,
      clearSelection = c("all"))
      input$check_nodes
  }, ignoreNULL = FALSE)
  
  ## Update checkboxinput based on selected rows in table==============
  observeEvent(tb_input2(), {
    
    DT::reloadData(
      DT::dataTableProxy('tbInput'),
      resetPaging = TRUE,
      clearSelection = c("all"))
    
    updateCheckboxGroupInput(session, "check_nodes",
                             label = paste(length(unique(c(selected()))), "node(s) selected:"),
                             choiceValues = unique(c(selected())),
                             choiceNames = unique(c(selected())),
                             selected = unique(c(selected())))
  })
  
  observeEvent(input$tbInput_rows_selected, {
    checkboxUpdateBySelectedRows("check_nodes", selected(),
                                 tb_input2()$id[input$tbInput_rows_selected],
                                 tb_input2(), session)
  })
  
  
  
  ## center nodes ==============================
  center_nodes <- eventReactive(input$gobutton, {
    if(input$gobutton == 0 & str_detect(session$clientData$url_search, 'centernode=')){
      url_vars <- session$clientData$url_search
      str_split(url_vars, 'centernode=')[[1]][2]
    }else{
      if(input$gobutton == 0 & !isTruthy(input$check_nodes)){
        init_nodes
      } else {
        input$check_nodes
      } 
    }
  }, ignoreNULL = FALSE)
    
    # center_nodes <- reactive({
    #   print(paste("input$gobutton", input$gobutton))
    #   if(input$gobutton == 0){
    #     # c("RXNORM:221062", "PheCode:313.3")
    #     # tb_inpisolateut2()$id[rows()]
    #     input$check_nodes
    #   } else {
    #     req(input$gobutton)
    #     isolate(input$check_nodes)
    #   }
    # })
  
  reactive({
    center_nodes()
  })
})}

