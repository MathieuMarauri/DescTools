



ModelDlg <- function(x, ...){

  .GetModTxt <- function()
    tcltk::tclvalue(tcltk::tkget(tfModx, "0.0", "end"))


  .AddVar <- function(sep, pack = NULL) {

    var.name <- as.numeric(tcltk::tkcurselection(tlist.var))

    if (length(var.name) == 0)
      tcltk::tkmessageBox(message = "No variable selected",
                          icon = "info", type = "ok")

    if (length(var.name) > 0) {

      txt <- DescTools::StrTrim(.GetModTxt())
      if(is.null(pack))
        vn <- colnames(x)[var.name + 1]
      else
        vn <- gettextf(pack, colnames(x)[var.name + 1])

      tcltk::tkinsert(tfModx, "insert",
                      paste(ifelse(txt=="", "", " +"), paste(vn, collapse=sep))
                      , "notwrapped")
    }
  }

  .BtnAddVar <- function() .AddVar(" + ")
  .BtnAddMult <- function() .AddVar(" * ")
  .BtnAddInt <- function() .AddVar(" : ")
  .BtnAddPoly <- function() .AddVar(sep=" + ", pack="poly(%s, 2)")

  .InsertLHS <- function() {

    var.name <- as.numeric(tcltk::tkcurselection(tlist.var))

    if (length(var.name) == 0)
      tcltk::tkmessageBox(message = "No variable selected",
                          icon = "info", type = "ok")

    if (length(var.name) > 0) {
      tcltk::tclvalue(tflhs) <- paste(colnames(x)[var.name + 1], collapse=", ")
    }
  }

  fam <- "comic"
  size <- 10
  myfont <- tcltk::tkfont.create(family = fam, size = size)

  tfmodx <- tcltk::tclVar("")
  tflhs <- tcltk::tclVar("")

  mod_x <- NA_character_

  e1 <- environment()
  modx <- character()
  # old, repl. by 0.99.22: xname <- deparse(substitute(x))
  xname <- paste(StrTrim(deparse(substitute(x))), collapse=" ")

  if (!missing(x)) {
    if(class(x) == "formula") {

      # would be nice to pick up a formula here, to be able to edit the formula
      # https://rviews.rstudio.com/2017/02/01/the-r-formula-method-the-good-parts/

      # try to extract the name of the data.frame from match.call
      xname <- StrExtract(gsub("^.+data = ", "\\1", paste(deparse(match.call()), collapse=" ")), ".+[[:alnum:]]")

      tcltk::tclvalue(tflhs) <- deparse(x[[2]])
      mod_x <- deparse(x[[3]])

      x <- eval(parse(text=xname, parent.env()))

    } else if(!is.data.frame(x))
      stop("x must be a data.frame")


  } else {
    stop("Some data must be provided, example: ModelDlg(iris)")
  }


  OnOK <- function() {
    assign("modx", paste(
      DescTools::StrTrim(tcltk::tclvalue(tflhs)), " ~ ",
      DescTools::StrTrim(.GetModTxt()), ", data=", xname, sep=""), envir = e1)
    tcltk::tkdestroy(root)
  }

  # do not update screen
  tcltk::tclServiceMode(on = FALSE)

  # create window
  root <- .InitDlg(width = 840, height = 480, resizex=TRUE, resizey=TRUE,
                   main="Build Model Formula", ico="R")

  # define widgets
  content = tcltk::tkframe(root, padx=10, pady=10)


  # Variable list
  frmVar <- tcltk::tkwidget(content, "labelframe", text = "Variables:",
                            fg = "black", padx = 10, pady = 10, font = myfont)

  var.scr <- tcltk::tkscrollbar(frmVar, repeatinterval = 5,
                                command = function(...) tcltk::tkyview(tlist.var, ...))

  tlist.var <- tcltk::tklistbox(frmVar, selectmode = "extended",
                                yscrollcommand = function(...)
                                  tcltk::tkset(var.scr, ...), background = "white",
                                exportselection = FALSE,
                                height=21, width = 25, font = myfont)

  for (z in names(x)) {
    tcltk::tkinsert(tlist.var, "end", z)
  }


  tcltk::tkbind(tlist.var)
  tcltk::tkgrid(tlist.var, var.scr, sticky = "ns")
  tcltk::tkgrid.configure(var.scr, sticky = "ns")
  # tcltk2::tk2tip(tlist.var, "List of variables in data frame")

  # Buttons
  frmButtons <- tcltk::tkwidget(content, "labelframe", text = "",  bd=0,
                              fg = "black", padx = 5, pady = 25)

  tfButLHS <- tcltk::tkbutton(frmButtons, text = ">",
    command = .InsertLHS, height = 1, width = 2, font=myfont)

  tfButAdd <- tcltk::tkbutton(frmButtons, text = "+",
     command = .BtnAddVar, height = 1, width = 2, font=myfont)
  tfButMult <- tcltk::tkbutton(frmButtons, text = "*",
     command = .BtnAddMult, height = 1, width = 2, font=myfont)
  tfButInt <- tcltk::tkbutton(frmButtons, text = ":",
             command = .BtnAddInt,
             height = 1, width = 2, font=myfont)
  tfButPoly <- tcltk::tkbutton(frmButtons, text = "x\U00B2",
                              command = .BtnAddPoly,
                              height = 1, width = 2, font=myfont)

  tcltk::tkgrid(tfButLHS, row = 0, rowspan=10, padx = 5, sticky = "s")
  tcltk::tkgrid(tcltk::tklabel(frmButtons, text="\n\n"))
  tcltk::tkgrid(tfButAdd, row = 40, padx = 5, sticky = "s")
  tcltk::tkgrid(tfButMult, row = 50, padx = 5, sticky = "s")
  tcltk::tkgrid(tfButInt, row = 60, padx = 5, sticky = "s")
  tcltk::tkgrid(tfButPoly, row = 70, padx = 5, sticky = "s")


  # Model textbox
  frmModel <- tcltk::tkwidget(content, "labelframe", text = "Model:",
                              fg = "black", padx = 10, pady = 10, font = myfont)

  tfLHS <- tcltk::tkentry(frmModel, textvariable=tflhs, bg="white")
  tfModx <- tcltk::tktext(frmModel, bg="white", height=18, width=70, font=myfont)
  tcltk::tkgrid(tfLHS, column=0, row=0, pady=10, sticky="nwes")
  tcltk::tkgrid(tcltk::tklabel(frmModel, text="~"), row=1, sticky="w")
  tcltk::tkgrid(tfModx, column=0, row=2, pady=10, sticky="nws")
  if(!is.na(mod_x))
    tcltk::tkinsert(tfModx, "insert", mod_x, "notwrapped")

  # root
  tfButOK = tcltk::tkbutton(content, text="OK", command=OnOK, width=6)
  tfButCanc = tcltk::tkbutton(content, text="Cancel", width=7,
                              command=function() tcltk::tkdestroy(root))

  # build GUI
  tcltk::tkgrid(content, column=0, row=0, sticky = "nwes")
  tcltk::tkgrid(frmVar, padx = 5, pady = 5, row = 0, column = 0,
                rowspan = 20, columnspan = 1, sticky = "ns")

  tcltk::tkgrid(frmButtons, padx = 5, pady = 5, row = 0, column = 2,
                rowspan = 20, columnspan = 1, sticky = "ns")

  tcltk::tkgrid(frmModel, padx = 5, pady = 5, row = 0, column = 3,
                rowspan = 20,
                sticky = "nes")

  tcltk::tkgrid(tfButOK, column=3, row=30, ipadx=15, padx=5, sticky="es")
  tcltk::tkgrid(tfButCanc, column=0, row=30, ipadx=15, padx=5, sticky="ws")

  tcltk::tkfocus(tlist.var)
  tcltk::tclServiceMode(on = TRUE)

  tcltk::tcl("wm", "attributes", root, topmost=TRUE)

  tcltk::tkwait.window(root)

  return(modx)

}



