#' @title Pie charts with statistical tests
#' @name ggpiestats
#' @aliases ggpiestats
#' @description Pie charts for categorical data with statistical details
#'   included in the plot as a subtitle.
#' @author Indrajeet Patil
#'
#' @param factor.levels A character vector with labels for factor levels of
#'   `main` variable.
#' @param title The text for the plot title.
#' @param caption The text for the plot caption.
#' @param sample.size.label Logical that decides whether sample size information
#'   should be displayed for each level of the grouping variable `condition`
#'   (Default: `TRUE`).
#' @param palette If a character string (e.g., `"Set1"`), will use that named
#'   palette. If a number, will index into the list of palettes of appropriate
#'   type. Default palette is `"Dark2"`.
#' @param facet.wrap.name The text for the facet_wrap variable label.
#' @param facet.proptest Decides whether proportion test for `main` variable is
#'   to be carried out for each level of `condition` (Default: `TRUE`).
#' @param perc.k Numeric that decides number of decimal places for percentage
#'   labels (Default: `0`).
#' @param slice.label Character decides what information needs to be displayed
#'   on the label in each pie slice. Possible options are `"percentage"`
#'   (default), `"counts"`, `"both"`.
#' @param bf.message Logical that decides whether to display a caption with
#'   results from bayes factor test in favor of the null hypothesis (default:
#'   `FALSE`).
#' @inheritParams bf_contingency_tab
#' @inheritParams subtitle_contingency_tab
#' @inheritParams subtitle_onesample_proptest
#' @inheritParams paletteer::scale_fill_paletteer_d
#' @inheritParams theme_ggstatsplot
#'
#' @import ggplot2
#'
#' @importFrom dplyr select group_by summarize n arrange if_else desc
#' @importFrom dplyr mutate mutate_at mutate_if
#' @importFrom rlang !! enquo quo_name
#' @importFrom crayon green blue yellow red
#' @importFrom paletteer scale_fill_paletteer_d
#' @importFrom groupedstats grouped_proptest
#' @importFrom tidyr uncount
#' @importFrom tibble as_tibble
#'
#' @references
#' \url{https://indrajeetpatil.github.io/ggstatsplot/articles/web_only/ggpiestats.html}
#'
#' @return Unlike a number of statistical softwares, `ggstatsplot` doesn't
#'   provide the option for Yates' correction for the Pearson's chi-squared
#'   statistic. This is due to compelling amount of Monte-Carlo simulation
#'   research which suggests that the Yates' correction is overly conservative,
#'   even in small sample sizes. As such it is recommended that it should not
#'   ever be applied in practice (Camilli & Hopkins, 1978, 1979; Feinberg, 1980;
#'   Larntz, 1978; Thompson, 1988). For more, see-
#'   \url{http://www.how2stats.net/2011/09/yates-correction.html}
#'
#' @examples
#' 
#' # for reproducibility
#' set.seed(123)
#' 
#' # simple function call with the defaults (without condition)
#' ggstatsplot::ggpiestats(
#'   data = ggplot2::msleep,
#'   main = vore,
#'   perc.k = 1,
#'   k = 2
#' )
#' 
#' # simple function call with the defaults (with condition)
#' ggstatsplot::ggpiestats(
#'   data = datasets::mtcars,
#'   main = vs,
#'   condition = cyl,
#'   bf.message = TRUE,
#'   nboot = 10,
#'   factor.levels = c("0 = V-shaped", "1 = straight"),
#'   legend.title = "Engine"
#' )
#' 
#' # simple function call with the defaults (without condition; with count data)
#' library(jmv)
#' 
#' ggstatsplot::ggpiestats(
#'   data = as.data.frame(HairEyeColor),
#'   main = Eye,
#'   counts = Freq
#' )
#' @export

