$ = jQuery

class Chosen.Parser
  constructor: (@chosen)->
    @all_options = []
    @available_options = []
    @selected_options = []
    @selectable_options = []

    @parse()

  destroy: ->
    delete @all_options
    delete @available_options
    delete @selected_options
    delete @selectable_options
    delete @chosen
    return

  parse: (selected_options = []) ->
    formatter = @chosen.option_formatter || @default_formatter
    current_group_label = null
    group = null

    @all_options = []
    @selected_options = []
    @selectable_options = []

    link_params =
      html: "×"
      href: "javascript:void(0)"
      class: "chosen-delete"
      tabindex: @chosen.$target[0].tabindex || "0"

    @chosen.$target.find("option").each (index, option) =>
      if option.parentNode.nodeName is "OPTGROUP"
        if current_group_label != option.parentNode.label
          current_group_label = option.parentNode.label
          group = $("<li />", class: "chosen-group", html: current_group_label)
      else
        group = null

      classes = "chosen-option"
      classes += " group" if group
      classes += " selected" if option.selected
      classes += " disabled" if option.disabled

      selected = $.grep(selected_options, (o) => o.value is option.value and o.label is option.label)[0]
      text = formatter(option)

      option_obj =
        $group: group
        $listed: (selected and selected.$listed) or $("<li />", class: classes, html: text[0])
        $choice: (selected and selected.$choice) or $("<li />", class: classes, html: [$("<a />", link_params), text[1]])
        $option: (selected and selected.$option) or $(option)
        blank: option.value is "" and index is 0
        index: index
        score: index * -1
        label: option.text
        value: option.value
        selected: option.selected
        disabled: option.disabled

      @all_options.push option_obj
      @selected_options.push option_obj if option.selected
      @selectable_options.push option_obj unless option.selected

    @order()
    return @

  update: (data) ->
    parser = @chosen.option_parser || @default_parser
    selected_options = []

    for option in @all_options
      if option.selected or option.blank
        selected_options.push(option)
      else
        option.$option.remove()

    for attrs in data
      parsed = parser(attrs)
      unless $.grep(selected_options, (o) => o.value is parsed.value.toString() and o.label == parsed.html.toString() ).length
        @chosen.$target.append($("<option />", parsed))

    @parse(selected_options)
    return @

  add: (data) ->
    formatter = @chosen.option_formatter || @default_formatter
    classes = "chosen-option"

    link_params =
      html: "×"
      href: "javascript:void(0)"
      class: "chosen-delete"
      tabindex: @chosen.$target[0].tabindex || "0"

    option = $("<option />", value: data.value, html: data.label)
    text = formatter(option[0])

    option_obj =
      $group: null
      $listed: $("<li />", class: classes, html: text[0])
      $choice: $("<li />", class: classes, html: [$("<a />", link_params), text[1]])
      $option: option
      blank: false
      index: 0
      score: 0
      label: option[0].text
      value: option[0].value
      selected: false
      disabled: false

    @all_options.unshift option_obj
    @available_options.unshift option_obj

    option_obj

  remove: (option) ->
    return if option.selected

    option.$listed.remove()
    option.$choice.remove()
    option.$option.remove()

    for collection in [@all_options, @available_options, @selected_options, @selectable_options]
      index = collection.indexOf(option)
      collection.splice(index, 1) if index > -1

  to_html: ->
    last_group = null
    list = []

    for option in @available_options
      if option.$group
        if not last_group or (last_group and last_group.text() isnt option.$group.text())
          last_group = option.$group.clone()
          list.push last_group
      else
        last_group = null

      list.push option.$listed

    list

  find_by_element: (element) ->
    for option in @all_options
      if option.$listed[0] is element or option.$choice[0] is element
        return option

    return null

  index_of: (option) ->
    if option then @available_options.indexOf(option) else 0

  select: (option) ->
    return @ unless option

    option.$option[0].selected = true
    option.$option.attr(selected: "selected")
    option.$listed.addClass("selected")
    option.$choice.addClass("selected")
    option.selected = true

    index = @selectable_options.indexOf(option)
    @selectable_options.splice(index, 1) unless index is -1
    @selected_options.push(option)

    return @

  deselect: (option) ->
    return @ unless option

    option.$option[0].selected = false
    option.$option.removeAttr("selected")
    option.$listed.removeClass("selected")
    option.$choice.removeClass("selected")
    option.selected = false

    index = @selected_options.indexOf(option)
    @selected_options.splice(index, 1) unless index is -1
    @selectable_options.push(option)

    return @

  selected: ->
    $.grep @available_options, (option) ->
      option.selected

  not_selected: ->
    $.grep @available_options, (option) ->
      not option.selected

  exact_matches: ->
    $.grep @available_options, (option) ->
      option.match_type is 0

  includes_blank: ->
    not not @blank_option()

  blank_option: ->
    for option in @all_options
      return option if option.blank

    return null

  apply_filter: (value) ->
    @reset_filter()

    if (value = $.trim(value))
      scores = [
        @all_options.length * 12, @all_options.length * 9
        @all_options.length * 6, @all_options.length * 3
      ]

      query = value.replace(Parser.escape_exp, "\\$&").split(" ")

      expressions_collection = $.map(query, (word, index) ->
        return [[
          new RegExp("^#{word}$", "i"), new RegExp("^#{word}", "i")
          new RegExp("#{word}$", "i"), new RegExp(word, "i")
        ]]
      )

      for option in @all_options
        words = option.label.split(" ")

        for word in words
          for expressions in expressions_collection
            for expression, index in expressions
              if word.match(expression)
                option.match_type = index
                option.score += scores[index]
                break
              else if index is expressions.length - 1
                option.score += -1

    @order()
    return @

  reset_filter: ->
    option.score = option.index * -1 for option in @all_options
    return @

  order: ->
    @all_options = @all_options.sort (a, b) ->
      if a.score > b.score then -1 else if a.score < b.score then 1 else 0

    @available_options = []

    for option in @all_options
      if not option.blank
        @available_options.push(option)

    return @

  default_parser: (attrs) ->
    value: attrs.value
    html: attrs.label
    data: { source: attrs }

  default_formatter: (option) ->
    [option.text, option.text]


  @escape_exp: /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g
