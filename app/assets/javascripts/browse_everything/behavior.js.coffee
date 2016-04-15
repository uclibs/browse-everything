(($, window) ->

  # Define the plugin class
  class BrowseEverything

    defaults:
      paramA: 'foo'
      paramB: 'bar'

    constructor: (el, options) ->
      @options = $.extend({}, @defaults, options)
      @$el = $(el)
      console.log ('I am now working as a cs plugin')

    # Additional plugin methods go here
    myMethod: (echo) ->
      @$el.html(@options.paramA + ': ' + echo)

  # Define the plugin
  $.fn.extend browseEverything: (option, args...) ->
    @each ->
      $this = $(this)
      data = $this.data('browseEverything')

      if !data
        $this.data 'browseEverything', (data = new BrowseEverything(this, option))
      if typeof option == 'string'
        data[option].apply(data, args)

) window.jQuery, window