# defining the function
ggpiestats <- function(data,
                       main,
                       condition = NULL,
                       counts = NULL,
                       ratio = NULL,
                       paired = FALSE,
                       factor.levels = NULL,
                       stat.title = NULL,
                       sample.size.label = TRUE,
                       bf.message = FALSE,
                       sampling.plan = "indepMulti",
                       fixed.margin = "rows",
                       prior.concentration = 1,
                       title = NULL,
                       caption = NULL,
                       conf.level = 0.95,
                       nboot = 25,
                       simulate.p.value = FALSE,
                       B = 2000,
                       legend.title = NULL,
                       facet.wrap.name = NULL,
                       k = 2,
                       perc.k = 0,
                       slice.label = "percentage",
                       facet.proptest = TRUE,
                       ggtheme = ggplot2::theme_bw(),
                       ggstatsplot.layer = TRUE,
                       package = "RColorBrewer",
                       palette = "Dark2",
                       direction = 1,
                       messages = TRUE) {

  # ================= extracting column names as labels  =====================

  if (base::missing(condition)) {
    # saving the column label for the 'main' variables
    if (is.null(legend.title)) {
      legend.title <- rlang::as_name(rlang::ensym(main))
    }
  } else {
    # if legend title is not provided, use the variable name for 'main'
    # argument
    if (is.null(legend.title)) {
      legend.title <- rlang::as_name(rlang::ensym(main))
    }
    # if facetting variable name is not specified, use the variable name for
    # 'condition' argument
    if (is.null(facet.wrap.name)) {
      facet.wrap.name <- rlang::as_name(rlang::ensym(condition))
    }
  }

  # =============================== dataframe ================================

  # creating a dataframe based on which variables are provided
  if (base::missing(condition)) {
    if (base::missing(counts)) {
      data <-
        dplyr::select(
          .data = data,
          main = !!rlang::enquo(main)
        )
    } else {
      data <-
        dplyr::select(
          .data = data,
          main = !!rlang::enquo(main),
          counts = !!rlang::enquo(counts)
        )
    }
  } else {
    if (base::missing(counts)) {
      data <-
        dplyr::select(
          .data = data,
          main = !!rlang::enquo(main),
          condition = !!rlang::quo_name(rlang::enquo(condition))
        )
    } else {
      data <-
        dplyr::select(
          .data = data,
          main = !!rlang::enquo(main),
          condition = !!rlang::quo_name(rlang::enquo(condition)),
          counts = !!rlang::quo_name(rlang::enquo(counts))
        )
    }
  }

  # =========================== converting counts ============================

  # untable the dataframe based on the count for each obervation
  if (!base::missing(counts)) {
    data %<>%
      tidyr::uncount(
        data = .,
        weights = counts,
        .remove = TRUE,
        .id = "id"
      )
  }

  # ============================ percentage dataframe ========================

  # main and condition need to be a factor for this analysis
  # also drop the unused levels of the factors

  # main
  data %<>%
    dplyr::mutate(.data = ., main = droplevels(as.factor(main))) %>%
    dplyr::filter(.data = ., !is.na(main))

  # condition
  if (!base::missing(condition)) {
    data %<>%
      dplyr::mutate(.data = ., condition = droplevels(as.factor(condition))) %>%
      dplyr::filter(.data = ., !is.na(condition))
  }

  # converting to tibble
  data %<>%
    tibble::as_tibble(x = .)

  # convert the data into percentages; group by conditional variable if needed
  if (base::missing(condition)) {
    df <-
      data %>%
      dplyr::group_by(.data = ., main) %>%
      dplyr::summarize(.data = ., counts = n()) %>%
      dplyr::mutate(.data = ., perc = (counts / sum(counts)) * 100) %>%
      dplyr::ungroup(x = .) %>%
      dplyr::arrange(.data = ., dplyr::desc(x = main))
  } else {
    df <-
      data %>%
      dplyr::group_by(.data = ., condition, main) %>%
      dplyr::summarize(.data = ., counts = n()) %>%
      dplyr::mutate(.data = ., perc = (counts / sum(counts)) * 100) %>%
      dplyr::ungroup(x = .) %>%
      dplyr::arrange(.data = ., dplyr::desc(x = main))
  }

  # checking what needs to be displayed on pie slices as labels also decide on
  # the text size for the label; if both counts and percentages are going to
  # be displayed, then use a bit smaller text size
  if (slice.label == "percentage") {
    # only percentage
    df %<>%
      dplyr::mutate(
        .data = .,
        slice.label = paste0(round(x = perc, digits = perc.k), "%")
      )

    label.text.size <- 4
  } else if (slice.label == "counts") {
    # only raw counts
    df %<>%
      dplyr::mutate(
        .data = .,
        slice.label = paste0("n = ", counts)
      )

    label.text.size <- 4
  } else if (slice.label == "both") {
    # both raw counts and percentages
    df %<>%
      dplyr::mutate(
        .data = .,
        slice.label = paste0(
          "n = ",
          counts,
          "\n(",
          round(x = perc, digits = perc.k),
          "%)"
        )
      )

    label.text.size <- 3
  }

  # ============================ sample size label ==========================

  # if sample size labels are to be displayed at the bottom of the pie charts
  # for each facet
  if (isTRUE(sample.size.label)) {
    if (!base::missing(condition)) {
      df_n_label <-
        dplyr::full_join(
          x = df,
          y = df %>%
            dplyr::group_by(.data = ., condition) %>%
            dplyr::summarize(.data = ., total_n = sum(counts)) %>%
            dplyr::ungroup(x = .) %>%
            dplyr::mutate(
              .data = .,
              condition_n_label = paste("(n = ", total_n, ")", sep = "")
            ) %>%
            # changing character variables into factors
            dplyr::mutate_if(
              .tbl = .,
              .predicate = purrr::is_bare_character,
              .funs = ~ base::as.factor(.)
            ),
          by = "condition"
        ) %>%
        dplyr::mutate(
          .data = .,
          condition_n_label = dplyr::if_else(
            condition = base::duplicated(condition),
            true = NA_character_,
            false = as.character(condition_n_label)
          )
        ) %>%
        stats::na.omit(.)
    }
  }

  # ================= preparing names for legend and facet_wrap ==============

  # reorder the category factor levels to order the legend
  df$main <- factor(
    x = df$main,
    levels = unique(df$main)
  )

  # getting labels for all levels of the 'main' variable factor
  if (is.null(factor.levels)) {
    legend.labels <- as.character(df$main)
  } else if (!missing(factor.levels)) {
    legend.labels <- factor.levels
  }

  # custom labeller function to use if the user wants a different name for
  # facet_wrap variable
  label_facet <- function(original_var, custom_name) {
    lev <- levels(x = as.factor(original_var))
    lab <- paste0(custom_name, ": ", lev)
    names(lab) <- lev
    return(lab)
  }

  # =================================== plot =================================

  # if no. of factor levels is greater than the default palette color count
  palette_message(
    package = package,
    palette = palette,
    min_length = length(unique(levels(data$main)))[[1]]
  )

  # if facet_wrap is *not* happening
  if (base::missing(condition)) {
    p <- ggplot2::ggplot(
      data = df,
      mapping = ggplot2::aes(x = "", y = counts)
    ) +
      ggplot2::geom_col(
        position = "fill",
        color = "black",
        width = 1,
        ggplot2::aes(fill = factor(get("main")))
      ) +
      ggplot2::geom_label(
        ggplot2::aes(
          label = slice.label,
          group = factor(get("main"))
        ),
        position = position_fill(vjust = 0.5),
        color = "black",
        size = label.text.size,
        show.legend = FALSE
      ) +
      ggplot2::coord_polar(theta = "y") # convert to polar coordinates
  } else {
    # if facet_wrap *is* happening
    p <- ggplot2::ggplot(
      data = df,
      mapping = ggplot2::aes(x = "", y = counts)
    ) +
      ggplot2::geom_col(
        position = "fill",
        color = "black",
        width = 1,
        ggplot2::aes(fill = factor(get("main")))
      ) +
      ggplot2::facet_wrap(
        facets = ~condition,
        # creating facets and, if necessary, changing the facet_wrap name
        labeller = ggplot2::labeller(
          condition = label_facet(
            original_var = df$condition,
            custom_name = facet.wrap.name
          )
        )
      ) +
      ggplot2::geom_label(
        ggplot2::aes(
          label = slice.label,
          group = factor(get("main"))
        ),
        position = ggplot2::position_fill(vjust = 0.5),
        color = "black",
        size = label.text.size,
        show.legend = FALSE
      ) +
      # convert to polar coordinates
      ggplot2::coord_polar(theta = "y")
  }

  # formatting
  p <- p +
    ggplot2::scale_y_continuous(breaks = NULL) +
    paletteer::scale_fill_paletteer_d(
      package = !!package,
      palette = !!palette,
      direction = direction,
      name = "",
      labels = unique(legend.labels)
    ) +
    theme_pie(
      ggtheme = ggtheme,
      ggstatsplot.layer = ggstatsplot.layer
    ) +
    # remove black diagonal line from legend
    ggplot2::guides(
      fill = ggplot2::guide_legend(override.aes = list(color = NA))
    )

  # =============== chi-square test (either Pearson or McNemar) =============

  # if facetting by condition is happening
  if (!base::missing(condition)) {
    if (isTRUE(facet.proptest)) {
      # merging dataframe containing results from the proportion test with
      # counts and percentage dataframe
      df2 <-
        dplyr::full_join(
          x = df,
          # running grouped proportion test with helper functions
          y = groupedstats::grouped_proptest(
            data = data,
            grouping.vars = condition,
            measure = main
          ),
          by = "condition"
        ) %>%
        dplyr::mutate(
          .data = .,
          significance = dplyr::if_else(
            condition = duplicated(condition),
            true = NA_character_,
            false = significance
          )
        ) %>%
        dplyr::filter(.data = ., !is.na(significance))

      # display grouped proportion test results
      if (isTRUE(messages)) {
        # tell the user what these results are
        base::message(cat(
          crayon::green("Note: "),
          crayon::blue("Results from faceted one-sample proportion tests:\n"),
          sep = ""
        ))

        # print the tibble and leave out unnecessary columns
        print(tibble::as_tibble(df2) %>%
          dplyr::select(.data = ., -c(main:slice.label)))
      }
    }

    # running approprate statistical test
    # unpaired: Pearson's Chi-square test of independence
    subtitle <-
      subtitle_contingency_tab(
        data = data,
        main = main,
        condition = condition,
        nboot = nboot,
        paired = paired,
        stat.title = stat.title,
        conf.level = conf.level,
        conf.type = "norm",
        simulate.p.value = simulate.p.value,
        B = B,
        messages = messages,
        k = k
      )

    # preparing the BF message for null hypothesis support
    if (isTRUE(bf.message)) {
      bf.caption.text <-
        bf_contingency_tab(
          data = data,
          main = main,
          condition = condition,
          sampling.plan = sampling.plan,
          fixed.margin = fixed.margin,
          prior.concentration = prior.concentration,
          caption = caption,
          output = "caption",
          k = k
        )
    }

    # if bayes factor message needs to be displayed
    if (isTRUE(bf.message)) {
      caption <- bf.caption.text
    }

    # ====================== facetted proportion test =======================

    # adding significance labels to pie charts for grouped proportion tests
    if (isTRUE(facet.proptest)) {
      p <-
        p +
        ggplot2::geom_text(
          data = df2,
          mapping = ggplot2::aes(label = significance, x = 1.65),
          position = ggplot2::position_fill(vjust = 1),
          size = 5,
          na.rm = TRUE
        )
    }

    # adding sample size info
    if (isTRUE(sample.size.label)) {
      p <-
        p +
        ggplot2::geom_text(
          data = df_n_label,
          mapping = ggplot2::aes(label = condition_n_label, x = 1.65),
          position = ggplot2::position_fill(vjust = 0.5),
          size = 4,
          na.rm = TRUE
        )
    }
  } else {
    subtitle <- subtitle_onesample_proptest(
      data = data,
      main = main,
      ratio = ratio,
      legend.title = legend.title,
      k = k
    )
  }

  # =========================== putting all together ========================

  # preparing the plot
  p <-
    p +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      subtitle = subtitle,
      title = title,
      caption = caption
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(title = legend.title))

  # return the final plot
  return(p)
}
